local api = vim.api
local fn = vim.fn
local util = vim.lsp.util

local M = {}

local state_res_current = nil ---@type farsight.live.MatchData|nil
local state_res_cache = {} ---@type table<string, farsight.live.MatchData>
local state_buf_lines = {} ---@type table<uinteger, table<uinteger, string>>
local state_ns = api.nvim_create_namespace("farsight.live")
local state_jump_point = nil

-- TODO: Use only numeric indexes once code is baked in.
-- TODO: Move definition to somewhere common.
---@class farsight.Target Ranges are zero-indexed, end-exclusive.
---@field [1] uinteger
---@field [2] uinteger
---@field [3] uinteger
---@field [4] uinteger
---@field vtext [string, string|uinteger][]

-- TODO: Use only numeric indexes once code is baked in.
-- TODO: Move definition to static module.
---@class farsight.static.Target : farsight.Target
---@field label string[]
---@field label_start boolean

-- TODO: Use only numeric indexes once code is baked in.
---@class farsight.live.Target : farsight.Target
---@field char_after string -- TODO: try to yeet

---@param res farsight.live.MatchData
---@param buf uinteger
---@param win uinteger
local function extmarks_refresh(res, buf, win)
    api.nvim_buf_clear_namespace(buf, state_ns, 0, -1)

    local targets = res.targets
    for _, target in ipairs(targets) do
        api.nvim_buf_set_extmark(buf, state_ns, target[1], target[2], {
            end_row = target[3],
            end_col = target[4],
            hl_group = "Search", -- TODO: Make custom group
            priority = 250, -- TODO: Come up with something reasonable
        })
    end

    local labeled_targets = res.labeled_targets
    for label, idx in pairs(labeled_targets) do
        local range = targets[idx]
        api.nvim_buf_set_extmark(buf, state_ns, range[3], range[4], {
            priority = 300, -- TODO: Come up with a real number
            virt_text = { { label, "CurSearch" } }, -- TODO: Make a custom group
            virt_text_pos = "overlay",
        })
    end

    api.nvim__redraw({ flush = true, valid = true, win = win })
end

---@param res farsight.live.MatchData Modifed in place!
---@param label string
---@param idx uinteger
local function res_checked_add_label(res, label, idx)
    local idxs_labeled = res.idxs_labeled
    if idxs_labeled[idx] == true then
        return false
    end

    res.labeled_targets[label] = idx
    idxs_labeled[idx] = true
    return true
end

---@param res farsight.live.MatchData
---@param tokens string[]
---@param upward boolean
local function res_labels_add(res, tokens, upward)
    local targets = res.targets
    local n = math.min(#targets, #tokens)
    if n == 0 then
        return
    end

    local start
    local stop
    local step
    if upward then
        start = #targets
        stop = 1
        step = -1
    else
        start = 1
        stop = #targets
        step = 1
    end

    local res_idxs_labeled = res.idxs_labeled
    local j = 1
    for i = start, stop, step do
        if res_idxs_labeled[i] == nil then
            res_checked_add_label(res, tokens[j], i)
            j = j + 1
            n = n - 1
        end

        if n == 0 then
            break
        end
    end
end

local COL_BITS = 10 -- Up to three digits
local COL_POW = 2 ^ COL_BITS

---@param target farsight.live.Target
---@return uinteger
local function bit_pack_start(target)
    return target[1] * COL_POW + target[2]
end
-- TODO: This should be able to handle more rows/cols.

---@param res farsight.live.MatchData Modified in place!
---@param old_res farsight.live.MatchData
---@param chars_after table<string, true>
local function res_intake_old_labels(res, old_res, chars_after)
    local packed_targets = res.packed_targets
    for i, target in ipairs(res.targets) do
        packed_targets[bit_pack_start(target)] = i
    end

    local old_targets = old_res.targets
    for old_label, old_label_idx in pairs(old_res.labeled_targets) do
        if chars_after[old_label] == nil then
            local old_target_key = bit_pack_start(old_targets[old_label_idx])
            local target_idx = packed_targets[old_target_key]
            if target_idx ~= nil then
                res_checked_add_label(res, old_label, target_idx)
            end
        end
    end
end

---@param res farsight.live.MatchData
---@param lines table<uinteger, string> 0-indexed.
---@return table<string, true>
local function chars_after_get(res, lines)
    local chars = {} ---@type table<string, true>
    for _, target in ipairs(res.targets) do
        local char_start_1 = target[4] + 1
        local line = lines[target[1]]
        local dist = vim.str_utf_end(line, char_start_1)
        chars[string.sub(line, char_start_1, char_start_1 + dist)] = true
    end

    return chars
end

---@param cmdline string
---@param version uinteger
---@return farsight.live.MatchData?
local function res_cached_get(cmdline, version)
    local res_cached = state_res_cache[cmdline]
    if res_cached == nil then
        return
    end

    if res_cached.buf_version ~= version then
        state_res_cache[cmdline] = nil
        return
    end

    return res_cached
end
-- TODO: Test how this works with regex atoms.

---@param text string
---@return string
local function char_last_get(text)
    local charlen = fn.strcharlen(text)
    if charlen == 0 then
        return ""
    end

    local byteidx = fn.byteidx(text, charlen - 1)
    return string.sub(text, byteidx + 1, #text)
end
-- TODO: Unsure if I have the indexing right
-- TODO: This should use the vim. functions if possible to keep composing char logic consistent

---@param cmdline string
---@param buf uinteger
local function should_jump(cmdline, buf)
    local last_char = char_last_get(cmdline)
    if state_res_current ~= nil then
        for label, idx in pairs(state_res_current.labeled_targets) do
            if label == last_char then
                local range = state_res_current.targets[idx]
                -- TODO: Use pos conversion logic here for clarity
                state_jump_point = { range[1] + 1, range[2] }
                api.nvim_buf_clear_namespace(buf, state_ns, 0, -1)
                return true
            end
        end
    end

    return false
end
-- TODO: Another return + side effect function
-- TODO: This feels especially undercooked.

---@param match_range [uinteger, uinteger, uinteger, uinteger]
---@param win uinteger
---@param buf uinteger
---@param re vim.regex
---@param tokens string[]
---@param upward boolean
local function targets_update(match_range, win, buf, re, tokens, upward)
    local cmdline = fn.getcmdline()
    if should_jump(cmdline, buf) then
        -- TODO: feed. either feedkeys or nvim_input unsure
        return
    end

    -- Track version in case user autocmds update the buffer.
    local version = util.buf_versions[buf]
    local res_cached = res_cached_get(cmdline, version)
    if res_cached ~= nil then
        extmarks_refresh(res_cached, buf, win)
        state_res_current = res_cached
        return
    end

    local ntt = require("nvim-tools.table")
    local lines = ntt.get_or_set_subtable(state_buf_lines, version)
    local win_matcher = require("farsight._aos_win_match")
    local ranges = win_matcher.res_live_get(match_range, win, buf, lines, re)
    ---@cast ranges farsight.live.Target[]
    ---@type farsight.live.MatchData
    local res = {
        buf_version = version,
        idxs_labeled = {},
        labeled_targets = {},
        packed_targets = {},
        targets = ranges,
    }

    local chars_after = chars_after_get(res, lines)
    if state_res_current ~= nil then
        res_intake_old_labels(res, state_res_current, chars_after)
    end

    local avail_tokens = ntt.i_copy(tokens)
    local res_labeled_targets = res.labeled_targets
    ntt.i_discard(avail_tokens, function(token)
        return chars_after[token] == true or res_labeled_targets[token] ~= nil
    end)

    res_labels_add(res, avail_tokens, upward)
    extmarks_refresh(res, buf, win)

    state_res_cache[cmdline] = res
    state_res_current = res
    api.nvim__redraw({ flush = true, valid = true, win = win })
end
-- TODO: This needs to be profiled.

local group_name = "farsight.live-input-listener"

---@param range [uinteger, uinteger, uinteger, uinteger]
---@param win uinteger
---@param buf uinteger
---@param re vim.regex
---@param upward boolean
---@param tokens string[]
local function listener_init(range, win, buf, re, tokens, upward)
    -- Re-create the group in case the previous del_autocmd failed to run.
    local group = api.nvim_create_augroup(group_name, {})
    api.nvim_create_autocmd("CmdlineChanged", {
        group = group,
        callback = function()
            targets_update(range, win, buf, re, tokens, upward)
        end,
    })
end

---@class farsight.live.MatchData
---@field buf_version uinteger
---@field idxs_labeled table<uinteger, true>
---@field labeled_targets table<string, uinteger>
---@field packed_targets table<uinteger, uinteger>
---@field targets farsight.live.Target[]

-- TODO: Define in init
---@class farsight.live.Ctx
---@field tokens string[]

---@param upward boolean
function M.live(upward, pattern, ctx)
    local win = api.nvim_get_current_win()
    local win_config = api.nvim_win_get_config(win)
    if win_config.hide then
        -- TODO: Probably print something here
        return
    end

    local match_ctx = {
        dir = upward and -1 or 1,
        folds = "none",
        match_end = "before",
        match_start = "after",
    }

    local win_matcher = require("farsight._aos_win_match")
    local ok, buf, re, range, err = win_matcher.live_info_get(win, pattern, match_ctx)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    listener_init(range, win, buf, re, ctx.tokens, upward)

    -- TODO: get input

    -- TODO: input teardown
    -- - use table.clear on buf_lines
    -- - use table.clear on tarets_cache
end
-- TODO: Config needs to validate that each token is one char long

return M

-- TODO: Keep the live logic as sectioned off as possible. Because live is the only module that
-- needs to be concerned with upward, it vastly reduces the assumptions behind the static labeler
-- and vtexter if we can always assume they run in list order.

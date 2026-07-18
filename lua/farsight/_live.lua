local api = vim.api
local fn = vim.fn

local ntt = require("nvim-tools.table")

-----------------
-- MARK: State --
-----------------

local state_cmdline = ""
local state_err = ""
local state_jump_col_ext = -1
local state_jump_row_ext = -1
local state_res_cache = {} ---@type table<string, farsight.live.MatchData>
local state_res_current = nil ---@type farsight.live.MatchData|nil

local function state_try_res_cache_as_current()
    local res_cached = state_res_cache[state_cmdline]
    if res_cached ~= nil then
        state_res_current = res_cached
        return true
    end

    return false
end

---@param text string
---@return string
local function char_last_get(text)
    if text == "" then
        return ""
    end

    local text_len = #text
    return string.sub(text, text_len + vim.str_utf_start(text, text_len), text_len)
end

local function state_try_stage_jump_from_label()
    if state_res_current == nil then
        return false
    end

    local last_char = char_last_get(state_cmdline)
    local range_idx = state_res_current.labeled_targets[last_char]
    if range_idx == nil then
        return false
    end

    local range = state_res_current.targets[range_idx]
    state_jump_row_ext = range[1]
    state_jump_col_ext = range[2]
    return true
end

---@param res farsight.live.MatchData
local function state_set_res_for_cur_cmdline(res)
    state_res_cache[state_cmdline] = res
    state_res_current = res
end

---@param ok boolean
---@param text string
---@param upward boolean
local function state_resolve_jump_pos(ok, text, upward)
    if state_jump_row_ext ~= -1 and state_jump_col_ext ~= -1 then
        return
    end

    if not (ok and text == state_cmdline and state_res_current ~= nil) then
        return
    end

    local targets = state_res_current.targets
    if #targets == 0 then
        return
    end

    local target = upward and targets[#targets] or targets[1]
    state_jump_row_ext = target[1]
    state_jump_col_ext = target[2]
end

---@return [uinteger, uinteger], string
local function state_clean_and_export()
    local jump_col_ext = state_jump_col_ext
    local jump_row_ext = state_jump_row_ext
    state_jump_row_ext = -1
    state_jump_col_ext = -1

    require("nvim-tools.table").clear(state_res_cache)
    state_res_current = nil
    state_cmdline = ""
    local err = state_err
    state_err = ""

    return { jump_row_ext, jump_col_ext }, err
end

--------------------------
-- MARK: Hl and Ns Info --
--------------------------

local ns_basename = "farsight.live"
local state_ns_dynamic = api.nvim_create_namespace(ns_basename .. ".dynamic")
local state_ns_dim = api.nvim_create_namespace(ns_basename .. ".dim")

do
    -- TODO-DEP: Remove this when 0.14 comes out.
    api.nvim_set_hl(0, "Dimmed", { default = true, link = "Comment" })

    api.nvim_set_hl(0, "farsightLiveDim", { default = true, link = "Dimmed" })
    api.nvim_set_hl(0, "farsightLiveResult", { default = true, link = "Search" })
    api.nvim_set_hl(0, "farsightLiveLabel", { default = true, link = "IncSearch" })
end

local hl_error = api.nvim_get_hl_id_by_name("ErrorMsg")

local hl_dim = api.nvim_get_hl_id_by_name("farsightLiveDim")
local hl_res = api.nvim_get_hl_id_by_name("farsightLiveResult")
local hl_label = api.nvim_get_hl_id_by_name("farsightLiveLabel")

local hl_priority_dim = vim.hl.priorities.user + 50
local hl_priority_res = hl_priority_dim + 1
local hl_priority_label = hl_priority_res + 1

-------------------
-- MARK: Display --
-------------------

---@param buf uinteger
local function extmarks_refresh_from_current(buf)
    api.nvim_buf_clear_namespace(buf, state_ns_dynamic, 0, -1)
    if state_res_current == nil then
        return
    end

    local targets = state_res_current.targets
    for _, target in ipairs(targets) do
        api.nvim_buf_set_extmark(buf, state_ns_dynamic, target[1], target[2], {
            end_col = target[4],
            end_row = target[3],
            hl_group = hl_res,
            priority = hl_priority_res,
        })
    end

    local labeled_targets = state_res_current.labeled_targets
    for label, idx in pairs(labeled_targets) do
        local range = targets[idx]
        api.nvim_buf_set_extmark(buf, state_ns_dynamic, range[3], range[4], {
            hl_mode = "combine",
            priority = hl_priority_label,
            virt_text = { { label, hl_label } },
            virt_text_pos = "overlay",
        })
    end
end

----------------------
-- MARK: Data Setup --
----------------------

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

---@param res farsight.live.MatchData Modified in place!
---@param tokens string[]
---@param chars_after table<string, true>
---@return string[]
local function tokens_avail_get(res, tokens, chars_after)
    local res_labeled_targets = res.labeled_targets
    if next(res_labeled_targets) ~= nil then
        return ntt.i_discard_to(tokens, function(token)
            return chars_after[token] == true or res_labeled_targets[token] ~= nil
        end)
    end

    return ntt.i_discard_to(tokens, function(token)
        return chars_after[token] == true
    end)
end

---@param target farsight.Target
---@return uinteger
local function bit_pack_start(target)
    return target[1] * 16384 + target[2]
end
-- MID: This should be able to detect massive files and switch to a string key.

---@param res farsight.live.MatchData Modified in place!
---@param chars_after table<string, true>
local function res_intake_old_labels(res, chars_after)
    if state_res_current == nil then
        return
    end

    local packed_targets = res.packed_targets
    for i, target in ipairs(res.targets) do
        packed_targets[bit_pack_start(target)] = i
    end

    local old_targets = state_res_current.targets
    for old_label, old_label_idx in pairs(state_res_current.labeled_targets) do
        if chars_after[old_label] == nil then
            local old_target_key = bit_pack_start(old_targets[old_label_idx])
            local target_idx = packed_targets[old_target_key]
            if target_idx ~= nil then
                res_checked_add_label(res, old_label, target_idx)
            end
        end
    end
end

---@param last_row integer
---@param cur_row integer
---@param last_line string
---@param lines table<uinteger, string> 0-indexed.
---@return integer, string
local function get_line_for_after(last_row, cur_row, last_line, lines)
    if last_row == cur_row then
        return last_row, last_line
    else
        return cur_row, lines[cur_row]
    end
end

---@param res farsight.live.MatchData Assumes results are properly ordered.
---@param lines table<uinteger, string> 0-indexed.
---@return table<string, true>
local function chars_after_get(res, lines)
    local last_row = -1
    local line = ""
    local chars = {} ---@type table<string, true>
    for _, target in ipairs(res.targets) do
        last_row, line = get_line_for_after(last_row, target[1], line, lines)
        local char_start_1 = target[4] + 1
        if char_start_1 <= #line then
            local dist = vim.str_utf_end(line, char_start_1)
            chars[string.sub(line, char_start_1, char_start_1 + dist)] = true
        end
    end

    return chars
end

---@param cmdline_mod fun(cmdline:string): string
---@param match_range [uinteger, uinteger, uinteger, uinteger]
---@param win uinteger
---@param buf uinteger
---@param lines table<uinteger, string>
---@param tokens string[]
---@param upward boolean
local function targets_update(cmdline_mod, match_range, win, buf, lines, tokens, upward)
    state_cmdline = fn.getcmdline()
    if state_try_res_cache_as_current() then
        extmarks_refresh_from_current(buf)
        return
    end

    if state_try_stage_jump_from_label() then
        api.nvim_feedkeys("\27", "nt", false)
        return
    end

    local matcher = require('lua.farsight._match')
    local ok, ranges, err =
        matcher.ranges_live_get(cmdline_mod(state_cmdline), match_range, win, buf, lines)
    if not ok then
        state_err = err
        return
    end

    ---@cast ranges farsight.Target[]
    ---@type farsight.live.MatchData
    local res = {
        idxs_labeled = {},
        labeled_targets = {},
        packed_targets = {},
        targets = ranges,
    }

    local chars_after = chars_after_get(res, lines)
    res_intake_old_labels(res, chars_after)
    res_labels_add(res, tokens_avail_get(res, tokens, chars_after), upward)

    state_set_res_for_cur_cmdline(res)
    extmarks_refresh_from_current(buf)
end

local group_name = "farsight.live-input-listener"

local function listener_teardown()
    for _, autocmd in ipairs(api.nvim_get_autocmds({ group = group_name })) do
        local id = autocmd.id
        if id ~= nil then
            api.nvim_del_autocmd(id)
        end
    end
end

---@param range [uinteger, uinteger, uinteger, uinteger]
---@param win uinteger
---@param buf uinteger
---@param lines table<uinteger, string>
---@param upward boolean
---@param tokens string[]
local function listener_init(cmdline_modifier, range, win, buf, lines, tokens, upward)
    -- Re-create the group in case the previous del_autocmd failed to run.
    local group = api.nvim_create_augroup(group_name, {})
    api.nvim_create_autocmd("CmdlineChanged", {
        group = group,
        callback = function()
            targets_update(cmdline_modifier, range, win, buf, lines, tokens, upward)
        end,
    })

    -- Fires after CmdlineChanged
    api.nvim_create_autocmd("CursorMovedC", {
        group = group,
        callback = function()
            local cmdpos = fn.getcmdpos()
            if cmdpos < (#state_cmdline + 1) then
                api.nvim_feedkeys("\27", "nt", false)
                return
            end
        end,
    })
end

---@class farsight.live.MatchData
---@field idxs_labeled table<uinteger, true>
---@field labeled_targets table<string, uinteger>
---@field packed_targets table<uinteger, uinteger>
---@field targets farsight.Target[]

local M = {}

---@param win uinteger
---@param buf uinteger Assumes that `win` contains `buf`.
---@param upward boolean
---@param ctx farsight.live.Ctx
function M.live(win, buf, upward, ctx)
    if api.nvim_win_get_config(win).hide then
        api.nvim_echo({ { "Cannot jump in a hidden window", "WarningMsg" } }, false, {})
        return
    end

    local matcher = require('lua.farsight._match')
    local range, lines = matcher.live_info_get(win, buf, (upward and -1 or 1))
    api.nvim__ns_set(state_ns_dynamic, { wins = { win } })
    local _util = require("farsight._util")
    local dim = ctx.dim
    if dim then
        _util.dim_set_ns_and_extmarks(state_ns_dim, win, hl_dim, hl_priority_dim, range, buf)
    end

    local prompt = ctx.prompt .. " "
    listener_init(ctx.cmdline_modifier, range, win, buf, lines, ctx.tokens, upward)
    local ok_i, text_i = require("nvim-tools.ui").input({ prompt = prompt, scope = "buffer" })
    listener_teardown()

    state_resolve_jump_pos(ok_i, text_i, upward)
    local pos_ext, err = state_clean_and_export()
    api.nvim_buf_clear_namespace(buf, state_ns_dynamic, 0, -1)
    if dim then
        api.nvim_buf_clear_namespace(buf, state_ns_dim, 0, -1)
    end

    if ok_i == false then
        api.nvim_echo({ { "Input error: " .. (text_i or ""), hl_error } }, true, {})
        return
    elseif pos_ext[1] == -1 or pos_ext[2] == -1 then
        if #err > 0 then
            api.nvim_echo({ { err, hl_error } }, true, {})
        end

        return
    end

    if not ctx.keepjumps then
        api.nvim_cmd({ cmd = "norm", args = { "m'" }, bang = true }, {})
    end

    pos_ext[1], pos_ext[2] =
        require("farsight._util").ensure_state_for_omode(win, buf, pos_ext[1], pos_ext[2])

    local pos = require("nvim-tools.pos").ext_to_mark_pos(pos_ext)
    api.nvim_win_set_cursor(win, pos)
    local unfold = ctx.unfold
    if #unfold > 0 then
        api.nvim_cmd({ cmd = "norm", args = { unfold }, bang = true }, {})
    end

    ctx.on_jump(win, buf, pos)
end

return M

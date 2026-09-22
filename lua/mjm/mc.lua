-- Credits:
-- drowning-cat: https://github.com/neovim/neovim/discussions/41997#discussion-10848201

local api = vim.api
local fn = vim.fn

-- local ns_mc = api.nvim_create_namespace("nvim.multicursor")
-- local ns_mc_cursor = vim.api.nvim_create_namespace("nvim.multicursor.cursor")
-- local ns_mc_visual = vim.api.nvim_create_namespace("nvim.multicursor.visual")

local M = {}

---@param mc_marks vim.api.keyset.get_extmark_item[]
---@return [uinteger, uinteger][] 0,0 indexed. Row, col, extmark id.
local function map_mc_marks_keep_oob(mc_marks)
    return require("nvim-tools.table").i_filter_map_to(mc_marks, function(mc)
        return { mc[2], mc[3] }
    end)
end

---@param buf uinteger
---@param mc_marks vim.api.keyset.get_extmark_item[]
---@return [uinteger, uinteger][] 0,0 indexed. Row, col, extmark id.
local function map_mc_marks_discard_oob(buf, mc_marks)
    local buf_lines = api.nvim_buf_line_count(buf)
    local ntt = require("nvim-tools.table")
    ---@diagnostic disable-next-line: return-type-mismatch
    return ntt.i_filter_map_ctx_to(mc_marks, buf_lines, function(lines, mc)
        local row = mc[2]
        if row < lines then
            return { mc[2], mc[3] }
        end
    end)
end

---@param buf uinteger
---@param mc_marks vim.api.keyset.get_extmark_item[]
---@param keep_oob boolean
---@return [uinteger, uinteger][] 0,0 indexed. Row, col, extmark id.
local function map_mc_marks(buf, mc_marks, keep_oob)
    if keep_oob then
        return map_mc_marks_keep_oob(mc_marks)
    else
        return map_mc_marks_discard_oob(buf, mc_marks)
    end
end

---@class nvim-tools.mc.GetOpts
---(Default: `false`) Keep  out of bounds cursors.
---@field keep_oob boolean?

---@param buf integer
---@param opts? nvim-tools.mc.GetOpts
---@return [uinteger, uinteger][], [uinteger, uinteger]
---Both 0,0 indexed
local function mc_get(buf, opts)
    opts = opts ~= nil and require("nvim-tools.table").deepcopy(opts) or {}
    vim.validate("opts.insert_main", opts.insert_main, "boolean", true)
    vim.validate("opts.keep_oob", opts.keep_oob, "boolean", true)

    local ns_mc = api.nvim_create_namespace("nvim.multicursor")
    local mc_marks = api.nvim_buf_get_extmarks(buf, ns_mc, 0, -1)
    if opts.keep_oob == nil then
        opts.keep_oob = false
    end

    local mc_positions = map_mc_marks(buf, mc_marks, opts.keep_oob)
    local main = require("nvim-tools.pos").mark_to_ext_pos(api.nvim_win_get_cursor(0))
    return mc_positions, main
end

---@param mc_positions [uinteger, uinteger][] 0,0 indexed
---@param curpos_ext [uinteger, uinteger] 0,0 indexed
---@param upward boolean
---@param count1 uinteger
---@param wrap boolean
---@return uinteger, uinteger Jump idx, start idx
local function jump_find_idx(mc_positions, curpos_ext, upward, count1, wrap)
    local ntp = require("nvim-tools.pos")
    local idx_start = vim.list.bisect(mc_positions, curpos_ext, {
        key = function(pos)
            return ntp.bit_pack_pos(pos)
        end,
    })

    if upward then
        if wrap then
            local ntm = require("nvim-tools.math")
            return ntm.wrapping_sub(idx_start, count1, 1, #mc_positions), idx_start
        else
            ---@diagnostic disable-next-line: return-type-mismatch
            return math.max(idx_start - count1, 1), idx_start
        end
    else
        -- LOW: Hacky, but unsure how else to correct without inserting curpos_ext into
        -- mc_positions, which is a non-trivial cost.
        -- in_bounds var because bisect can return the index past the end.
        local in_bounds = idx_start <= #mc_positions
        if in_bounds and ntp.cmp_tbl(curpos_ext, mc_positions[idx_start]) < 0 then
            idx_start = idx_start - 1
        end

        if wrap then
            local ntm = require("nvim-tools.math")
            return ntm.wrapping_add(idx_start, count1, 1, #mc_positions), idx_start
        else
            return math.min(idx_start + count1, #mc_positions), idx_start
        end
    end
end

---@class mjm.mc.JumpOpts
---(Default: `true`) Leave a cursor behind
---@field leave boolean?
---(Default: `true`) Wrapping count
---@field wrap boolean?

---@class mjm.mc.JumpCtx
---@field leave boolean
---@field wrap boolean

---@param opts mjm.mc.JumpOpts Modified in place!
---@return mjm.mc.JumpCtx
local function jump_opts_to_ctx(opts)
    if opts.leave == nil then
        opts.leave = true
    end

    if opts.wrap == nil then
        opts.wrap = true
    end

    return opts --[[@as mjm.mc.JumpCtx]]
end

---@param cur_pos [uinteger, uinteger] 0,0 indexed
---@param dest_pos [uinteger, uinteger] 0,0 indexed
---@param leave boolean
local function main_cursor_move(cur_pos, dest_pos, leave)
    api.nvim_cmd({ cmd = "norm", args = { "m'" }, bang = true })
    local ntp = require("nvim-tools.pos")
    if leave then
        api.nvim_mcursor(0, ntp.ext_to_mark_pos(cur_pos))
    end

    -- NOTE: If the destination is an mcursor, and follow mode is on, this will take over the
    -- destination cursor.
    api.nvim_win_set_cursor(0, ntp.ext_to_mark_pos(dest_pos))
end

---@param upward boolean
---@param count1 uinteger
function M.vertical(upward, count1)
    -- TODO: Extremely hacky.
    if api.nvim__mcursor_cascading() then
        return false
    end

    vim.validate("upward", upward, "boolean")

    local cur_pos = api.nvim_win_get_cursor(0)
    local row = cur_pos[1]
    local line_count = api.nvim_buf_line_count(0)
    if (upward and row == 1) or ((not upward) and row == line_count) then
        return
    end

    local dest_pos = require("nvim-tools.table").i_copy(cur_pos)
    local step = upward and -1 or 1
    local start = dest_pos[1] + step
    local stop = upward and 2 or (line_count - 1)
    local remaining = count1
    local dest_row = start
    for i = start, stop, step do
        if remaining <= 1 then
            break
        end

        dest_pos[1] = dest_row
        api.nvim_mcursor(0, dest_pos)
        remaining = remaining - 1
        dest_row = i + step
    end

    dest_pos[1] = dest_row
    local ntp = require("nvim-tools.pos")
    ntp.mark_to_ext_pos(cur_pos)
    ntp.mark_to_ext_pos(dest_pos)
    main_cursor_move(cur_pos, dest_pos, true)
end
-- MID: This feels like a laborious way to write something simple.

---Adaptation of private core logic.
--- @param upward boolean
--- @param count1 uinteger
--- @param opts mjm.mc.JumpOpts?
--- @return boolean Did jump.
function M.jump(upward, count1, opts)
    -- TODO: Extremely hacky.
    if api.nvim__mcursor_cascading() then
        return false
    end

    opts = opts ~= nil and require("nvim-tools.table").deepcopy(opts) or {}
    vim.validate("opts", opts, "table")
    vim.validate("upward", upward, "boolean")
    vim.validate("count1", count1, require("nvim-tools.types").is_count1)

    local buf = api.nvim_get_current_buf()
    local mc_positions, cur_pos_ext = mc_get(buf)
    local mc_positions_len = #mc_positions
    if mc_positions_len == 0 then
        return false
    end

    local ctx = jump_opts_to_ctx(opts)
    local idx, start_idx = jump_find_idx(mc_positions, cur_pos_ext, upward, count1, ctx.wrap)
    if idx == start_idx then
        return false
    end

    main_cursor_move(cur_pos_ext, mc_positions[idx], ctx.leave)
    return true
end
-- TODO-DEP: This now merges cursors if follow mode is on. Wait to fix until the internals are
-- more baked in.

---@param range [uinteger, uinteger, uinteger, uinteger] 0,0,0,0 indexed, end-exclusive
---@param buf uinteger
---@return boolean
local function range_contains_mcursor(range, buf)
    local ntr = require("nvim-tools.range")
    local range_ext = ntr.ext_from_api(range)

    local ns_mc = api.nvim_create_namespace("nvim.multicursor")
    local mc_marks = api.nvim_buf_get_extmarks(
        buf,
        ns_mc,
        { range_ext[1], range_ext[2] },
        { range_ext[3], range_ext[4] },
        { limit = 1, overlap = true }
    )

    return #mc_marks > 0
end

---@param pos [uinteger, uinteger] 0,0 indexed
---@param buf uinteger
---@param pattern string
---@param offset uinteger
local function add_mcursor_at_text(pos, buf, pattern, offset)
    local ntb = require("nvim-tools.buf")
    local cword_range = ntb.line_match_under_cursor(pos, buf, pattern)
    if cword_range == nil then
        local msg = "Invalid pos: " .. vim.inspect(pos)
        api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
        return
    end

    if not range_contains_mcursor(cword_range, buf) then
        local mark_pos = { cword_range[1], cword_range[2] }
        mark_pos[2] = mark_pos[2] + offset
        api.nvim_mcursor(buf, require("nvim-tools.pos").ext_to_mark_pos(mark_pos))
    end
end

---@param upward boolean
---@param wrap boolean
---@return string
local function search_flags_get(upward, wrap)
    local flags = {} ---@type string[]
    flags[#flags + 1] = "n"
    if upward then
        flags[#flags + 1] = "b"
    else
        flags[#flags + 1] = "z"
    end

    if wrap then
        flags[#flags + 1] = "w"
    else
        flags[#flags + 1] = "W"
    end

    return table.concat(flags, "")
end

---@param pattern string
---@param count1 uinteger
---@param pattern string
---@param wrap boolean
---@return [uinteger, uinteger][]
local function search_results_collect(upward, count1, pattern, wrap)
    local results = {} ---@type [uinteger, uinteger][]
    local flags = search_flags_get(upward, wrap)
    local remaining = count1
    fn.search(pattern, flags, 0, 500, function()
        local row = vim.call("line", ".") - 1
        local col = vim.call("col", ".") - 1
        ---@cast row uinteger
        ---@cast col uinteger
        results[#results + 1] = { row, col }

        remaining = remaining - 1
        return remaining > 0 and 1 or 0
    end)

    return results
end

---@param opts mjm.mc.CwordOpts Modified in place!
---@return mjm.mc.CwordCtx
local function cword_opts_to_ctx(opts)
    if opts.leave == nil then
        opts.leave = true
    end

    if opts.wrap == nil then
        opts.wrap = true
    end

    return opts --[[@as mjm.mc.CwordCtx]]
end

---@class mjm.mc.CwordOpts
---(Default: `true`) Leave a cursor behind
---@field leave boolean?
---(Default: `true`) Wrapping count
---@field wrap boolean?

---@class mjm.mc.CwordCtx
---@field leave boolean
---@field wrap boolean

---@param upward boolean
---@param count1 uinteger
---@param opts mjm.mc.CwordOpts
function M.cwords(upward, count1, opts)
    -- TODO: Extremely hacky.
    if api.nvim__mcursor_cascading() then
        return false
    end

    opts = opts ~= nil and require("nvim-tools.table").deepcopy(opts) or {}
    vim.validate("opts", opts, "table")
    vim.validate("upward", upward, "boolean")
    vim.validate("count1", count1, require("nvim-tools.types").is_count1)

    local cur_pos_ext = require("nvim-tools.win").cursor_ext_get(0)
    local buf = api.nvim_get_current_buf()
    local ntb = require("nvim-tools.buf")
    local cword_range = ntb.line_match_under_cursor(cur_pos_ext, buf, "\\k\\+")
    if cword_range == nil then
        api.nvim_echo({ { "Cursor is not on a cword" } }, false, {})
        return
    end

    local ctx = cword_opts_to_ctx(opts)
    local pattern = "\\M" .. ntb.text_from_range(cword_range, buf)
    local results = search_results_collect(upward, count1, pattern, ctx.wrap)
    local results_len = #results
    if results_len == 0 then
        return
    end

    local offset = math.max(cur_pos_ext[2] - cword_range[2], 0)
    for i = 1, results_len - 1 do
        add_mcursor_at_text(results[i], buf, pattern, offset)
    end

    local dest_pos = results[#results]
    dest_pos[2] = dest_pos[2] + offset
    main_cursor_move(cur_pos_ext, dest_pos, ctx.leave)
end

---@class mjm.mc.MatchesOpts
---(Default: `true`) Wrapping count
---@field wrap boolean?

---@class mjm.mc.MatchesCtx
---@field wrap boolean

---@param opts mjm.mc.MatchesOpts Modified in place!
---@return mjm.mc.MatchesCtx
local function matches_opts_to_ctx(opts)
    if opts.wrap == nil then
        opts.wrap = true
    end

    return opts --[[@as mjm.mc.MatchesCtx]]
end

---@param upward boolean
---@param count1 uinteger
---@param opts mjm.mc.MatchesOpts?
function M.matches(upward, count1, opts)
    -- TODO: Extremely hacky.
    if api.nvim__mcursor_cascading() then
        return false
    end

    opts = opts ~= nil and require("nvim-tools.table").deepcopy(opts) or {}
    vim.validate("opts", opts, "table")
    vim.validate("upward", upward, "boolean")
    vim.validate("count1", count1, require("nvim-tools.types").is_count1)

    local reg_text = fn.getreg("/")
    ---@cast reg_text string
    if reg_text == "" then
        api.nvim_echo({ { "No previous regular expression" } }, false, {})
        return
    end

    local ctx = matches_opts_to_ctx(opts)
    local results = search_results_collect(upward, count1, reg_text, ctx.wrap)
    local results_len = #results
    if results_len == 0 then
        return
    end

    local cur_pos_ext = require("nvim-tools.win").cursor_ext_get(0)
    local buf = api.nvim_get_current_buf()
    local ntb = require("nvim-tools.buf")
    local cursor_range = ntb.line_match_under_cursor(cur_pos_ext, buf, reg_text)
    local offset = 0 ---@type uinteger
    local on_match = cursor_range ~= nil
    if on_match then
        offset = math.max(cur_pos_ext[2] - cursor_range[2], 0)
        ---@cast offset uinteger
    end

    for i = 1, results_len - 1 do
        add_mcursor_at_text(results[i], buf, reg_text, offset)
    end

    local dest_pos = results[#results]
    dest_pos[2] = dest_pos[2] + offset
    main_cursor_move(cur_pos_ext, dest_pos, on_match)
end

---@param buf uinteger
---@return [uinteger, uinteger, uinteger, uinteger][], [uinteger, uinteger, uinteger, uinteger]
local function mc_visuals_get(buf)
    local ns_vis = api.nvim_create_namespace("nvim.multicursor.visual")
    local extmarks = api.nvim_buf_get_extmarks(buf, ns_vis, 0, -1, { details = true })
    local ntt = require("nvim-tools.table")
    local ntr = require("nvim-tools.range")
    local converted = ntt.i_filter_map_to(extmarks, ntr.api_from_extmark)

    local ntm = require("nvim-tools.misc")
    local vregion = ntm.region_from_positions(".", "v", "v")
    local vrange = ntr.from_region(vregion)
    if api.nvim_get_option_value("sel", { scope = "global" }) ~= "exclusive" then
        vrange[4] = vrange[4] + 1
    end

    ntr.qf_to_api(vrange)
    return converted, vrange
end
-- TODO: Need to add keep_oob opt here.

---@param upward boolean
---@param count1 uinteger
function M.rotate_mc(upward, count1)
    -- TODO: Extremely hacky.
    if api.nvim__mcursor_cascading() then
        return
    end

    vim.validate("upward", upward, "boolean")
    vim.validate("count1", count1, require("nvim-tools.types").is_count1)

    local buf = api.nvim_get_current_buf()
    local converted, vrange = mc_visuals_get(buf)
    local ntr = require("nvim-tools.range")
    local at = ntr.ranges_bisect(converted, vrange)
    if ntr.cmp_(converted[at], vrange) ~= 0 then
        table.insert(converted, at, vrange)
    end

    local ntt = require("nvim-tools.table")
    ---@diagnostic disable-next-line: assign-type-mismatch
    local texts = ntt.i_filter_map_ctx_to(converted, buf, function(b, r)
        return api.nvim_buf_get_text(b, r[1], r[2], r[3], r[4])
    end)

    ntt.i_rotate(texts, count1, upward and -1 or 1)
    for i = #converted, 1, -1 do
        local c = converted[i]
        api.nvim_buf_set_text(0, c[1], c[2], c[3], c[4], texts[i])
    end
end
-- TODO: This function does not intelligently keep the old visual selection and cursor position
-- around when replacing with the new text. Am loathe to try coding in this behavior when the
-- underlying architecture is still being developed.

return M

-- TODO: Split visual selection into multiple cursors
-- TODO: I/A split selections by line for insert before/after (every visual mode can function like
-- block mode)
-- TODO: Split visual selection by regex
-- TODO: Within a visual selection, split by search matches
-- TODO: Based on the primary cursor's selection, add a new cursor with the same visual selection
-- above or below if it exists.

-- TODO-DEP: Hold on this until the finalized interfaces drop and the surrounding ecosystem is
-- more mature.

-- TODO: Backwards searches catch the result under cursor unless the cursor is on the very first
-- character. Unsure how to fix in a non-hacky way.

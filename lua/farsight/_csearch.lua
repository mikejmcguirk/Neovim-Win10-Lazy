local api = vim.api
local fn = vim.fn

local matcher = require("farsight._match")
local ntt = require("nvim-tools.table")
local ntp = require("nvim-tools.pos")
local _util = require("farsight._util")

local HUGE_INT = 2 ^ 53

-------------------------------------
-- MARK: Namespaces and Highlights --
-------------------------------------

local state_ns_dim = api.nvim_create_namespace("farsight.csearch.dim")
local state_ns_labels = api.nvim_create_namespace("farsight.csearch.labels")
local state_ns_on_key = api.nvim_create_namespace("farsight.csearch.on_key")

do
    -- TODO-DEP: Remove this when 0.14 comes out.
    api.nvim_set_hl(0, "Dimmed", { default = true, link = "Comment" })

    api.nvim_set_hl(0, "farsightCsearchDim", { default = true, link = "Dimmed" })
    api.nvim_set_hl(0, "farsightCsearchChar", { default = true, link = "Search" })
    api.nvim_set_hl(0, "farsightCsearchCurChar", { default = true, link = "CurSearch" })
    api.nvim_set_hl(0, "farsightCsearchLabel1st", { default = true, link = "IncSearch" })
    api.nvim_set_hl(0, "farsightCsearchLabel2nd", { default = true, link = "CurSearch" })
    api.nvim_set_hl(0, "farsightCsearchLabel3rd", { default = true, link = "Search" })
end

local hl_dim = api.nvim_get_hl_id_by_name("farsightCsearchDim")
local hl_char = api.nvim_get_hl_id_by_name("farsightCsearchChar")
local hl_cur_char = api.nvim_get_hl_id_by_name("farsightCsearchCurChar")
local hl_label_1 = api.nvim_get_hl_id_by_name("farsightCsearchLabel1st")
local hl_label_2 = api.nvim_get_hl_id_by_name("farsightCsearchLabel2nd")
local hl_label_3 = api.nvim_get_hl_id_by_name("farsightCsearchLabel3rd")

local hl_priority_dim = vim.hl.priorities.user + 50
local hl_priority_label = hl_priority_dim + 1
local hl_priority_cur_char = hl_priority_label + 1

---@param buf uinteger
---@param dim boolean
local function init_jump_clear_all_hls(buf, dim)
    api.nvim_buf_clear_namespace(buf, state_ns_labels, 0, -1)
    if dim then
        api.nvim_buf_clear_namespace(buf, state_ns_dim, 0, -1)
    end
end

-------------------------
-- MARK: General State --
-------------------------

local state_char = ""
-- TODO-DEP: Save state_char since it comes from user-input. `till` and `upward` should both
-- consistently come from the same func params on dot-repeat. Can save those though if a case
-- comes up that breaks this.

---------------------------------
-- MARK: Continuation State --
---------------------------------

local is_cont_mode = false
local cont_buf = 0 ---@type uinteger
local cont_win = 0 ---@type uinteger
local cont_top = HUGE_INT
local cont_bot = 1
local cont_did_csearch = false
local cont_cur_char_extmark = -1

local cont_group_name = "farsight.csearch.continuation-listeners"

local function continuation_teardown()
    if not is_cont_mode then
        return
    end

    for _, autocmd in ipairs(api.nvim_get_autocmds({ group = cont_group_name })) do
        local id = autocmd.id
        if id ~= nil then
            api.nvim_del_autocmd(id)
        end
    end

    vim.on_key(nil, state_ns_on_key)

    -- Providers are cleared when this function is run.
    api.nvim_set_decoration_provider(state_ns_labels)
    api.nvim_buf_clear_namespace(cont_buf, state_ns_dim, 0, -1)
    api.nvim_buf_clear_namespace(cont_buf, state_ns_labels, 0, -1)

    is_cont_mode = false
end

---@param ranges [uinteger, uinteger, uinteger, uinteger][]
local function cont_char_extmarks_set(ranges)
    local opts = { hl_group = hl_char, priority = hl_priority_label, strict = false }
    for _, range in ipairs(ranges) do
        opts.end_row = range[3]
        opts.end_col = range[4]
        api.nvim_buf_set_extmark(cont_buf, state_ns_labels, range[1], range[2], opts)
    end
end

---@param top uinteger 0-indexed
---@param bot uinteger 0-indexed
---@return integer, integer, uinteger, uinteger All 0-indexed, inclusive
local function cont_expanded_range_get(top, bot)
    if top < cont_top then
        return top, cont_top - 1, top, cont_bot
    elseif cont_bot < bot then
        return cont_bot + 1, bot, cont_top, bot
    else
        return -1, -1, cont_top, cont_bot
    end
end

---@param win uinteger
---@param top uinteger
---@param bot uinteger
local function on_win(_, win, buf, top, bot)
    -- Has to be checked, even with namespace scoping.
    if win ~= cont_win then
        return
    end

    -- Need to check this for buffer switches.
    if buf ~= cont_buf then
        return
    end

    local start_row, end_row, new_top, new_bot = cont_expanded_range_get(top, bot)
    if start_row < 0 or end_row < 0 then
        return
    end

    local ranges = matcher.csearch_cont_results_get(start_row, end_row, cont_buf, state_char)
    cont_char_extmarks_set(ranges)
    cont_top = new_top
    cont_bot = new_bot
end

---@param pos [uinteger, uinteger] 0,0 indexed
---@param till boolean
---@param upward boolean
local function cont_set_cur_char_mark(pos, till, upward)
    api.nvim_buf_del_extmark(cont_buf, state_ns_labels, cont_cur_char_extmark)

    local row = pos[1]
    local col = pos[2]
    local state_char_len = #state_char
    if till then
        if upward then
            col = col - state_char_len
        else
            col = ntp.utf_advance_col(cont_buf, row, col)
        end
    end

    ---@cast col uinteger
    cont_cur_char_extmark = api.nvim_buf_set_extmark(cont_buf, state_ns_labels, row, col, {
        end_row = row,
        end_col = col + state_char_len,
        hl_group = hl_cur_char,
        priority = hl_priority_cur_char,
        strict = false,
    })
end

---@param win uinteger
---@param buf uinteger
---@param top uinteger -- 0 indexed
---@param bot uinteger -- 0 indexed
---@param till boolean
---@param upward boolean
---@param jump_pos [uinteger, uinteger] 0,0 indexed
---@param cancel_keys string[]
local function continuation_begin(win, buf, top, bot, jump_pos, till, upward, cancel_keys)
    if is_cont_mode then
        return
    end

    cont_win = win
    cont_buf = buf
    cont_top = top
    cont_bot = bot
    cont_did_csearch = true

    cont_set_cur_char_mark(jump_pos, till, upward)
    local ranges = matcher.csearch_cont_results_get(cont_top, cont_bot, cont_buf, state_char)
    cont_char_extmarks_set(ranges)

    -- TODO-DEP: When 0.14 comes out, remove the opt table.
    local group = api.nvim_create_augroup(cont_group_name, {})
    api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = vim.schedule_wrap(function()
            if api.nvim_get_current_buf() ~= cont_buf then
                continuation_teardown()
            end
        end),
    })

    api.nvim_create_autocmd("CursorMoved", {
        group = group,
        callback = function()
            if api.nvim_get_current_win() ~= cont_win then
                return
            end

            if cont_did_csearch then
                cont_did_csearch = false
                return
            end

            local cur_ext = require("nvim-tools.win").cursor_ext_get(cont_win)
            local marks = api.nvim_buf_get_extmarks(cont_buf, state_ns_labels, cur_ext, cur_ext, {
                limit = 1,
            })

            if #marks > 0 then
                return
            else
                continuation_teardown()
            end
        end,
    })

    api.nvim_create_autocmd("ModeChanged", {
        group = group,
        callback = function()
            local event = vim.v.event
            ---@diagnostic disable-next-line: undefined-field
            local old_byte = string.byte(event.old_mode, 1)
            ---@diagnostic disable-next-line: undefined-field
            local new_byte = string.byte(event.new_mode, 1)
            local n_c = old_byte == 110 and new_byte == 99
            local c_n = old_byte == 99 and new_byte == 110
            if not (n_c or c_n) then
                continuation_teardown()
            end
        end,
    })

    -- If you delete a char then enter continuation mode, TextChanged fires for some reason.
    api.nvim_buf_attach(cont_buf, false, {
        on_lines = function()
            continuation_teardown()
            return true -- Detach
        end,
    })

    api.nvim_create_autocmd("WinEnter", {
        group = group,
        callback = vim.schedule_wrap(function()
            if api.nvim_get_current_win() ~= cont_win then
                continuation_teardown()
            end
        end),
    })

    vim.on_key(function(key, typed)
        if #ntt.i_overlap(nil, true, { key, typed }, cancel_keys) > 0 then
            if string.byte(api.nvim_get_mode().mode, 1) ~= 99 then
                continuation_teardown()
            end
        end
    end, state_ns_on_key)

    api.nvim_set_decoration_provider(state_ns_labels, { on_win = on_win })
    is_cont_mode = true
    api.nvim__redraw({ flush = false, valid = true, win = win })
end

-------------------
-- MARK: Jumping --
-------------------

---@param keepjumps boolean
---@param upward boolean
---@param top uinteger
---@param bot uinteger
---@param jump_row uinteger
---@return boolean
local function should_set_pcmark(keepjumps, upward, top, bot, jump_row)
    if not keepjumps then
        return false
    end

    if upward then
        return jump_row < top
    else
        return bot < jump_row
    end
end

---@param char string
---@param upward boolean
---@param till boolean
---@param mode_status 0|1|2|3
---@param exclusive boolean
---@return string
local function pattern_resolve(char, upward, till, mode_status, exclusive)
    local pattern = string.gsub(char, "\\", "\\\\")
    local pattern_tbl = { "\\C" }

    if upward then
        pattern_tbl[#pattern_tbl + 1] = "\\V"
        pattern_tbl[#pattern_tbl + 1] = pattern
        if till then
            pattern_tbl[#pattern_tbl + 1] = "\\zs"
            pattern_tbl[#pattern_tbl + 1] = "\\m."
        end
    else
        if till then
            if not (mode_status == 2 and exclusive) then
                pattern_tbl[#pattern_tbl + 1] = "\\m."
                pattern_tbl[#pattern_tbl + 1] = "\\ze"
            end

            pattern_tbl[#pattern_tbl + 1] = "\\V"
            pattern_tbl[#pattern_tbl + 1] = pattern
        else
            pattern_tbl[#pattern_tbl + 1] = "\\V"
            pattern_tbl[#pattern_tbl + 1] = pattern

            if mode_status == 2 and exclusive then
                pattern_tbl[#pattern_tbl + 1] = "\\zs"
                pattern_tbl[#pattern_tbl + 1] = "\\m."
            end
        end
    end

    return table.concat(pattern_tbl, "")
end

---@param char string
---@param upward boolean
---@param till boolean
---@param count1 uinteger
---@param top uinteger 0-indexed
---@param bot uinteger 0-indexed
---@param mode_status 0|1|2|3
---@param win uinteger
---@param buf uinteger
---@param ctx farsight.csearch.Ctx
---@return boolean, [uinteger, uinteger]
local function do_jump(char, upward, till, count1, top, bot, mode_status, win, buf, ctx)
    local exclusive = api.nvim_get_option_value("selection", { scope = "global" }) == "exclusive"
    local pattern = pattern_resolve(char, upward, till, mode_status, exclusive)
    local jump_pos = { -1, -1 } ---@type [integer, integer]
    fn.search(pattern, (upward and "Wnb" or "Wnz"), 0, 500, function()
        jump_pos[1] = vim.call("line", ".")
        jump_pos[2] = vim.call("col", ".")
        if count1 > 1 then
            count1 = count1 - 1
            return 1
        else
            return 0
        end
    end)

    ntp.eval_to_ext_pos(jump_pos)
    if jump_pos[1] < 0 or jump_pos[2] < 0 then
        return false, jump_pos
    end

    local set_pcmark = should_set_pcmark(ctx.keepjumps, upward, top, bot, jump_pos[1])
    if set_pcmark then
        api.nvim_cmd({ cmd = "norm", args = { "m'" }, bang = true }, {})
    end

    if mode_status == 2 then
        if upward and not exclusive then
            local cur_pos = ntp.mark_to_ext_pos(api.nvim_win_get_cursor(win))
            if cur_pos[1] > 0 or cur_pos[2] > 0 then
                local col = math.max(ntp.utf_decrease_col(buf, cur_pos[1], cur_pos[2]), 0)
                cur_pos[2] = col
                ntp.ext_to_eval_pos(cur_pos)
                -- Avoid nvim_win_set_cursor bookkeeping
                fn.cursor(cur_pos[1], cur_pos[2])
            end
        end

        api.nvim_cmd({ cmd = "norm", args = { "v" }, bang = true }, {})
    end

    ntp.ext_to_mark_pos(jump_pos)
    api.nvim_win_set_cursor(win, jump_pos)
    local unfold = ctx.unfold
    if #unfold > 0 then
        api.nvim_cmd({ cmd = "norm", args = { unfold }, bang = true }, {})
    end

    -- TODO-DEP: This could cause goofy behaviors if it modifies text, but I don't want to create
    -- guard code in the abstract.
    ctx.on_jump(win, buf, jump_pos)

    ntp.mark_to_ext_pos(jump_pos)
    return true, jump_pos
end

-------------------------
-- MARK: Jump Labeling --
-------------------------

---@class (private) farsight.csearch.Traversal
---@field counts table<uinteger, integer>
---@field [1] [uinteger, uinteger, uinteger, uinteger][]
---@field [2] [uinteger, uinteger, uinteger, uinteger][]
---@field [3] [uinteger, uinteger, uinteger, uinteger][]

---@param ranges [uinteger, uinteger, uinteger, uinteger][] Assumes:
---- Ranges are 0,0,0,0 indexed, end-exclusive
---- Ranges are ordered
---- Ranges are restricted to a single line
---- Ranges already conform to the line's utf8 boundaries.
---@param lines table<uinteger, string>
---@param till boolean
---@param traversal farsight.csearch.Traversal
---@param init uinteger
local function ranges_get_hls_rev(ranges, lines, till, traversal, init)
    local get_utf8_codepoint = require("farsight._util").get_utf8_codepoint
    local counts = traversal.counts

    local last_row = -1
    local line = ""
    for r = #ranges, 1, -1 do
        local range = ranges[r]
        local row = range[1]
        if row ~= last_row then
            last_row = row
            line = lines[row]
        end

        -- get_utf8_codepoint is one-indexed
        local i = range[4]
        -- Reverse till searches skip the last character
        if till and i == #line then
            i = i - 1 + vim.str_utf_start(line, i)
        end

        while i >= range[2] + 1 do
            ---@cast i uinteger
            local codepoint, len_codepoint = get_utf8_codepoint(line, i)
            if len_codepoint > 0 then
                local count = counts[codepoint]
                if count == nil then
                    count = init
                end

                if count < 3 then
                    count = count + 1
                    if count >= 1 then
                        local start_col = i - 1
                        local end_col = start_col + len_codepoint -- End-exclusive
                        local traversal_count = traversal[count]
                        traversal_count[#traversal_count + 1] = { row, start_col, row, end_col }
                    end

                    counts[codepoint] = count
                end
            end

            i = i - 1
        end
    end
end
-- TODO-DEP: If we find a meaningful case where a search result would create ranges that don't
-- conform to the line's UTF-8 bounds, can add a guard to make sure the codepoint doesn't run
-- over the range boundary.

---@param ranges [uinteger, uinteger, uinteger, uinteger][] Assumes:
---- Ranges are 0,0,0,0 indexed, end-exclusive
---- Ranges are ordered
---- Ranges are restricted to a single line
---@param lines table<uinteger, string>
---@param till boolean
---@param traversal farsight.csearch.Traversal
---@param init integer
local function ranges_get_hls_fwd(ranges, lines, till, traversal, init)
    local get_utf8_codepoint = require("farsight._util").get_utf8_codepoint
    local counts = traversal.counts

    local last_row = -1
    local line = ""
    for _, range in ipairs(ranges) do
        local row = range[1]
        if row ~= last_row then
            last_row = row
            line = lines[row]
        end

        -- get_utf8_codepoint is one-indexed
        local i = range[2] + 1
        -- A fwd till search will skip the first character of a line
        if till and i == 1 then
            i = i + 1 + vim.str_utf_end(line, i)
        end

        while i <= range[4] do
            local codepoint, len_codepoint = get_utf8_codepoint(line, i)
            if len_codepoint > 0 then
                local count = counts[codepoint]
                if count == nil then
                    count = init
                end

                if count < 3 then
                    count = count + 1
                    if count >= 1 then
                        local start_col = i - 1
                        local end_col = start_col + len_codepoint -- End-exclusive
                        local traversal_count = traversal[count]
                        traversal_count[#traversal_count + 1] = { row, start_col, row, end_col }
                    end

                    counts[codepoint] = count
                end

                i = i + len_codepoint
            else
                i = i + 1
            end
        end
    end
end

---@param hls [uinteger, uinteger, uinteger, uinteger][]
---@param buf uinteger
---@param hl_group uinteger
local function hl_labels_set(hls, buf, hl_group)
    local opts = { hl_group = hl_group, priority = hl_priority_label, strict = false }
    for _, hl in ipairs(hls) do
        opts.end_row = hl[3]
        opts.end_col = hl[4]
        api.nvim_buf_set_extmark(buf, state_ns_labels, hl[1], hl[2], opts)
    end
end

---@param win uinteger
---@param buf uinteger
---@param upward boolean
---@param count1 uinteger
---@param till boolean
---@param ctx farsight.csearch.Ctx
local function base_hls_set(win, buf, upward, count1, till, ctx)
    local match_area = matcher.csearch_match_area_get(win, buf, upward and -1 or 1)
    if ctx.dim then
        _util.dim_set_ns_and_extmarks(state_ns_dim, win, hl_dim, hl_priority_dim, match_area, buf)
    end

    local ranges, lines = matcher.csearch_initial_labels_get(buf, match_area, ctx.pattern)
    ---@type farsight.csearch.Traversal
    local traversal = { counts = {}, [1] = {}, [2] = {}, [3] = {} }
    local init = 1 - count1
    if upward then
        ranges_get_hls_rev(ranges, lines, till, traversal, init)
    else
        ranges_get_hls_fwd(ranges, lines, till, traversal, init)
    end

    hl_labels_set(traversal[1], buf, hl_label_1)
    hl_labels_set(traversal[2], buf, hl_label_2)
    hl_labels_set(traversal[3], buf, hl_label_3)
    api.nvim__redraw({ flush = true, valid = true, win = win })
end

-------------------
-- MARK: Routing --
-------------------

---@param upward boolean
---@param count1 uinteger
---@param till boolean
---@param top uinteger 0-indexed
---@param bot uinteger 0-indexed
---@param mode_status 0|1|2|3
---@param ctx farsight.csearch.Ctx
local function cont_jump(upward, till, count1, top, bot, mode_status, ctx)
    cont_did_csearch = true
    local ok, pos =
        do_jump(state_char, upward, till, count1, top, bot, mode_status, cont_win, cont_buf, ctx)
    if ok then
        cont_set_cur_char_mark(pos, till, upward)
    else
        cont_did_csearch = false
        api.nvim_buf_del_extmark(cont_buf, state_ns_labels, cont_cur_char_extmark)
    end
end

local M = {}

---@return 0|1, boolean
local function cont_mode_ensure_valid()
    local is_repeating = require("farsight._util").get_is_repeating()
    local is_reg_executing = fn.reg_executing() ~= ""
    if is_cont_mode and (is_repeating == 1 or is_reg_executing) then
        continuation_teardown()
    end

    return is_repeating, is_reg_executing
end

---@return 0|1|2|3
---- 3: `noV` mode
---- 2: `o` mode
---- 1: `v` mode
---- 0: Everything else
local function mode_status_get()
    local mode = api.nvim_get_mode().mode
    local ntm = require("nvim-tools.misc")
    if #mode >= 2 and string.byte(mode, 1) == 110 and string.byte(mode, 2) == 111 then
        if #mode > 2 and ntm.is_vmode(string.sub(mode, 3)) then
            return 3
        end

        return 2
    end

    return ntm.is_vmode(mode) and 1 or 0
end

---@param win uinteger
---@param buf uinteger
---@param count1 uinteger
---@param upward boolean
---@param till boolean
---@param ctx farsight.csearch.Ctx
function M.csearch(win, buf, count1, upward, till, ctx)
    local mode_status = mode_status_get()
    local is_repeating, is_reg_executing = cont_mode_ensure_valid()
    local top = fn.line("w0", win) - 1
    local bot = fn.line("w$", win) - 1
    if is_cont_mode then
        cont_jump(upward, till, count1, top, bot, mode_status, ctx)
        return
    end

    if is_repeating == 1 or is_reg_executing then
        do_jump(state_char, upward, till, count1, top, bot, mode_status, win, buf, ctx)
        return
    end

    api.nvim__ns_set(state_ns_labels, { wins = { win } })
    base_hls_set(win, buf, upward, count1, till, ctx)
    local _, char = pcall(fn.getcharstr, -1)
    init_jump_clear_all_hls(buf, ctx.dim)
    if char == "\27" or char == "\3" or char == "\r" then
        return
    end

    local ok, jump_pos = do_jump(char, upward, till, count1, top, bot, mode_status, win, buf, ctx)
    if ok then
        state_char = char
    else
        return
    end

    if mode_status > 0 then
        return
    end

    continuation_begin(win, buf, top, bot, jump_pos, till, upward, ctx.cancel_keys)
end

---@return boolean
function M.is_in_continuation_mode()
    return is_cont_mode
end

return M

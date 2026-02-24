local api = vim.api
local fn = vim.fn

---@class farsight.search.HlInfo
---@field [1] integer Length
---@field [2] integer[] Start rows
---@field [3] integer[] Start cols
---@field [4] integer[] Fin rows
---@field [5] integer[] Fin cols

---@class farsight.search.DimHlInfo
---@field [1] integer Length
---@field [2] integer[] Start rows
---@field [3] integer[] Fin rows

local TIMEOUT = 500

local HL_DIM_STR = "FarsightSearchDim"
api.nvim_set_hl(0, HL_DIM_STR, { default = true, link = "Comment" })
local hl_dim = api.nvim_get_hl_id_by_name(HL_DIM_STR)

local dim_ns = api.nvim_create_namespace("farsight-search-dim")
local search_ns = api.nvim_create_namespace("farsight-search-hl")

local search_group = api.nvim_create_augroup("farsight-search-hl", {})

---@param win integer
---@param buf integer
---@param fwd boolean
---@return farsight.search.HlInfo, integer, boolean, integer[]|nil
local function get_win_search_data(win, buf, fwd)
    local tn = require("farsight.util")._table_new
    ---@type farsight.search.HlInfo
    local hl_info = { 0, tn(64, 0), tn(64, 0), tn(64, 0), tn(64, 0) }

    if fwd then
        local common = require("farsight._common")
        local wS = fn.line("w$")
        local stop_row, valid = common.get_wrap_checked_bot_row(win, buf, wS)
        return hl_info, stop_row, valid, nil
    else
        -- Get the data to restore with the vimfn later
        local cursor = fn.getcurpos()
        local stop_row = cursor[2]
        local valid = true
        return hl_info, stop_row, valid, cursor
    end
end

---Edits hl_info and line_cache in place
---@param buf integer
---@param hl_info farsight.search.HlInfo
---@param line_cache table<integer, string>
local function fix_jit_raw_hl_info(buf, hl_info, line_cache)
    local len_hl_info = hl_info[1]
    local hl_rows = hl_info[2]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]

    -- Convert search_match_lines to end rows
    for i = 1, len_hl_info do
        hl_fin_rows[i] = hl_rows[i] + hl_fin_rows[i]
    end

    local line_count = api.nvim_buf_line_count(buf)
    local nvim_buf_get_lines = api.nvim_buf_get_lines

    local last_row = -1
    local line

    for i = len_hl_info, 1, -1 do
        -- Handle OOB "foo\n" searches on the last line
        local row = hl_fin_rows[i]
        if row > line_count then
            hl_fin_rows[i] = line_count
            if row ~= last_row then
                last_row = row
                line = line_cache[row]
                if not line then
                    line = nvim_buf_get_lines(buf, line_count - 1, line_count, false)[1]
                    line_cache[row] = line
                end
            end

            hl_fin_cols[i] = #line
        else
            break
        end
    end
end

---Edits line_cache in place
---@param win integer
---@param buf integer
---@param cmdline string
---@param fwd boolean
---@param line_cache table<integer, string>
---@param opts farsight.search.SearchOpts
---@return boolean, farsight.search.HlInfo, boolean, integer[]|nil
local function create_raw_hl_info_jit(win, buf, cmdline, fwd, line_cache, opts)
    local hl_info, stop_row, valid, cursor = get_win_search_data(win, buf, fwd)

    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]
    local call = vim.call
    local ffi_c = require("ffi").C

    if (not fwd) and cursor then
        -- Use the vimfn because nvim_win_set_cursor updates the view and pushes a redraw
        fn.cursor(fn.line("w0"), 1, 0)
    end

    -- If searching in reverse, the entries closest to the cursor will be pulled last, so using
    -- count in the skip function does not work. Still use count if searching forward, as skipping
    -- is cheaper than editing the arrays later.
    local count1 = fwd and vim.v.count1 or 1
    local ok, _ = pcall(call, "search", cmdline, "nWz", stop_row, opts.timeout, function()
        if count1 <= 1 then
            hl_rows[#hl_rows + 1] = call("line", ".")
            hl_cols[#hl_cols + 1] = call("col", ".")
            hl_fin_rows[#hl_fin_rows + 1] = ffi_c.search_match_lines --[[ @as integer ]]
            hl_fin_cols[#hl_fin_cols + 1] = ffi_c.search_match_endcol --[[ @as integer ]]

            hl_info[1] = hl_info[1] + 1
            return 1
        else
            count1 = count1 - 1
            return 1
        end
    end)

    if (not fwd) and cursor then
        fn.cursor({ cursor[2], cursor[3], cursor[4], cursor[5] })
    end

    if ok then
        fix_jit_raw_hl_info(buf, hl_info, line_cache)
    end

    return ok, hl_info, valid, cursor
end

---@param win integer
---@param buf integer
---@param cmdline string
---@param fwd boolean
---@param _ table<integer, string>
---@param opts farsight.search.SearchOpts
---@return boolean, farsight.search.HlInfo, boolean, integer[]|nil
local function create_raw_hl_info_puc(win, buf, cmdline, fwd, _, opts)
    local hl_info, stop_row, valid, cursor = get_win_search_data(win, buf, fwd)

    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]
    local call = vim.call

    if (not fwd) and cursor then
        -- Use the vimfn because nvim_win_set_cursor updates the view and pushes a redraw
        fn.cursor(fn.line("w0"), 1, 0)
    end

    -- If searching in reverse, the entries closest to the cursor will be pulled last, so using
    -- count in the skip function does not work. Still use count if searching forward, as skipping
    -- is cheaper than editing the arrays later.
    local count1 = fwd and vim.v.count1 or 1
    local ok_s, _ = pcall(call, "search", cmdline, "nWz", stop_row, opts.timeout, function()
        if count1 <= 1 then
            hl_rows[#hl_rows + 1] = call("line", ".")
            hl_cols[#hl_cols + 1] = call("col", ".")
            hl_info[1] = hl_info[1] + 1
            return 1
        else
            count1 = count1 - 1
        end
    end)

    if not ok_s then
        if (not fwd) and cursor then
            fn.cursor({ cursor[2], cursor[3], cursor[4], cursor[5] })
        end

        return ok_s, hl_info, valid
    end

    count1 = vim.v.count1
    local ok_f, _ = pcall(call, "search", cmdline, "nWze", stop_row, opts.timeout, function()
        if count1 <= 1 then
            hl_fin_rows[#hl_fin_rows + 1] = call("line", ".")
            hl_fin_cols[#hl_fin_cols + 1] = call("col", ".")
            return 1
        else
            count1 = count1 - 1
            return 1
        end
    end)

    if (not fwd) and cursor then
        fn.cursor({ cursor[2], cursor[3], cursor[4], cursor[5] })
    end

    if ok_f then
        local len_hl_info = hl_info[1]
        -- Verify both loops captured the same number of results. |zero-width| assertions can cause
        -- issues if searching backward
        local count_hl_info = #hl_info
        for i = 2, count_hl_info do
            if #hl_info[i] ~= len_hl_info then
                return false, hl_info, valid, cursor
            end
        end
    end

    return ok_f, hl_info, valid, cursor
end

local create_raw_hl_info = (function()
    if require("farsight._common").has_ffi_search_globals() then
        return create_raw_hl_info_jit
    else
        return create_raw_hl_info_puc
    end
end)()

---@param buf integer
---@param dim_hl_info farsight.search.DimHlInfo|nil
---@param dim boolean
local function checked_set_dim_extmarks(buf, dim_hl_info, dim)
    if not (dim_hl_info and dim) then
        return
    end

    local nvim_buf_set_extmark = api.nvim_buf_set_extmark
    local dim_rows = dim_hl_info[2]
    local dim_fin_rows = dim_hl_info[3]

    local extmark_opts = {
        end_col = 0,
        hl_eol = true,
        hl_group = hl_dim,
        priority = 998,
    }

    local len_dim_hl_info = dim_hl_info[1]
    for i = 1, len_dim_hl_info do
        extmark_opts.end_row = dim_fin_rows[i] + 1
        pcall(nvim_buf_set_extmark, buf, dim_ns, dim_rows[i], 0, extmark_opts)
    end
end

---@param buf integer
---@param hl_info farsight.search.HlInfo
---@param incsearch boolean
local function set_search_extmarks(buf, hl_info, incsearch)
    local len_hl_info = hl_info[1]
    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols_ = hl_info[5]

    local start = 1
    if incsearch then
        start = 2
        pcall(api.nvim_buf_set_extmark, buf, search_ns, hl_rows[1], hl_cols[1], {
            priority = 1000,
            hl_group = "IncSearch",
            strict = false,
            end_row = hl_fin_rows[1],
            end_col = hl_fin_cols_[1],
        })
    end

    local extmark_opts = {
        priority = 999,
        hl_group = "Search",
        strict = false,
    }

    for i = start, len_hl_info do
        extmark_opts.end_row = hl_fin_rows[i]
        extmark_opts.end_col = hl_fin_cols_[i]
        pcall(api.nvim_buf_set_extmark, buf, search_ns, hl_rows[i], hl_cols[i], extmark_opts)
    end
end

---Assumes that hl_info has at least one entry and that overlapping entries have been merged
---@param hl_info farsight.search.HlInfo
---@param dim boolean
---@return farsight.search.DimHlInfo|nil
local function checked_get_dim_rows(hl_info, dim)
    if not dim then
        return
    end

    local len_hl_info = hl_info[1]
    local hl_rows = hl_info[2]
    local hl_fin_rows = hl_info[4]

    local tn = require("farsight.util")._table_new
    local dim_hl_info = { 0, tn(32, 0), tn(32, 0) } ---@type farsight.search.DimHlInfo
    local dim_rows = dim_hl_info[2]
    local dim_fin_rows = dim_hl_info[3]

    dim_rows[1] = hl_rows[1]
    dim_fin_rows[1] = hl_fin_rows[1]

    local j = 1
    for i = 2, len_hl_info do
        if dim_fin_rows[j] < hl_rows[i] + 1 then
            j = j + 1
            dim_rows[j] = hl_rows[i]
            dim_fin_rows[j] = hl_fin_rows[i]
        else
            dim_fin_rows[j] = hl_fin_rows[i]
        end
    end

    dim_hl_info[1] = j
    return dim_hl_info
end

---@param buf integer
---@param dim boolean
local function checked_clear_namespaces(buf, dim)
    api.nvim_buf_clear_namespace(buf, search_ns, 0, -1)
    if dim then
        api.nvim_buf_clear_namespace(buf, dim_ns, 0, -1)
    end
end

---@param win integer
---@param buf integer
---@param dim boolean
---@param valid boolean
local function clear_ns_and_redraw(win, buf, dim, valid)
    checked_clear_namespaces(buf, dim)
    api.nvim__redraw({ valid = valid, win = win })
end

---@param win integer
---@param buf integer
---@param hl_info farsight.search.HlInfo|string
---@param valid boolean
---@param opts farsight.search.SearchOpts
local function handle_hl_info_err(win, buf, hl_info, valid, opts)
    if opts.debug_msgs and type(hl_info) == "string" then
        api.nvim_echo({ { hl_info, "ErrorMsg" } }, true, {})
    end

    clear_ns_and_redraw(win, buf, opts.dim, valid)
end

---Edits hl_info in place
---Assumes zero-based, exclusive indexing
---Assumes hl_info has at least one entry
---Always perform this check because, even with cpo-c not present, the C core's searchit()
---function does not properly handle searching from after the end of multiline matches.
---We still do assume that an extmark can never start before the previous one.
---@param hl_info farsight.search.HlInfo
---@param incsearch boolean
local function merge_hl_info_entries(hl_info, incsearch)
    local init_len_hl_info = hl_info[1]
    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols_ = hl_info[5]

    local start = incsearch and 3 or 2
    local j = start - 1
    for i = start, init_len_hl_info do
        local cur_fin_row = hl_fin_rows[j]
        local cur_fin_col = hl_fin_cols_[j]
        local test_row = hl_rows[i]
        local test_col = hl_cols[i]
        local test_fin_row = hl_fin_rows[i]
        local test_fin_col = hl_fin_cols_[i]

        local col_before = cur_fin_row == test_row and cur_fin_col < test_col
        if col_before or cur_fin_row < test_row then
            j = j + 1
            hl_rows[j] = test_row
            hl_cols[j] = test_col
            hl_fin_rows[j] = test_fin_row
            hl_fin_cols_[j] = test_fin_col
        else
            local fin_row_before = cur_fin_row < test_fin_row
            if fin_row_before or cur_fin_row == test_fin_row and cur_fin_col < test_fin_col then
                hl_fin_rows[j] = test_fin_row
                hl_fin_cols_[j] = test_fin_col
            end

            -- Implicitly do nothing if cur_fin_pos >= test_fin_pos
        end
    end

    hl_info[1] = j
    for i = j + 1, init_len_hl_info do
        hl_rows[i] = nil
        hl_cols[i] = nil
        hl_fin_rows[i] = nil
        hl_fin_cols_[i] = nil
    end
end

---Edits hl_info in place
---Change 1, 1 search() results to extmark indexing
---@param hl_info farsight.search.HlInfo
local function adjust_hl_info_indexing(hl_info)
    local len_hl_info = hl_info[1]
    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]

    for i = 1, len_hl_info do
        hl_rows[i] = hl_rows[i] - 1
        hl_cols[i] = hl_cols[i] - 1
        hl_fin_rows[i] = hl_fin_rows[i] - 1
        hl_fin_cols[i] = hl_fin_cols[i] - 1
    end
end

---Edits hl_info in place
---Assumes entries are still 1,1 indexed
---@param cursor [integer, integer, integer, integer]
---@param hl_info farsight.search.HlInfo
local function trim_rev_entries(cursor, hl_info)
    local cur_row = cursor[2]
    local cur_col_1 = cursor[3]

    local len_hl_info = hl_info[1]
    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]

    -- Searching from the top of the screen might cause results to run over the stop_row on the
    -- cursor line.
    for i = len_hl_info, 1, -1 do
        local start_row = hl_rows[i]
        local start_col_1 = hl_cols[i]

        local start_above = start_row < cur_row
        if start_above or (start_row == cur_row and start_col_1 < cur_col_1) then
            break
        else
            hl_info[1] = hl_info[1] - 1
            hl_rows[i] = nil
            hl_cols[i] = nil
            hl_fin_rows[i] = nil
            hl_fin_cols[i] = nil
        end
    end

    -- Because the entries closest to the cursor are searched last, they cannot be skipped when
    -- searching.
    len_hl_info = hl_info[1]
    local to_trim = vim.v.count1 - 1
    while to_trim > 0 do
        to_trim = to_trim - 1

        local idx = len_hl_info - to_trim
        hl_info[1] = hl_info[1] - 1
        hl_rows[idx] = nil
        hl_cols[idx] = nil
        hl_fin_rows[idx] = nil
        hl_fin_cols[idx] = nil
    end
end

---Edits hl_info and line_cache in place
---Assumes hl_info entries are still 1, 1 indexed search() results
---@param buf integer
---@param hl_info farsight.search.HlInfo
---@param line_cache table<integer, string>
---@param fwd boolean
---@param cursor [integer, integer, integer, integer]|nil
local function adjust_hl_info_vals(buf, hl_info, line_cache, fwd, cursor)
    local len_hl_info = hl_info[1]
    local hl_rows = hl_info[2]
    local hl_cols = hl_info[3]
    local hl_fin_rows = hl_info[4]
    local hl_fin_cols = hl_info[5]

    -- Handle results of |zero-width| assertions
    for i = 1, len_hl_info do
        hl_fin_cols[i] = math.max(hl_fin_cols[i], 1)
        if hl_rows[i] == hl_fin_rows[i] and hl_fin_cols[i] < hl_cols[i] then
            hl_fin_cols[i] = hl_cols[i]
        end
    end

    local min = math.min
    local nvim_buf_get_lines = api.nvim_buf_get_lines

    local last_row = -1
    local line
    for i = 1, len_hl_info do
        local row = hl_rows[i]
        if row ~= last_row then
            last_row = row
            line = line_cache[row]
            if not line then
                line = nvim_buf_get_lines(buf, row - 1, row, false)[1]
                line_cache[row] = line
            end
        end

        -- Handle OOB results from \n chars and zero length lines
        hl_cols[i] = min(hl_cols[i], #line)
    end

    local get_utf_codepoint = require("farsight._util_char")._get_utf_codepoint
    local str_byte = string.byte

    for i = 1, len_hl_info do
        local row = hl_fin_rows[i]
        if row ~= last_row then
            last_row = row
            line = line_cache[row]
            if not line then
                line = nvim_buf_get_lines(buf, row - 1, row, false)[1]
                line_cache[row] = line
            end
        end

        local len_line = #line
        if len_line > 0 then
            local fin_col_1 = min(hl_fin_cols[i], len_line)
            local b1 = str_byte(line, fin_col_1) or 0
            local _, len_char = get_utf_codepoint(line, b1, fin_col_1)
            hl_fin_cols[i] = fin_col_1 + len_char
        else
            hl_fin_cols[i] = 2
        end
    end

    if (not fwd) and cursor then
        -- Wait until now so we are operating on clean data.
        trim_rev_entries(cursor, hl_info)
    end
end

---@param fwd boolean
---@param cmdline string
---@param hl_info farsight.search.HlInfo
---@return string
local function get_hl_info_err_str(fwd, cmdline, hl_info)
    local err_tbl = {}

    err_tbl[#err_tbl + 1] = "Prompt: " .. (fwd and "/" or "?")
    err_tbl[#err_tbl + 1] = ", Pattern: " .. cmdline
    err_tbl[#err_tbl + 1] = ", Total length: " .. hl_info[1]
    err_tbl[#err_tbl + 1] = ", #Start rows: " .. #hl_info[2]
    err_tbl[#err_tbl + 1] = ", #Start cols: " .. #hl_info[3]
    err_tbl[#err_tbl + 1] = ", #Fin Rows: " .. #hl_info[4]
    err_tbl[#err_tbl + 1] = ", #Fin Cols: " .. #hl_info[5]

    return table.concat(err_tbl, "")
end

---Edits line_cache in place
---@param win integer
---@param buf integer
---@param fwd boolean
---@param cmdline string
---@param line_cache table<integer, string>
---@param incsearch boolean
---@param opts farsight.search.SearchOpts
---@return boolean, farsight.search.HlInfo|string, boolean
local function get_hl_info(win, buf, fwd, cmdline, line_cache, incsearch, opts)
    local ok, hl_info, valid, cursor = create_raw_hl_info(win, buf, cmdline, fwd, line_cache, opts)
    if not ok then
        local err_str = get_hl_info_err_str(fwd, cmdline, hl_info)
        return ok, err_str, valid
    end

    if hl_info[1] >= 1 then
        adjust_hl_info_vals(buf, hl_info, line_cache, fwd, cursor)
        adjust_hl_info_indexing(hl_info)
        merge_hl_info_entries(hl_info, incsearch)
    end

    return ok, hl_info, valid
end

---@param cmdprompt string
---@param cmdline_raw string
---@return string, string
local function parse_search_offset(cmdprompt, cmdline_raw)
    local BACKSLASH = 0x5C
    local str_byte = string.byte
    local prompt_byte = str_byte(cmdprompt)

    local i = 1
    local len = #cmdline_raw
    local escaping = false
    while i <= len do
        local c = str_byte(cmdline_raw, i)
        if escaping then
            escaping = false
        elseif c == BACKSLASH then
            escaping = true
        elseif c == prompt_byte then
            local cmdline = string.sub(cmdline_raw, 1, i - 1)
            local offset = string.sub(cmdline_raw, i + 1)
            return cmdline, offset
        end

        i = i + 1
    end

    return cmdline_raw, ""
end

---@param win integer
---@param buf integer
---@param fwd boolean
---@param incsearch boolean
---@param dim boolean
local function handle_empty_cmdline(win, buf, fwd, incsearch, dim)
    checked_clear_namespaces(buf, dim)

    local valid = true
    if fwd or ((not fwd) and incsearch) then
        local common = require("farsight._common")
        local wS = fn.line("w$")
        local _, checked_valid = common.get_wrap_checked_bot_row(win, buf, wS)
        valid = checked_valid
    end

    api.nvim__redraw({ valid = valid, win = win })
end

---@param win integer
---@param buf integer
---@param prompt string
---@param opts farsight.search.SearchOpts
local function display_search_highlights(win, buf, prompt, opts)
    if fn.getcmdprompt() ~= prompt then
        return
    end

    ---@type boolean
    local is = api.nvim_get_option_value("is", { scope = "global" })
    local fwd = prompt == "/"
    local cmdline_raw = fn.getcmdline()
    if cmdline_raw == "" then
        handle_empty_cmdline(win, buf, fwd, is, opts.dim)
        return
    end

    local cmdline, _ = parse_search_offset(prompt, cmdline_raw)
    local line_cache = {} ---@type table<integer, string>
    local ok, hl_info, valid = get_hl_info(win, buf, fwd, cmdline, line_cache, is, opts)
    local r_ok, r_hl_info, r_valid
    if is then
        -- Get this before handling hl_info because we need the returned valid value in case it
        -- is false. Otherwise, wrapped filler rows might not be redrawn
        local r_fwd = not fwd
        r_ok, r_hl_info, r_valid = get_hl_info(win, buf, r_fwd, cmdline, line_cache, is, opts)
        if r_valid == false then
            valid = r_valid
        end

        if (not r_ok) or type(r_hl_info) ~= "table" then
            handle_hl_info_err(win, buf, r_hl_info, valid, opts)
            return
        elseif hl_info[1] == 0 and r_hl_info[1] == 0 then
            clear_ns_and_redraw(win, buf, opts.dim, valid)
            return
        end
    end

    if (not ok) or type(hl_info) ~= "table" then
        handle_hl_info_err(win, buf, hl_info, valid, opts)
        return
    elseif (not is) and hl_info[1] == 0 then
        clear_ns_and_redraw(win, buf, opts.dim, valid)
        return
    end

    local dim_hl_info = checked_get_dim_rows(hl_info, opts.dim)
    checked_clear_namespaces(buf, opts.dim)
    set_search_extmarks(buf, hl_info, is)
    checked_set_dim_extmarks(buf, dim_hl_info, opts.dim)
    if is then
        -- Always pass false. Search will not jump here
        set_search_extmarks(buf, r_hl_info, false)
        -- Reverse IncSearch highlights are not valid targets. Don't dim.
    end

    api.nvim__redraw({ valid = valid, win = win })
end

local function del_search_listener()
    local autocmds = api.nvim_get_autocmds({ group = search_group })
    for _, autocmd in ipairs(autocmds) do
        api.nvim_del_autocmd(autocmd.id)
    end
end

---@param win integer
---@param buf integer
---@param prompt string
---@param opts farsight.search.SearchOpts
local function create_search_listener(win, buf, prompt, opts)
    api.nvim_create_autocmd("CmdlineChanged", {
        group = search_group,
        desc = "Highlight search terms",
        callback = function()
            display_search_highlights(win, buf, prompt, opts)
            -- TODO: Display labels if that opt is true
        end,
    })
end

---@param win integer
---@param dim boolean
local function checked_ns_set(win, dim)
    api.nvim__ns_set(search_ns, { wins = { win } })
    if dim then
        api.nvim__ns_set(dim_ns, { wins = { win } })
    end
end

---@param cur_buf integer
---@param opts farsight.search.SearchOpts
local function resolve_search_opts(cur_buf, opts)
    vim.validate("opts", opts, "table")
    local ut = require("farsight.util")

    opts.debug_msgs = ut._use_gb_if_nil(opts.debug_msgs, "farsight_search_debug_msgs", cur_buf)
    opts.debug_msgs = ut._resolve_bool_opt(opts.debug_msgs, false)

    opts.dim = ut._use_gb_if_nil(opts.dim, "farsight_search_dim", cur_buf)
    opts.dim = ut._resolve_bool_opt(opts.dim, false)

    opts.keepjumps = ut._use_gb_if_nil(opts.keepjumps, "farsight_search_keepjumps", cur_buf)
    opts.keepjumps = ut._resolve_bool_opt(opts.keepjumps, false)

    opts.timeout = ut._use_gb_if_nil(opts.timeout, "farsight_search_timeout", cur_buf)
    if opts.timeout == nil then
        opts.timeout = TIMEOUT
    else
        vim.validate("opts.timeout", opts.timeout, ut._is_int)
    end

    -- TODO: Add keepjumps option. How to make work with feedkeys?
end

local M = {}

---@class farsight.search.SearchOpts
---Dim lines with targeted characters (Default: `false`)
---@field debug_msgs? boolean
---@field dim? boolean
---@field keepjumps? boolean
---@field timeout? integer

---@param fwd boolean
---@param opts? farsight.search.SearchOpts
function M.search(fwd, opts)
    opts = opts and vim.deepcopy(opts) or {}
    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)
    resolve_search_opts(cur_buf, opts)

    -- TODO: Check if we are dot repeating or in a macro. If so, check if the "/" register has
    -- contents. If so, search for that and return.
    -- NOTE: Forward searches operate until just before the term. Backard searches operate until
    -- and including the beginning of the term.
    -- Since this is a direct search, wrapscan needs to be handled

    checked_clear_namespaces(0, opts.dim)
    checked_ns_set(cur_win, opts.dim)

    local prompt = fwd and "/" or "?"
    create_search_listener(cur_win, cur_buf, prompt, opts)

    -- pcall so that pressing Ctrl+c does not enter error
    local ok, pattern_raw = pcall(fn.input, prompt)

    del_search_listener()
    local pattern, _ = parse_search_offset(prompt, pattern_raw)
    if not ok or pattern == "" then
        checked_clear_namespaces(cur_buf, opts.dim)
        -- TODO: This needs to check for the keyboard interrupt error specifically
        api.nvim_echo({ { "" } }, false, {}) -- LOW: I wish there was a less blunt way
        return
    end

    -- TODO: This looks nicer but might create an extra redraw step. Profile
    if opts.dim then
        api.nvim_buf_clear_namespace(cur_buf, dim_ns, 0, -1)
    end

    local arg_parts = {
        'vim.api.nvim_feedkeys("',
        tostring(vim.v.count1),
        prompt,
        string.gsub(pattern_raw, "\\", "\\\\"),
        '\\r","nx",false)',
    }

    local args = { table.concat(arg_parts, "") }
    local mods = { keepjumps = opts.keepjumps }
    api.nvim_cmd({ cmd = "lua", args = args, mods = mods }, {})
    -- Running this right before running search can cause flicker
    api.nvim_buf_clear_namespace(cur_buf, search_ns, 0, -1)
end

function M.get_ns()
    return search_ns
end

return M

-- TODO: The cursor location should be visible during searches.
-- TODO: Properly support folds. My understanding so far:
-- - Only the first result in a fold is considered
-- - If a highlight would be in a fold, it is discarded
--   - Removing extmarks from within folds is an obvious win, but double-check the actual
--   behavior as well as what is considered standard for something like this
-- TODO: Does performing search with feedkeys properly handle fdo?
-- TODO: Handle repeats and macros. I think you just get vcount1 and feed an empty search string
-- to make it repeat. Macros might not be able to get around having to input, but highlights can
-- still be disabled.
-- TODO: Verify Vim's internal timeout for search
-- TODO: Test visual mode behavior
-- TODO: Test omode behavior
-- TODO: Go through the tests to make sure there aren't any functionalities or corner cases I
-- need to cover.
-- - test/unit/search_spec.lua
-- - test/old/testdir/test_search.vim
-- TODO: IncSearch hl priority should be > Search.

-- TODO: DOCUMENT: IncSearch emulation is incomplete. Setting IncSearch to true will produce
-- IncSearch style highlighting. However, the cursor will not automatically advance and
-- <C-t>/<C-g> commands will not work.
-- TODO: DOCUMENT: Farsight will always display "Search" highlights in the direction the user
-- entered. With IncSearch on, backward facing labels will also be displayed. IncSearch will also
-- cause the next result to display with an IncSearch highlight. Labels will only be calculated
-- and added to results after the cursor.
-- TODO: DOCUMENT: |search-offset| is supported
-- TODO: DOCUMENT: Search highlights will always show in the direction you are searching
-- TODO: DOCUMENT: Highlighting only one way is intentional.
-- TODO: DOCUMENT: Limitation: Ctrl-T/Ctrl-G navigation with Incsearch are not supported
-- TODO: DOCUMENT: Make some sort of useful documentation out of my error with running nohlsearch
-- on cmdline enter
-- TODO: DOCUMENT: cpo c is respected
--
-- LABELS
--
-- TODO: Labels should not accept if the cursor is not in the last position. Maybe don't even
-- show labels, or show them with a different highlight. Prevents issue with going back and
-- TODO: The default highlights here have to work with CurSearch and IncSearch. Being that this is
-- the lowest degrees of freedom module, it is the anchor point for the others.
-- modifying the search
-- TODO: Should have fold behavior similar to Csearch. Either skip folds entirely, or affix labels
-- in a reasonable manner. If there's no good way to apply labels, I'm fine with always skipping.
-- TODO: Label jumps should have an on_jump option. The default should be a reasonable application
-- of fdo
-- Should saving searchforward/histadd/searchreg for labels be an option or something handled in
-- on_jump?
-- Labels should only go in the direction of the search. Want to keep possibilities down so
-- useful labeling can be done more quickly. Omni-directional should be handled in jump
-- TODO: There might be interesting stuff we can do with \%V (search inside the visual area only)
-- On the baseline level, if the user wants to make that custom mapping, where you exit visual
-- mode (update the marks) and then run search with that magic pre-filled, it should do so
-- smoothly

-- MID: Is winhighlight properly respected?
-- MID: The built-in search highlights zero length lines. Extmark highlights do not display on
-- them. The only way I can think of to deal with this is to manually traverse the results and pick
-- out the zero-length lines within. Those lines can then have virtual text laid on top of them.
-- MID: Results off-screen should be reported. Intuitively, it should be a virtual text overlay
-- on the top/bottom of the window. Blocker: What fallbacks should be used if the overlay would
-- cover a label? Easier version: Only show this if no on-screen results.
-- - Is searchcount() useful here?
-- MID: Implement <C-t>/<C-g> navigation.
-- Blocker questions:
-- - Should IncSearch's auto-forward cursor movement be supported? I do not use it, but it's a
-- core component of how IncSearch functions. Because this version of search has non-IncSearch
-- highlights I'm comfortable with, I'm directionally okay with making IncSearch match its
-- default behavior
-- - Is any sort of displaying being done for searches above/below the screen? Might influence how
-- IncSearch should behave
-- Questions about built-in behavior:
-- - Do <C-t>/<C-g> accept count?
-- - Do they respect wrapscan?
-- - What happens if you go into a fold?
-- - Based on user input, when is the temporary home abandoned? When does the temporary home
-- advance? Go back? My approximate answers from light testing:
--   - If the user adds text, the cursor tries to advance forward, either at the current position
--   or to a future one if it's found. This seems to respect wrapscan
--   - If the user removes search characters, the cursor tries to find a location backwards but
--   closest to its temporary home
--   - The cursor does not go backward past the origin
--   - If a match produces no results, but there is text in the cmdline, the temporary home will
--   not be abandoned. If the cmdline is cleared, it will be
--   - How is the current position considered? It seems to straightforwardly be a matter of if the
--   cursor overlaps with the search. But there could be nuance I'm missing.
-- - Other Questions:
--   - How would <Ctrl-t>/<Ctrl-g> be intercepted and processed? Naive but possibly correct answer:
--     Look at the last character of the cmdline, manually edit the cmdline, then process the char
--   - How can the cursor be moved without triggering scrolloff? This is also relevant for
--   potentially removing backward searches from the codebase
--   - How would the original cur_pos be stored? I think you can pass it as part of the autocmd
--   closure
--   - Does the temporary home need to be stored in module level state? Or, if the cursor is
--   being moved, is getting the current cur_pos sufficient?
--   - When cmdline is updated, how do we check if the cursor is on a valid match? I would guess
--   using search() with the "c" flag
--
-- LOW: A potential optimization would be to look for contiguous search results and merging them
-- together. Since the end_cols are end-exclusive indexed, this is not infeasible. You would make
-- a loop that iterates through and merges in the next index if possible, then niling the
-- remainder. This *could* help with redraws. Low priority because it's complexity surface area
-- and extmark rendering is not the biggest bottleneck at the moment.
-- LOW: It would be better if hl_info and rev_hl_info were one big array. Splitting them in two
-- defeats the purpose of using a struct of arrays to begin with.
-- LOW: When getting search positions, it might be faster to run getpos() rather than line() and
-- col(). My concern is that getpos() allocates a table. This would need to be profiled.
--
-- NON: Do not re-implement cursor movement for IncSearch. This is performance intensive, creates
-- complexity surface area, and is visually too busy.
-- NON: Multi-window searching. Creates weird questions with wrap scan. Creates a problem where
-- even if you replicate the proper window ordering, it's not necessarily intuitive to which
-- window you will jump to.
-- NON: Multi-directional searching. Creates weird questions with how the v:vars are updated.
-- Jump handles this.
-- NON: Grafting this on top of the default search. This would require listeners/autocmds to
-- always be running, which means persistent state + the plugin insisting on itself. Harder to
-- turn off if unwanted. It also means that I don't have full-stepwise control over the relevant
-- events.

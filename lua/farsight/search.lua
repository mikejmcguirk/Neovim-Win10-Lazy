local api = vim.api
local fn = vim.fn

---@class farsight.search.DimHlInfo
---@field [1] integer Length
---@field [2] integer[] Start rows
---@field [3] integer[] Fin rows

local TIMEOUT = 500

local HL_SEARCH_STR = "FarsightSearch"
local HL_SEARCH_AHEAD_STR = "FarsightSearchAhead"
local HL_SEARCH_TARGET_STR = "FarsightSearchTarget"
local HL_DIM_STR = "FarsightSearchDim"

api.nvim_set_hl(0, HL_SEARCH_STR, { default = true, link = "DiffChange" })
api.nvim_set_hl(0, HL_SEARCH_AHEAD_STR, { default = true, link = "DiffText" })
api.nvim_set_hl(0, HL_SEARCH_TARGET_STR, { default = true, link = "DiffAdd" })
api.nvim_set_hl(0, HL_DIM_STR, { default = true, link = "Comment" })

local hl_search_next = api.nvim_get_hl_id_by_name(HL_SEARCH_STR)
local hl_search_ahead = api.nvim_get_hl_id_by_name(HL_SEARCH_AHEAD_STR)
local hl_search_target = api.nvim_get_hl_id_by_name(HL_SEARCH_TARGET_STR)
local hl_dim = api.nvim_get_hl_id_by_name(HL_DIM_STR)

local hl_is = api.nvim_get_hl_id_by_name("IncSearch")
local hl_search = api.nvim_get_hl_id_by_name("Search")

local dim_ns = api.nvim_create_namespace("farsight-search-dim")
local search_ns = api.nvim_create_namespace("farsight-search-hl")

local search_group = api.nvim_create_augroup("farsight-search-hl", {})

---@param buf integer
---@param res farsight.common.SearchResults
---@param is boolean
---@param dir -1|1
local function set_search_extmarks(buf, res, is, dir)
    local len_res = res[2]
    local start = dir == 1 and 1 or len_res
    local stop = dir == 1 and len_res or 1

    local res_idxs = res[3]
    local res_rows = res[4]
    local res_cols = res[5]
    local res_fin_rows = res[6]
    local res_fin_cols_ = res[7]

    if is then
        local idx = res_idxs[start]
        start = start + dir
        api.nvim_buf_set_extmark(buf, search_ns, res_rows[idx], res_cols[idx], {
            priority = 1000,
            hl_group = hl_is,
            strict = false,
            end_row = res_fin_rows[idx],
            end_col = res_fin_cols_[idx],
        })
    end

    local extmark_opts = {
        priority = 999,
        hl_group = hl_search,
        strict = false,
    }

    for i = start, stop, dir do
        local idx = res_idxs[i]
        extmark_opts.end_row = res_fin_rows[idx]
        extmark_opts.end_col = res_fin_cols_[idx]
        api.nvim_buf_set_extmark(buf, search_ns, res_rows[idx], res_cols[idx], extmark_opts)
    end
end

---Assumes that overlapping entries have been merged
---@param res farsight.common.SearchResults 0 indexed, exclusive
---@param dim boolean
---@return farsight.search.DimHlInfo|nil
local function checked_get_dim_rows_from_res(res, dim)
    if not dim then
        return
    end

    local len_res = res[2]
    if len_res < 1 then
        return
    end

    local res_idxs = res[3]
    local res_rows = res[4]
    local res_fin_rows = res[6]

    local tn = require("farsight.util")._table_new
    local dim_hl_info = { 0, tn(32, 0), tn(32, 0) } ---@type farsight.search.DimHlInfo
    local dim_rows = dim_hl_info[2]
    local dim_fin_rows = dim_hl_info[3]

    local first_idx = res_idxs[1]
    dim_rows[1] = res_rows[first_idx]
    dim_fin_rows[1] = res_fin_rows[first_idx]

    local j = 1
    for i = 2, len_res do
        local idx = res_idxs[i]
        if dim_fin_rows[j] < res_rows[idx] + 1 then
            j = j + 1
            dim_rows[j] = res_rows[idx]
            dim_fin_rows[j] = res_fin_rows[idx]
        else
            dim_fin_rows[j] = res_fin_rows[idx]
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
---@param msg farsight.common.SearchResults|string
---@param hl table<integer, table<integer, string>>|string|nil
---@param opts farsight.search.SearchOpts
local function handle_targets_err(win, msg, hl, opts)
    require("farsight.util")._echo(not opts.debug_msgs, msg, hl)
    api.nvim__redraw({ valid = false, win = win })
end

---Edits res in place
---Always perform this check because, even with cpo-c not present, the C core's searchit()
---function does not properly handle searching from after the end of multiline matches.
---We still do assume that a result can never start before the previous one.
---@param res farsight.common.SearchResults 0 indexed, exclusive
---@param incsearch boolean
local function merge_res(res, incsearch)
    local init_len_res = res[2]
    local start = incsearch and 3 or 2
    if init_len_res < start then
        return
    end

    local res_idxs = res[3]
    local res_rows = res[4]
    local res_cols = res[5]
    local res_fin_rows = res[6]
    local res_fin_cols_ = res[7]

    local j = start - 1
    for i = start, init_len_res do
        local idx = res_idxs[i]
        local dst = res_idxs[j]
        local cur_fin_row = res_fin_rows[dst]
        local cur_fin_col = res_fin_cols_[dst]
        local test_row = res_rows[idx]
        local test_col = res_cols[idx]

        local col_before = cur_fin_row == test_row and cur_fin_col < test_col
        -- cur_pos before test_pos. Compact.
        if col_before or cur_fin_row < test_row then
            j = j + 1
            res_idxs[j] = idx
        else
            local test_fin_col = res_fin_cols_[idx]
            local test_fin_row = res_fin_rows[idx]

            local fin_row_before = cur_fin_row < test_fin_row
            -- Overlapping ranges. Merge.
            if fin_row_before or cur_fin_row == test_fin_row and cur_fin_col < test_fin_col then
                res_fin_rows[dst] = test_fin_row
                res_fin_cols_[dst] = test_fin_col
            end

            -- Implicitly do nothing if cur_fin_pos >= test_fin_pos
        end
    end

    res[2] = j
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
            local str_sub = string.sub
            local cmdline = str_sub(cmdline_raw, 1, i - 1)
            local offset = str_sub(cmdline_raw, i + 1)
            return cmdline, offset
        end

        i = i + 1
    end

    return cmdline_raw, ""
end

-- Prefer home row, then top, then bottom.
-- Prefer index/middle fingers.
-- Index prefers to go down. Middle and ring prefer to go up.
-- Prefer right hand due to keyboard slope.
-- Because tokens will be filtered based on chars after, prefer ergonomics over memorizable
-- ordering.
-- To avoid over-subjectivity, group finger/row combinations. Put all shift keys after.
local tokens = vim.split("kdjflsaieowghmvtnurybpqcxzKDJFLSAIEOWGHMVTNURYBPQCXZ", "")

---@param win integer
---@param buf integer
---@param prompt string
---@param search_ctx farsight.common.SearchCtx
---@param is boolean
---@param is_ctx farsight.common.SearchCtx|nil
---@param valid boolean
---@param opts farsight.search.SearchOpts
local function display_search_highlights(win, buf, prompt, search_ctx, is, is_ctx, valid, opts)
    if vim.call("getcmdprompt") ~= prompt then
        return
    end

    local dim = opts.dim ---@type boolean
    checked_clear_namespaces(buf, dim)
    local cmdline_raw = vim.call("getcmdline") ---@type string
    local cmdline, _ = parse_search_offset(prompt, cmdline_raw)
    local common = require("farsight._common")
    if not common.is_valid_pattern(cmdline) then
        api.nvim__redraw({ valid = false, win = win })
        return
    end

    local cache = {} ---@type table<integer, table<integer, string>>
    local ok, targets, err_hl = common.search(win, cmdline, cache, search_ctx)

    local r_ok, r_targets, r_err_hl
    if is and is_ctx then
        r_ok, r_targets, r_err_hl = common.search(win, cmdline, cache, is_ctx)

        if (not r_ok) or type(r_targets) == "string" then
            handle_targets_err(win, r_targets, r_err_hl, opts)
            return
        end
    end

    if (not ok) or type(targets) == "string" then
        handle_targets_err(win, targets, err_hl, opts)
        return
    end

    if targets[2] > 0 then
        local labeler = require("farsight._labeler")
        labeler.fill_labels({ win }, { [win] = targets }, tokens, cache, {
            allow_partial = true,
            cursor = search_ctx.cursor,
            filter_next = true,
            locations = "finish",
            max_tokens = 1,
            is_upward = true,
        })

        labeler.fill_virt_text(targets, 1, 1, {
            hl_next = hl_search_next,
            hl_ahead = hl_search_ahead,
            hl_last = hl_search_target,
            locations = "finish",
            start_row = search_ctx.start_row,
            stop_row = search_ctx.stop_row,
            use_upward = true,
        })

        labeler.set_label_extmarks(
            buf,
            search_ns,
            targets,
            { cursor = search_ctx.cursor, locations = "finish", use_upward = true }
        )

        merge_res(targets, is)
        local dim_hl_info = checked_get_dim_rows_from_res(targets, dim)
        set_search_extmarks(buf, targets, is, search_ctx.dir)
        local highlighting = require("farsight._highlighting")
        highlighting.checked_set_dim_extmarks(buf, dim_ns, hl_dim, dim_hl_info, opts.dim)
    end

    if is and is_ctx then
        if r_targets[2] > 0 then
            -- Saves time setting extmarks
            merge_res(r_targets, is)
            -- Because these are not valid destinations, always assign false and do not dim
            set_search_extmarks(buf, r_targets, false, is_ctx.dir)
        end
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
---@param dir -1|1
---@param cursor [integer, integer, integer, integer, integer]
---@param start_row integer
---@param start_col integer
---@param stop_row integer
---@return farsight.common.SearchCtx
local function get_search_opts(win, dir, cursor, start_row, start_col, stop_row)
    return {
        alloc_size = 64,
        allow_folds = 2,
        cursor = cursor,
        dir = dir,
        handle_count = true,
        start_row = start_row,
        start_col = start_col,
        stop_row = stop_row,
        timeout = 500,
        upward = dir == -1 and true or false,
        wins = { win },
    }
end

---@param win integer
---@param buf integer
---@param prompt string
---@param dir -1|1
---@param opts farsight.search.SearchOpts
local function create_search_listener(win, buf, prompt, dir, opts)
    local cursor = vim.call("getcurpos") ---@type [integer, integer, integer, integer, integer]
    local get_pos_and_valid = require("farsight._common").get_pos_and_valid_from_dir

    local start_row, start_col, stop_row, valid = get_pos_and_valid(win, buf, dir, cursor)
    local search_opts = get_search_opts(win, dir, cursor, start_row, start_col, stop_row)

    local is_opts
    local is = api.nvim_get_option_value("is", { scope = "global" }) ---@type boolean
    if is then
        local is_dir = dir * -1
        local is_start_row, is_start_col, is_stop_row, is_valid =
            get_pos_and_valid(win, buf, is_dir, cursor)
        is_opts = get_search_opts(win, is_dir, cursor, is_start_row, is_start_col, is_stop_row)
        if is_valid == false then
            valid = false
        end
    end

    api.nvim_create_autocmd("CmdlineChanged", {
        group = search_group,
        desc = "Highlight search terms",
        callback = function()
            display_search_highlights(win, buf, prompt, search_opts, is, is_opts, valid, opts)
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
local function resolve_search_params(cur_buf, dir, opts)
    vim.validate("opts", opts, "table")
    vim.validate("dir", dir, function()
        return dir == -1 or dir == 1
    end)

    local ut = require("farsight.util")
    opts.debug_msgs = ut._use_gb_if_nil(opts.debug_msgs, "farsight_search_debug_msgs", cur_buf)
    opts.debug_msgs = ut._resolve_bool_opt(opts.debug_msgs, false)

    opts.dim = ut._use_gb_if_nil(opts.dim, "farsight_search_dim", cur_buf)
    opts.dim = ut._resolve_bool_opt(opts.dim, false)

    opts.keepjumps = ut._use_gb_if_nil(opts.keepjumps, "farsight_search_keepjumps", cur_buf)
    opts.keepjumps = ut._resolve_bool_opt(opts.keepjumps, false)

    opts.open_folds = ut._use_gb_if_nil(opts.open_folds, "farsight_search_open_folds", cur_buf)
    if opts.open_folds == nil then
        local fdo = api.nvim_get_option_value("fdo", { scope = "global" })
        local search, _, _ = string.find(fdo, "search", 1, true)
        local all, _, _ = string.find(fdo, "all", 1, true)
        if search or all then
            opts.open_folds = true
        else
            opts.open_folds = false
        end
    end

    opts.timeout = ut._use_gb_if_nil(opts.timeout, "farsight_search_timeout", cur_buf)
    if opts.timeout == nil then
        opts.timeout = TIMEOUT
    else
        vim.validate("opts.timeout", opts.timeout, ut._is_int)
    end
end

local M = {}

---@class farsight.search.SearchOpts
---@field debug_msgs? boolean
---Dim lines with targeted characters (Default: `false`)
---@field dim? boolean
---(Default: respect `foldopen`)
---@field keepjumps? boolean
---@field open_folds? boolean
---@field timeout? integer

---This function returns a typed search command string meant to be used in an
---expr mapping. On error, an empty string is returned.
---Note that keepjumps and on_jump only apply to label jumps, not the wrapped search call.
---@param dir -1|1
---@param opts? farsight.search.SearchOpts
---@return string
function M.search(dir, opts)
    opts = opts and vim.deepcopy(opts) or {}
    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)
    resolve_search_params(cur_buf, dir, opts)

    if require("farsight._common").get_is_repeating() == 1 then
        if vim.call("getreg", "/") ~= "" then
            return (vim.v.searchforward == 1 and "/" or "?") .. "\r"
        else
            return ""
        end
    end

    local prompt = dir == 1 and "/" or "?"
    if vim.call("reg_executing") == "" then
        checked_ns_set(cur_win, opts.dim)
        create_search_listener(cur_win, cur_buf, prompt, dir, opts)
    end

    local ok, pattern_raw = pcall(fn.input, prompt)
    del_search_listener()
    if not ok then
        checked_clear_namespaces(cur_buf, opts.dim)
        if pattern_raw == "Keyboard interrupt" then
            api.nvim_echo({ { "" } }, false, {}) -- LOW: Is there a less blunt way to handle this?
        else
            api.nvim_echo({ { pattern_raw, "ErrorMsg" } }, true, {})
        end

        return ""
    end

    local pattern, _ = parse_search_offset(prompt, pattern_raw)
    if pattern == "" and vim.call("getreg", "/") == "" then
        checked_clear_namespaces(cur_buf, opts.dim)
        return ""
    end

    if opts.dim then
        api.nvim_buf_clear_namespace(cur_buf, dim_ns, 0, -1)
    end

    vim.schedule(function()
        -- Delay execution to avoid flicker.
        api.nvim_buf_clear_namespace(cur_buf, search_ns, 0, -1)
    end)

    local expr = { prompt, pattern_raw, "\r" }
    if opts.open_folds then
        expr[#expr + 1] = "zv"
    end

    -- Return an expr to support dot repeat and operator pending mode
    return table.concat(expr, "")
end

function M.get_ns()
    return search_ns
end

return M

-- TODO: Delete this module once the live jump is actually working. Perhaps save the search merge
-- logic for future reference.

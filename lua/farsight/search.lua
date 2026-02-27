local api = vim.api
local fn = vim.fn

---@class farsight.search.DimHlInfo
---@field [1] integer Length
---@field [2] integer[] Start rows
---@field [3] integer[] Fin rows

local TIMEOUT = 500

local HL_DIM_STR = "FarsightSearchDim"
api.nvim_set_hl(0, HL_DIM_STR, { default = true, link = "Comment" })
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
local function handle_res_err(win, msg, hl, opts)
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

---@param win integer
---@param buf integer
---@param prompt string
---@param search_opts farsight.common.SearchOpts
---@param is boolean
---@param is_opts farsight.common.SearchOpts|nil
---@param valid boolean
---@param opts farsight.search.SearchOpts
local function display_search_highlights(win, buf, prompt, search_opts, is, is_opts, valid, opts)
    if vim.call("getcmdprompt") ~= prompt then
        return
    end

    local dim = opts.dim ---@type boolean
    checked_clear_namespaces(buf, dim)
    local cmdline_raw = vim.call("getcmdline") ---@type string
    if cmdline_raw == "" then
        api.nvim__redraw({ valid = false, win = win })
        return
    end

    local cmdline, _ = parse_search_offset(prompt, cmdline_raw)
    local common_search = require("farsight._common").search
    local ok, win_res, cache = common_search(cmdline, search_opts)

    local r_ok, r_win_res, r_cache
    if is and is_opts then
        r_ok, r_win_res, r_cache = common_search(cmdline, is_opts)

        if (not r_ok) or type(r_win_res) == "string" then
            handle_res_err(win, r_win_res, r_cache, opts)
            return
        end
    end

    if (not ok) or type(win_res) == "string" then
        handle_res_err(win, win_res, cache, opts)
        return
    end

    local res = win_res[win]
    if res[2] > 0 then
        merge_res(res, is)
        local dim_hl_info = checked_get_dim_rows_from_res(res, dim)
        set_search_extmarks(buf, res, is, search_opts.dir)
        local highlighting = require("farsight._highlighting")
        highlighting.checked_set_dim_extmarks(buf, dim_ns, hl_dim, dim_hl_info, opts.dim)
    end

    if is and is_opts then
        local r_res = r_win_res[win]
        if r_res[2] > 0 then
            -- Saves time setting extmarks
            merge_res(r_res, is)
            -- Because these are not valid destinations, always assign false and do not dim
            set_search_extmarks(buf, r_res, false, is_opts.dir)
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
---@return farsight.common.SearchOpts
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

-- TODO: Add an opt for display of "Search" labels.
-- TODO: Add a "prepend" opt that adds some text before your search. Example use case: If you want
-- to make a map that only searches inside the current visual area, you could add \%V
-- TODO: Related to the above, if you wanted to do that kind of map using the defaults, you could
-- just map "/\%V". I'm not totally sure you could do that here unless you used the "remap"
-- option (test if that even works, maybe document if so). And I would not map the plugs with
-- remap. You could conctenate your prepend with the function call. Awkward though.
-- TODO: Outline highlighting. Needs to work with the csearch case

-- TODO_DOC: By default, Farsight Search will live highlight matches in the direction the user is
-- searching using |hl-Search|. If |incsearch| is true, all visible matches will be highlighted,
-- with |hl-IncSearch| used for the first match. If jump labels are enabled (true by default), they
-- will only be added in the current window in the direction the user is searching. For
-- multi-directional/multi-window navigation, use jump.
-- TODO_DOC: IncSearch emulation is incomplete. Setting IncSearch to true will produce
-- IncSearch style highlighting. However, the cursor will not automatically advance and
-- <C-t>/<C-g> commands will not work.
-- TODO_DOC: Make some sort of useful documentation out of my error with running nohlsearch
-- on cmdline enter
-- TODO_DOC: The search module, really, is just a wrapper around the built-in /? cmds. If you
-- press enter to search, that is still handled with the built-in. This means cpo-c is respected
-- and hlsearch is still used for results.
-- TODO_DOC: If a macro or dot repeat are performed, the |quote/| last search register is used,
-- emulating default behavior.
-- TODO_DOC: Because this module uses input(), if you have an autocmd that schedules nohlsearch
-- after CmdlineEnter or CmdlineLeave, it will disable hlsearch after you have pressed enter.
--
-- LABELS
--
-- TODO: Labeling and dimming need to be abstracted out, as every module uses it.
-- - Challenge: Csearch
-- - Pass the labels as a list
-- - Fair labeling or preferential labeling (based on upward/res position)
-- - For live jumps, do you handle trimming the labels generally or specifically?
-- TODO: Results with overlapping ends can happen and need to be filtered. Prefer the first
-- one probably.
-- TODO: Labels should not accept if the cursor is not in the last position. Maybe don't even
-- show labels, or show them with a different highlight. Prevents issue with going back and
-- TODO: The default highlights here have to work with CurSearch and IncSearch. Being that this is
-- the lowest degrees of freedom module, it is the anchor point for the others.
-- modifying the search
-- TODO: Label jumps should have an on_jump option. The default should be a reasonable application
-- of fdo
-- Should saving searchforward/histadd/searchreg for labels be an option or something handled in
-- on_jump?

-- MID: Verify that builtin search timeout is half a second.
-- MID: When does input() return vim.NIL?
-- MID: Fold handling could be further optimized:
-- - The first extmark in each fold block is currently allowed to be set. This is to avoid
-- introducing additional logic around fixing hl_info for count and incsearch. But this still
-- forces Neovim to do bookkeeping around the extmark. I think this is fixed, roughly, by deleting
-- additional entries based on where the cursor will end up.
-- - (low priority) It might be more efficient to pre-compute the fold statuses of each row and
-- look them up in a table, rather than doing an if check on each entry. But this would be
-- predicated on having a list of rows to build the fold lookup from, rather than having to
-- iterate through every entry (otherwise, this is pointless). You could use dim_rows for this,
-- but that list is built after the hl_info entries are merged (and fold visibility needs to be
-- checked per pre-merge entry).
-- - An alternative to all this might be to just check folds during search, which is how do_search
-- handles it. This would solve the first problem, and make the second one irrelevant. The problem
-- is how to make this work with Puc Lua's double search, since fold handling is based only on the
-- start index (from what I can tell, this is as per default behavior). You would need to save a
-- list of omitted searches and hope the Puc Lua ending syncs up with that. Storing a list would
-- also be a new heap allocation.
-- MID: Display a highlight on the cursor position. Not required for parity with the built-in.
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
-- default behavior. If this is done, do this before getting into <C-t>/<C-g>, as the only
-- positions you need to be aware of are the current cursor position and the first match. Note
-- that this would require off-screen searching and supporting wrapscan.
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
-- LOW: Briefly looking at the code for clearing namespaces, it doesn't look like that triggers a
-- redraw, so I guess having multiple of them here is okay.
-- LOW: A potential optimization would be to look for contiguous search results and merging them
-- together. Since the end_cols are end-exclusive indexed, this is not infeasible. You would make
-- a loop that iterates through and merges in the next index if possible, then niling the
-- remainder. This *could* help with redraws. Low priority because it's complexity surface area
-- and extmark rendering is not the biggest bottleneck at the moment.
-- LOW: It would be better if hl_info and rev_hl_info were one big array. Splitting them in two
-- defeats the purpose of using a struct of arrays to begin with.
-- LOW: When getting search positions, it might be faster to run getpos() rather than line() and
-- col(). My concern is that getpos() allocates a table. This would need to be profiled.
-- LOW: Support keepjumps for search.
--
-- NON: Multi-window searching. Creates weird questions with wrap scan. Creates a problem where
-- even if you replicate the proper window ordering, it's not necessarily intuitive to which
-- window you will jump to.
-- NON: Multi-directional searching. Creates weird questions with how the v:vars are updated.
-- Jump handles this.
-- NON: Grafting this on top of the default search. This would require listeners/autocmds to
-- always be running, which means persistent state + the plugin insisting on itself. Harder to
-- turn off if unwanted. It also means that I don't have full-stepwise control over the relevant
-- events.

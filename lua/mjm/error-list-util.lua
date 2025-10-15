--- @class QfRancherUtils
local M = {}

-----------------
--- CMD UTILS ---
-----------------

--- @param fargs string[]
--- @return string|nil
function M._find_cmd_pattern(fargs)
    require("mjm.error-list-types")._validate_list(fargs, { type = "string" })

    for _, arg in ipairs(fargs) do
        if vim.startswith(arg, "/") then
            return string.sub(arg, 2) or ""
        end
    end

    return nil
end

--- @param fargs string[]
--- @param valid_args string[]
--- @param default string
function M._check_cmd_arg(fargs, valid_args, default)
    local ey = require("mjm.error-list-types") --- @type QfRancherTypes
    ey._validate_list(fargs, { type = "string" })
    ey._validate_list(valid_args, { type = "string" })
    vim.validate("default", default, "string")

    for _, arg in ipairs(fargs) do
        if vim.tbl_contains(valid_args, arg) then
            return arg
        end
    end

    return default
end

-------------------
--- INPUT UTILS ---
-------------------

--- @param input QfRancherInputType
--- @return string
--- NOTE: This function assumes that an API input of "vimsmart" has already been resolved
function M._get_display_input_type(input)
    if input == "regex" then
        return "Regex"
    elseif input == "sensitive" then
        return "Case Sensitive"
    elseif input == "smartcase" then
        return "Smartcase"
    else
        return "Case Insensitive"
    end
end

--- @param input QfRancherInputType
--- @return QfRancherInputType
function M._resolve_input_type(input)
    require("mjm.error-list-types")._validate_input_type(input)

    if input ~= "vimsmart" then
        return input
    end

    local smartcase = require("mjm.error-list-util")._get_g_var("qf_rancher_use_smartcase")
    if smartcase == true then
        return "smartcase"
    elseif smartcase == false then
        return "insensitive"
    end

    if vim.api.nvim_get_option_value("smartcase", { scope = "global" }) then
        return "smartcase"
    else
        return "insensitive"
    end
end

--- @param mode string
--- @return string|nil
local function get_visual_pattern(mode)
    vim.validate("mode", mode, "string")
    vim.validate("mode", mode, function()
        return mode == "v" or mode == "V" or mode == "\22"
    end)

    local start_pos = vim.fn.getpos(".") --- @type Range4
    local end_pos = vim.fn.getpos("v") --- @type Range4
    local region = vim.fn.getregion(start_pos, end_pos, { type = mode }) --- @type string[]
    if #region < 1 then
        return nil
    end

    if #region == 1 then
        local trimmed = region[1]:gsub("^%s*(.-)%s*$", "%1") --- @type string
        if trimmed == "" then
            vim.api.nvim_echo({ { "get_visual_pattern: Empty selection", "" } }, false, {})
            return nil
        end

        return trimmed
    end

    for _, line in ipairs(region) do
        if line ~= "" then
            vim.api.nvim_cmd({ cmd = "normal", args = { "\27" }, bang = true }, {})
            return table.concat(region, "\n")
        end
    end

    vim.api.nvim_echo({ { "get_visual_pattern: Empty selection", "" } }, false, {})
    return nil
end

--- @param prompt string
--- @return string|nil
local function get_input(prompt)
    vim.validate("prompt", prompt, "string")

    --- @type boolean, string
    local ok, pattern = pcall(vim.fn.input, { prompt = prompt, cancelreturn = "" })
    if ok then
        return pattern
    end

    if pattern == "Keyboard interrupt" then
        return nil
    end

    local chunk = { (pattern or "Unknown error getting input"), "ErrorMsg" } --- @type string[]
    vim.api.nvim_echo({ chunk }, true, { err = true })
    return nil
end

--- @param prompt string
--- @param input_pattern string|nil
--- @param input_type QfRancherInputType
--- @return string|nil
function M._resolve_pattern(prompt, input_pattern, input_type)
    vim.validate("prompt", prompt, "string")
    vim.validate("input_pattern", input_pattern, "string", true)
    require("mjm.error-list-types")._validate_input_type(input_type)

    if input_pattern then
        return input_pattern
    end

    local mode = vim.fn.mode() --- @type string
    local is_visual = mode == "v" or mode == "V" or mode == "\22" --- @type boolean
    if is_visual then
        return get_visual_pattern(mode)
    end

    local pattern = get_input(prompt) --- @type string|nil
    return (pattern and input_type == "insensitive") and string.lower(pattern) or pattern
end

------------
--- MISC ---
------------

--- @param win integer
--- @param todo function
--- @return any
function M._locwin_check(win, todo)
    require("mjm.error-list-types")._validate_win(win, false)

    local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    return todo()
end

--- @param count integer
--- @return integer
function M._count_to_count1(count)
    require("mjm.error-list-types")._validate_uint(count)
    return math.max(count, 1)
end

--- @param x integer
--- @param y integer
--- @param min integer
--- @param max integer
--- @return integer
function M._wrapping_add(x, y, min, max)
    local period = max - min + 1 --- @type integer
    return ((x - min + y) % period) + min
end

--- @param x integer
--- @param y integer
--- @param min integer
--- @param max integer
--- @return integer
function M._wrapping_sub(x, y, min, max)
    local period = max - min + 1 --- @type integer
    return ((x - y - min) % period) + min
end

--- @param win integer
--- @return boolean
function M._win_can_have_loclist(win)
    require("mjm.error-list-types")._validate_win(win, true)
    if not win then
        return false
    end

    local wintype = vim.fn.win_gettype(win)
    if wintype == "" or wintype == "loclist" then
        return true
    end

    --- @type string
    local text = "Window " .. win .. " with type " .. wintype .. " cannot contain a location list"
    vim.api.nvim_echo({ { text, "ErrorMsg" } }, true, { err = true })
    return false
end

--- @param msg string
--- @param print_msgs boolean
--- @param is_err boolean
--- @return nil
function M._checked_echo(msg, print_msgs, is_err)
    if not print_msgs then
        return
    end

    if is_err then
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
    else
        vim.api.nvim_echo({ { msg, "" } }, false, {})
    end
end

-- TODO: Go through usages of this and update to handle new params/separate buf logic
-- TODO: For this and other similar situations, since nvim_win_close errors on bad data anyway,
--  do we need a separate validation?
-- TODO: Returns buffer to handle. Conceptually, makes sense inasmuch as, if we close a win return
--  the buf, if we don't close a win, don't return a buf. But if we're in the last win, we also
--  want to return the buf so it can be closed. Or is it better to say/think - return the buf
--  if the win is valid

--- @param win integer
--- @param force boolean
--- @return integer
function M._pwin_close(win, force)
    require("mjm.error-list-types")._validate_uint(win)
    vim.validate("force", force, "boolean")

    if not vim.api.nvim_win_is_valid(win) then
        return -1
    end

    local tabpages = vim.api.nvim_list_tabpages() --- @type integer[]
    local win_tabpage = vim.api.nvim_win_get_tabpage(win) --- @type integer
    local win_tabpage_wins = vim.api.nvim_tabpage_list_wins(win_tabpage) --- @type integer[]
    if #tabpages == 1 and #win_tabpage_wins == 1 then
        return -1
    end

    local buf = vim.api.nvim_win_get_buf(win) --- @type integer
    local ok, _ = pcall(vim.api.nvim_win_close, win, force) --- @type boolean, nil
    if not ok then
        return -1
    else
        return buf
    end
end

--- @param win integer
--- @param cur_pos {[1]: integer, [2]: integer}
--- @return nil
function M._protected_set_cursor(win, cur_pos)
    local ey = require("mjm.error-list-types")
    ey._validate_uint(win)

    if not vim.api.nvim_win_is_valid(win) then
        return
    end

    ey._validate_cur_pos(cur_pos)

    local adj_cur_pos = vim.deepcopy(cur_pos, true) --- @type {[1]: integer, [2]: integer}
    local win_buf = vim.api.nvim_win_get_buf(win) --- @type integer

    local line_count = vim.api.nvim_buf_line_count(win_buf) --- @type integer
    adj_cur_pos[1] = math.min(adj_cur_pos[1], line_count)

    local row = adj_cur_pos[1] --- @type integer
    local set_line = vim.api.nvim_buf_get_lines(win_buf, row - 1, row, false)[1] --- @type string
    adj_cur_pos[2] = math.min(adj_cur_pos[2], #set_line - 1)
    adj_cur_pos[2] = math.max(adj_cur_pos[2], 0)

    vim.api.nvim_win_set_cursor(win, adj_cur_pos)
end

-- MID: https://github.com/neovim/neovim/pull/33402
-- Redo this once this issue is resolved

--- @param buf integer
--- @param force boolean
--- @param wipeout boolean
--- @return nil
function M._pbuf_rm(buf, force, wipeout)
    require("mjm.error-list-types")._validate_uint(buf)
    vim.validate("force", force, "boolean")
    vim.validate("wipeout", wipeout, "boolean")

    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end

    if not wipeout then
        vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
    end

    local delete_opts = wipeout and { force = force } or { force = force, unload = true }
    pcall(vim.api.nvim_buf_delete, delete_opts)
end

--- @param win integer
--- @param force boolean
--- @param wipeout boolean
--- @return nil
function M._pclose_and_rm(win, force, wipeout)
    -- The individual functions handle validation
    local buf = M._pwin_close(win, force)
    if buf > 0 then
        M._pbuf_rm(buf, force, wipeout)
    end
end

-- PR: Why can't this be a part of Nvim core?
-- MID: This could be a binary search instead
-- TODO: Test

--- @param vcol integer
--- @param line string
--- @return boolean, integer, integer
function M._vcol_to_byte_bounds(vcol, line)
    require("mjm.error-list-types")._validate_uint(vcol)
    vim.validate("line", line, "string")

    if vcol == 0 or #line <= 1 then
        return true, 0, 0
    end

    local max_vcol = vim.fn.strdisplaywidth(line) --- @type integer
    if vcol > max_vcol then
        return false, 0, 0
    end

    local charlen = vim.fn.strcharlen(line) --- @type integer
    for char_idx = 0, charlen - 1 do
        local start_byte = vim.fn.byteidx(line, char_idx) --- @type integer
        if start_byte == -1 then
            return false, 0, 0
        end

        local char = vim.fn.strcharpart(line, char_idx, 1, true) --- @type string
        local fin_byte = start_byte + #char - 1 --- @type integer

        local test_str = line:sub(1, fin_byte + 1) --- @type string
        local test_vcol = vim.fn.strdisplaywidth(test_str) --- @type integer
        if test_vcol >= vcol then
            return true, start_byte, fin_byte
        end
    end

    return false, 0, 0
end

--- @param vcol integer
--- @param line string
--- @return integer
function M._vcol_to_end_col_(vcol, line)
    require("mjm.error-list-types")._validate_uint(vcol) --- @type QfRancherTypes
    vim.validate("line", line, "string")

    local ok, _, fin_byte = M._vcol_to_byte_bounds(vcol, line) --- @type boolean, integer
    if ok then
        return math.min(fin_byte + 1, #line)
    else
        return #line
    end
end

-- TODO: Use this for all g_var calls
-- TODO: I am not sure where to define whether or not certain vars allow nils. On one hand,
-- centralization makes sense because it makes documentation easier. On the other, it makes
-- type annotations more difficult as well. Right now winborder is the use case

--- @param g_var string
--- @param allow_nil? boolean
--- @return any
function M._get_g_var(g_var, allow_nil)
    vim.validate("g_var", g_var, "string")
    vim.validate("allow_nil", allow_nil, "boolean", true)

    local g_var_data = _QFR_G_VAR_MAP[g_var] --- @type {[1]:string[], [2]:any}

    local ey = require("mjm.error-list-types") --- @type QfRancherTypes
    ey._validate_list(g_var_data, { len = 2 })
    ey._validate_list(g_var_data[1], { type = "string" })
    vim.validate("g_var_default", g_var_data[2], function()
        return type(g_var_data[2]) ~= "nil"
    end, "G var defaults canot be nil")

    local cur_g_val = vim.g[g_var] --- @type any
    if allow_nil and type(cur_g_val) == "nil" then
        return nil
    end

    if vim.tbl_contains(g_var_data[1], type(cur_g_val)) then
        return cur_g_val
    else
        return g_var_data[2]
    end
end

----------------------
--- WINDOW FINDING ---
----------------------

--- @param opts QfRancherTabpageOpts
--- @return integer[]
function M._resolve_tabpages(opts)
    require("mjm.error-list-types")._validate_tabpage_opts(opts)

    if opts.all_tabpages then
        return vim.api.nvim_list_tabpages()
    elseif opts.tabpages then
        return opts.tabpages
    elseif opts.tabpage then
        return { opts.tabpage }
    else
        return { vim.api.nvim_get_current_tabpage() }
    end
end

-- NOTE: Used in hot loops. No validations here

--- @param qf_id integer
--- @param t_win integer
--- @return boolean
local function check_win(qf_id, t_win)
    local tw_qf_id = vim.fn.getloclist(t_win, { id = 0 }).id --- @type integer
    if tw_qf_id ~= qf_id then
        return false
    end

    local t_win_buf = vim.api.nvim_win_get_buf(t_win) --- @type integer
    --- @type string
    local t_win_buftype = vim.api.nvim_get_option_value("buftype", { buf = t_win_buf })
    if t_win_buftype == "quickfix" then
        return true
    end

    return false
end

--- If searching for wins by qf_id, passing a zero id is allowed so that orphans can be checked

--- @param qf_id integer
--- @param opts QfRancherTabpageOpts
--- @return integer[]
local function get_loclist_wins(qf_id, opts)
    local ey = require("mjm.error-list-types")
    ey._validate_uint(qf_id)
    ey._validate_tabpage_opts(opts)

    local wins = {} --- @type integer[]
    local tabpages = M._resolve_tabpages(opts) --- @type integer[]
    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
        for _, t_win in ipairs(tabpage_wins) do
            if check_win(qf_id, t_win) then
                table.insert(wins, t_win)
            end
        end
    end

    return wins
end

--- @param qf_id integer
--- @param opts QfRancherTabpageOpts
--- @return integer|nil
local function get_loclist_win(qf_id, opts)
    local ey = require("mjm.error-list-types") --- @type QfRancherTypes
    ey._validate_uint(qf_id)
    ey._validate_tabpage_opts(opts)

    local tabpages = M._resolve_tabpages(opts) --- @type integer[]
    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
        for _, t_win in ipairs(tabpage_wins) do
            if check_win(qf_id, t_win) then
                return t_win
            end
        end
    end

    return nil
end

--- @param win integer
--- @param opts QfRancherTabpageOpts
--- @return integer|nil
function M._get_loclist_win_by_win(win, opts)
    require("mjm.error-list-types")._validate_win(win, false)

    local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
    if qf_id == 0 then
        return nil
    else
        return get_loclist_win(qf_id, opts)
    end
end

--- @param qf_id integer
--- @param opts QfRancherTabpageOpts
--- @return integer|nil
function M._get_ll_win_by_qf_id(qf_id, opts)
    return get_loclist_win(qf_id, opts)
end

--- @param win integer
--- @param opts QfRancherTabpageOpts
--- @return integer[]
function M._get_loclist_wins_by_win(win, opts)
    require("mjm.error-list-types")._validate_win(win, false)

    local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
    if qf_id == 0 then
        return {}
    end

    return get_loclist_wins(qf_id, opts)
end

--- @param qf_id integer
--- @param opts QfRancherTabpageOpts
--- @return integer[]
function M._get_loclist_wins_by_qf_id(qf_id, opts)
    return get_loclist_wins(qf_id, opts)
end

--- @param opts QfRancherTabpageOpts
--- @return integer[]
function M._get_all_loclist_wins(opts)
    local ll_wins = {} --- @type integer[]
    local tabpages = M._resolve_tabpages(opts) --- @type integer[]

    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
        for _, win in ipairs(tabpage_wins) do
            local wintype = vim.fn.win_gettype(win)
            if wintype == "loclist" then
                table.insert(ll_wins, win)
            end
        end
    end

    return ll_wins
end

--- @param opts QfRancherTabpageOpts
--- @return integer[]
function M._get_qf_wins(opts)
    local wins = {} --- @type integer[]
    local tabpages = M._resolve_tabpages(opts) --- @type integer[]

    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
        for _, t_win in ipairs(tabpage_wins) do
            local wintype = vim.fn.win_gettype(t_win)
            if wintype == "quickfix" then
                table.insert(wins, t_win)
            end
        end
    end

    return wins
end

--- @param opts QfRancherTabpageOpts
--- @return integer|nil
function M._get_qf_win(opts)
    local tabpages = M._resolve_tabpages(opts) --- @type integer[]

    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
        for _, t_win in ipairs(tabpage_wins) do
            local wintype = vim.fn.win_gettype(t_win)
            if wintype == "quickfix" then
                return t_win
            end
        end
    end

    return nil
end

--- @param win integer|nil
--- @param opts QfRancherTabpageOpts
--- @return integer|nil
function M._get_list_win(win, opts)
    if win then
        return M._get_loclist_win_by_win(win, opts)
    else
        return M._get_qf_win(opts)
    end
end

-- --- @param win integer|nil
-- --- @param opts QfRancherTabpageOpts
-- --- @return integer[]
-- function M._get_list_wins(win, opts)
--     if win then
--         return M._get_loclist_wins_by_win(win, opts)
--     else
--         return M._get_qf_wins(opts)
--     end
-- end

return M

------------
--- TODO ---
------------

--- Tests
--- Docs

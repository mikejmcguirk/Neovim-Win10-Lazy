--- @class QfRancherUtils
local M = {}

--- TODO: Move these to types

--- @param count integer
--- return integer
function M._count_to_count1(count)
    require("mjm.error-list-types")._validate_count(count)
    return math.max(count, 1)
end

M._severity_map = {
    [vim.diagnostic.severity.ERROR] = "E",
    [vim.diagnostic.severity.WARN] = "W",
    [vim.diagnostic.severity.INFO] = "I",
    [vim.diagnostic.severity.HINT] = "H",
} ---@type table<integer, string>

M._severity_unmap = {
    E = vim.diagnostic.severity.ERROR,
    W = vim.diagnostic.severity.WARN,
    I = vim.diagnostic.severity.INFO,
    H = vim.diagnostic.severity.HINT,
} ---@type table<string, integer>

--- @param table string[]
--- @return nil
function M._is_valid_str_list(table)
    vim.validate("table", table, "table")
    for k, v in ipairs(table) do
        assert(type(k) == "number", "Key " .. vim.inspect(k) .. " is not a number")
        assert(type(v) == "string", "Item " .. vim.inspect(v) .. " is not a string")
    end
end

-----------------
--- CMD UTILS ---
-----------------

--- @param fargs string[]
--- @return string|nil
function M._find_cmd_pattern(fargs)
    if vim.g.qf_rancher_debug_assertions then
        M._is_valid_str_list(fargs)
    end

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
    if vim.g.qf_rancher_debug_assertions then
        M._is_valid_str_list(fargs)
        M._is_valid_str_list(valid_args)
        vim.validate("default", default, "string")
    end

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

    if vim.g.qf_rancher_use_smartcase == true then
        return "smartcase"
    elseif vim.g.qf_rancher_use_smartcase == false then
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

    local ok, pattern = pcall(vim.fn.input, { prompt = prompt, cancelreturn = "" })
    if ok then
        return pattern
    end

    if pattern == "Keyboard interrupt" then
        return nil
    end

    local chunk = { (pattern or "Unknown error getting input"), "ErrorMsg" }
    vim.api.nvim_echo({ chunk }, true, { err = true })
    return nil
end

--- @param prompt string
--- @param input_pattern string|nil
--- @param input_type QfRancherInputType
--- @return string|nil
function M._resolve_pattern(prompt, input_pattern, input_type)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("prompt", prompt, "string")
        vim.validate("input_pattern", input_pattern, { "nil", "string" })
        require("mjm.error-list-types")._validate_input_type(input_type)
    end

    if input_pattern then
        return input_pattern
    end

    local mode = vim.fn.mode() --- @type string
    local is_visual = mode == "v" or mode == "V" or mode == "\22" --- @type boolean
    if is_visual then
        return get_visual_pattern(mode)
    end

    local pattern = get_input(prompt) --- @type string|nil
    return pattern and input_type == "insensitive" and string.lower(pattern) or pattern
end

------------
--- MISC ---
------------

--- @param win integer
--- @param todo function
--- @return any
function M._locwin_check(win, todo)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, false)
    end

    local qf_id = vim.fn.getloclist(win, { id = 0 }).id
    if qf_id == 0 then
        vim.api.nvim_echo({ { "Current window has no location list", "" } }, false, {})
        return
    end

    return todo()
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
    if not win then
        return false
    end

    require("mjm.error-list-types")._validate_win(win, false)

    local wintype = vim.fn.win_gettype(win) --- @type string
    if wintype == "" or wintype == "loclist" then
        return true
    end

    --- @type string
    local text = "Window " .. win .. " with type " .. wintype .. " cannot contain a location list"
    vim.api.nvim_echo({ { text, "ErrorMsg" } }, true, { err = true })
    return false
end

--- @param win integer|nil
--- @return string|nil
function M._get_listtype(win)
    vim.validate("win", win, { "nil", "number" })
    if type(win) == "number" then
        assert(vim.api.nvim_win_is_valid(win))
    end

    win = win or vim.api.nvim_get_current_win()
    local wintype = vim.fn.win_gettype(win) --- @type string
    return (wintype == "quickfix" or wintype == "loclist") and wintype or nil
end

----------------------
--- WINDOW FINDING ---
----------------------

--- TODO: Apply these utils to any sort of window finding operation. So if we want to gether
--- lists to do some operation on, it should call this to get the list, then run the operation
--- If we find cases we can't handle, we need to expand or break out these functions as needed

local function resolve_tabpages(opts)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_tabpage_opts(opts)
    end

    if opts.all_tabpages then
        return vim.api.nvim_list_tabpages()
    elseif opts.some_tabpages then
        return opts.some_tabpages
    elseif opts.tabpage then
        return { opts.tabpage }
    else
        return { vim.api.nvim_get_current_tabpage() }
    end
end

local function check_win(qf_id, t_win)
    local tw_qf_id = vim.fn.getloclist(t_win, { id = 0 }).id --- @type integer
    if tw_qf_id ~= qf_id then
        return false
    end

    local t_win_buf = vim.api.nvim_win_get_buf(t_win) --- @type integer
    --- @type string
    local t_win_buftype = vim.api.nvim_get_option_value("buftype", { buf = t_win_buf })
    if t_win_buftype == "quickfix" then
        return t_win
    end
end

--- @param qf_id integer
--- @param opts {tabpage?: integer, some_tabpages?: integer[], all_tabpages?:boolean}
--- @return integer[]
local function get_loclist_wins(qf_id, opts)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("qf_id", qf_id, "number")
    end

    local wins = {}
    if qf_id == 0 then
        return wins
    end

    local tabpages = resolve_tabpages(opts) --- @type integer[]
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
--- @param opts {tabpage?: integer, some_tabpages?: integer[], all_tabpages?:boolean}
--- @return integer|nil
local function get_loclist_win(qf_id, opts)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("qf_id", qf_id, "number")
    end

    if qf_id == 0 then
        return nil
    end

    local tabpages = resolve_tabpages(opts) --- @type integer[]
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
--- @param opts {tabpage?: integer, some_tabpages?: integer[], all_tabpages?:boolean}
--- @return integer|nil
function M._get_loclist_win_by_win(win, opts)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, false)
    end

    local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
    return get_loclist_win(qf_id, opts)
end

--- TODO: A possible solution for finding orphans would be to move the qf_id check to the
--- get win_by_win function and allow any qf_id here to find zeroes. I think though there's more
--- recursion than that. So maybe you need a top level function that calls these functions
--- multiple times. But then the qf_id passthrough might still be necessary
--- If we do that, must document that the by_qf_id function does not check for zero

--- @param qf_id integer
--- @param opts QfRancherTabpageOpts
--- @return integer|nil
function M._get_loclist_win_by_qf_id(qf_id, opts)
    return get_loclist_win(qf_id, opts)
end

--- @param win integer
--- @param opts QfRancherTabpageOpts
--- @return integer[]
function M._get_loclist_wins_by_win(win, opts)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_win(win, false)
    end

    local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
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
function M._get_qf_wins(opts)
    local wins = {}
    local tabpages = resolve_tabpages(opts) --- @type integer[]

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
    local tabpages = resolve_tabpages(opts) --- @type integer[]

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

--- @param win integer|nil
--- @param opts QfRancherTabpageOpts
--- @return integer[]
function M._get_list_wins(win, opts)
    if win then
        return M._get_loclist_wins_by_win(win, opts)
    else
        return M._get_qf_wins(opts)
    end
end

-- TODO: Generalize out this function

--- @param opts?{tabpage?:integer, tabpage_wins?: integer[]}
--- @return integer[]
function M._find_orphan_loclists(opts)
    opts = opts or {}
    vim.validate("opts.tabpage", opts.tabpage, { "nil", "number" })
    vim.validate("opts.tabpage_wins", opts.tabpage_wins, { "nil", "table" })

    local tabpage = opts.tabpage or vim.api.nvim_get_current_tabpage() --- @type integer
    --- @type integer[]
    local tabpage_wins = opts.tabpage_wins or vim.api.nvim_tabpage_list_wins(tabpage)

    local orphans = {} --- @type integer[]
    for _, win in pairs(tabpage_wins) do
        if vim.fn.win_gettype(win) == "loclist" then
            local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
            if qf_id == 0 then
                table.insert(orphans, win)
            else
                local is_orphan = true --- @type boolean
                for _, inner_win in pairs(tabpage_wins) do
                    local iw_qf_id = vim.fn.getloclist(inner_win, { id = 0 }).id --- @type integer
                    if inner_win ~= win and iw_qf_id == qf_id then
                        is_orphan = false
                        break
                    end
                end

                if is_orphan then
                    table.insert(orphans, win)
                end
            end
        end
    end

    return orphans
end

return M

------------
--- TODO ---
------------

--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation
--- - Check that the qf and loclist versions are both properly built for purpose. Should be able
---     to use the loclist function for buf/win specific info

--- @class QfRancherUtils
local M = {}

-----------------
--- CMD UTILS ---
-----------------

--- @param fargs string[]
--- @return string|nil
function M._find_cmd_pattern(fargs)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_str_list(fargs)
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
        local ey = require("mjm.error-list-types") --- @type QfRancherTypes
        ey._validate_str_list(fargs)
        ey._validate_str_list(valid_args)
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
    return (pattern and input_type == "insensitive") and string.lower(pattern) or pattern
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

    local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
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

    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, false)
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

--- TODO: Only used in preview. Feels unnecessary. Or at least move there

--- @param win integer|nil
--- @return string|nil
function M._get_listtype(win)
    vim.validate("win", win, { "nil", "number" })
    if type(win) == "number" then
        assert(vim.api.nvim_win_is_valid(win))
    end

    win = win or vim.api.nvim_get_current_win() --- @type integer
    local wintype = vim.fn.win_gettype(win) --- @type string
    return (wintype == "quickfix" or wintype == "loclist") and wintype or nil
end

--- @param win integer
--- @return boolean
function M._win_is_list(win)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, false)
    end

    local buf = vim.api.nvim_win_get_buf(win) --- @type integer
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
    if buftype == "quickfix" then
        return true
    else
        return false
    end
end

----------------------
--- WINDOW FINDING ---
----------------------

--- @param opts QfRancherTabpageOpts
--- @return integer[]
function M._resolve_tabpages(opts)
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_tabpage_opts(opts)
    end

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
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_qf_id(qf_id)
        ey._validate_tabpage_opts(opts)
    end

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
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types") --- @type QfRancherTypes
        ey._validate_qf_id(qf_id)
        ey._validate_tabpage_opts(opts)
    end

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
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, false)
    end

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
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_win(win, false)
    end

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

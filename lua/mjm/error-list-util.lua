--- @class QfRancherUtils
local M = {}

--- @param count integer
--- return integer
function M._count_to_count1(count)
    require("mjm.error-list-types")._validate_count(count)
    return math.max(count, 1)
end

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

--- TODO: There are cases where you need to gather all loclist wins to handle edge cases. This
--- feels like a simple way to handle normal cases. Unsure if I want to conflate cleanup logic
--- in here

--- @param win integer
--- @param opts {tabpage?: integer, some_tabpages?: integer[], all_tabpages?:boolean}
--- @return integer|nil
function M._get_loclist_win_by_win(win, opts)
    opts = opts or {}
    if vim.g.qf_rancher_debug_assertions then
        require("mjm.error-list-types")._validate_win(win, false)
        vim.validate("opts", opts, "table")
        vim.validate("opts.tabpage", opts.tabpage, { "nil", "number" })
        vim.validate("opts.some_tabpages", opts.some_tabpages, { "nil", "table" })
        vim.validate("opts.all_tabpages", opts.all_tabpages, { "boolean", "nil" })
    end

    local qf_id = vim.fn.getloclist(win, { id = 0 }) --- @type integer
    if qf_id == 0 then
        return nil
    end

    local tabpages = (function()
        if opts.all_tabpages then
            return vim.api.nvim_list_tabpages()
        elseif opts.some_tabpages then
            return opts.some_tabpages
        elseif opts.tabpage then
            return { opts.tabpage }
        else
            return { vim.api.nvim_win_get_tabpage(win) }
        end
    end)() --- @type integer[]

    local function check_win(t_win)
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

    for _, tabpage in ipairs(tabpages) do
        local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage) --- @type integer[]
        for _, t_win in ipairs(tabpage_wins) do
            if check_win(t_win) then
                return t_win
            end
        end
    end

    return nil
end

--- TODO: There's a specific problem that needs to be solved where the caller already has the
--- tabpage wins, so we don't want to get them again, but that creates a weird side-case in
--- a find function scoped by tabpages. As shown above, the logic for which tabpages to look at
--- scopes cleanly

--- @param qf_id integer
--- @param opts {win?: integer, tabpage?: integer, tabpage_wins?: integer[]}
function M._find_loclist_win_by_qf_id(qf_id, opts)
    opts = opts or {}
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("qf_id", qf_id, "number")
        vim.validate("opts", opts, { "nil", "table" })

        if type(opts) == "table" then
            vim.validate("opts.win", opts.win, { "nil", "number" })
            vim.validate("opts.tabpage", opts.tabpage, { "nil", "number" })
            vim.validate("opts.tabpage_wins", opts.tabpage_wins, { "nil", "table" })
        end
    end

    local win = opts.win or vim.api.nvim_get_current_win()
    local tabpage = opts.tabpage or vim.api.nvim_win_get_tabpage(win)
    local tabpage_wins = opts.tabpage_wins or vim.api.nvim_tabpage_list_wins(tabpage)

    for _, t_win in ipairs(tabpage_wins) do
        if vim.fn.win_gettype(t_win) == "loclist" then
            local tw_qf_id = vim.fn.getloclist(t_win, { id = 0 }).id
            if tw_qf_id == qf_id then
                return win
            end
        end
    end

    return nil
end

--- @param opts {tabpage?: integer, some_tabpages?: integer[], all_tabpages?:boolean}
--- @return integer|nil
function M._get_qf_win(opts)
    opts = opts or {}
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("opts", opts, "table")
        vim.validate("opts.tabpage", opts.tabpage, { "nil", "number" })
        vim.validate("opts.some_tabpages", opts.some_tabpages, { "nil", "table" })
        vim.validate("opts.all_tabpages", opts.all_tabpages, { "boolean", "nil" })
    end

    local tabpages = (function()
        if opts.all_tabpages then
            return vim.api.nvim_list_tabpages()
        elseif opts.some_tabpages then
            return opts.some_tabpages
        elseif opts.tabpage then
            return { opts.tabpage }
        else
            return { vim.api.nvim_get_current_tabpage() }
        end
    end)() --- @type integer[]

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
--- @param opts {tabpage?: integer, some_tabpages?: integer[], all_tabpages?:boolean}
--- @return integer|nil
function M._get_list_win(win, opts)
    if win then
        return M._get_loclist_win_by_win(win, opts)
    else
        return M._get_qf_win(opts)
    end
end

--- TODO: Similar issue to the above. What scope are we looking at. Purely based on the code,
--- it's a specific tabpage based on the win, but it's very silly

--- @param opts?{tabpage?: integer, win?:integer, tabpage_wins?:integer[]}
--- @return integer|nil
function M._find_qf_win(opts)
    opts = opts or {}
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("opts.win", opts.win, { "nil", "number" })
        vim.validate("opts.tabpage", opts.tabpage, { "nil", "number" })
        vim.validate("opts.tabpage_wins", opts.tabpage, { "nil", "table" })
    end

    --- LOW: Does not feel like the most efficient way to do this. Could also yield weird results
    --- if more than one opt is specified
    local win = opts.win or vim.api.nvim_get_current_win()
    local tabpage = opts.tabpage or vim.api.nvim_win_get_tabpage(win)
    local tabpage_wins = opts.tabpage_wins or vim.api.nvim_tabpage_list_wins(tabpage)

    for _, t_win in ipairs(tabpage_wins) do
        if vim.fn.win_gettype(t_win) == "quickfix" then
            return t_win
        end
    end

    return nil
end

function M._find_qf_win_in_cur_tabpage()
    local tabpage = vim.api.nvim_get_current_tabpage()
    local tabpage_wins = vim.api.nvim_tabpage_list_wins(tabpage)
    for _, win in ipairs(tabpage_wins) do
        if vim.fn.win_gettype(win) == "quickfix" then
            return win
        end
    end

    return nil
end

--- LOW: For this and _has_any_loclist, you can pass a getlist function and make them the same
--- thing

--- @return boolean
function M._has_any_qflist()
    local max_nr = vim.fn.getqflist({ nr = "$" }).nr --- @type integer
    if max_nr == 0 then
        return false
    end

    for i = 1, max_nr do
        local size = vim.fn.getqflist({ nr = i, size = 0 }).size --- @type integer
        if size > 0 then
            return true
        end
    end

    return false
end

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

--- @param entry table
--- @return string
local function get_qf_key(entry)
    local fname = entry.filename or ""
    local lnum = tostring(entry.lnum or 0)
    local col = tostring(entry.col or 0)
    return fname .. ":" .. lnum .. ":" .. col
end

--- MAYBE: Move into tools file

--- @param a table
--- @param b table
--- @return table
function M._merge_qf_lists(a, b)
    local merged = {}
    local seen = {}

    local x = #a > #b and a or b
    local y = #a > #b and b or a

    for _, entry in ipairs(x) do
        local key = get_qf_key(entry)
        seen[key] = true
        table.insert(merged, entry)
    end

    for _, entry in ipairs(y) do
        local key = get_qf_key(entry)
        if not seen[key] then
            seen[key] = true
            table.insert(merged, entry)
        end
    end

    return merged
end

--- @param is_loclist boolean
--- @return fun(table):boolean
function M._get_openlist(is_loclist)
    local elo = require("mjm.error-list-open")

    if is_loclist then
        return function(opts)
            return elo._open_loclist(opts)
        end
    else
        return function(opts)
            return elo._open_qflist(opts)
        end
    end
end

--- @param table string[]
--- @return nil
--- TODO: There is a bespoke version of this out there somewhere
function M._is_valid_str_list(table)
    vim.validate("table", table, "table")
    for k, v in ipairs(table) do
        assert(type(k) == "number", "Key " .. vim.inspect(k) .. " is not a number")
        assert(type(v) == "string", "Item " .. vim.inspect(v) .. " is not a string")
    end
end

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

return M

--- TODO:
--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation
--- - Check that the qf and loclist versions are both properly built for purpose. Should be able
---     to use the loclist function for buf/win specific info

--------------
--- FUTURE ---
--------------

--- If this file gets to 1k lines, split it

--- @class QfRancherUtils
local M = {}

function M._count_to_count1(count)
    require("mjm.error-list-validation")._validate_count(count)
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

--- MID: Keeping this function split out in case we need a direct check without the output_opts
--- check. Leaving error printing here because it is used in every case

--- @param win integer
--- @return boolean
local function source_win_can_have_loclist(win)
    vim.validate("win", win, "number")
    vim.validate("win", win, function()
        return vim.api.nvim_win_is_valid(win)
    end)

    local wintype = vim.fn.win_gettype(win) --- @type string
    --- If you do getloclist or setloclist on either the source window or a window containing the
    --- loclist buf, they will both write to the loclist, so both types are acceptable here
    if wintype == "" or wintype == "loclist" then
        return true
    end

    --- @type string
    local text = "Window " .. win .. " with type " .. wintype .. " cannot contain a location list"
    local chunk = { text } --- @type string[]
    vim.api.nvim_echo({ chunk }, true, { err = true })
    return false
end

--- @param output_opts QfRancherOutputOpts
--- @return nil
function M._is_valid_loclist_output(output_opts)
    if not output_opts.use_loclist then
        return true
    end

    -- source_win_can_have_loclist will print the appropriate error
    return source_win_can_have_loclist(output_opts.loclist_source_win)
end

--- TODO: I'm wondering if for functions like this it's better to have a few smaller, more easily
--- parsable functions. The get loclist by qf_id below is basically the same length as this, but
--- infinitely more readable

--- @param win integer
--- @param qf_id? integer
--- @return integer|nil
function M._find_loclist_win(win, qf_id)
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("qf_id", qf_id, { "nil", "number" })
        vim.validate("win", win, "number")
        vim.validate("win", win, function()
            return vim.api.nvim_win_is_valid(win)
        end)

        vim.validate("win", win, function()
            return source_win_can_have_loclist(win)
        end)
    end

    qf_id = qf_id or vim.fn.getloclist(win, { id = 0 }) --- @type integer

    local win_tabpage = vim.api.nvim_win_get_tabpage(win) --- @type integer
    local win_tabpage_wins = vim.api.nvim_tabpage_list_wins(win_tabpage) --- @type integer[]
    for _, t_win in ipairs(win_tabpage_wins) do
        local tw_qf_id = vim.fn.getloclist(t_win, { id = 0 }).id --- @type integer
        if tw_qf_id == qf_id then
            local t_win_buf = vim.api.nvim_win_get_buf(t_win) --- @type integer
            --- @type string
            local t_win_buftype = vim.api.nvim_get_option_value("buftype", { buf = t_win_buf })
            if t_win_buftype == "quickfix" then
                return t_win
            end
        end
    end

    return nil
end

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

--- @param output_opts? QfRancherOutputOpts
--- @return integer|nil
function M._find_list_win(output_opts)
    output_opts = output_opts or {}
    if vim.g.qf_rancher_debug_assertions then
        M._validate_output_opts(output_opts)
    end

    if output_opts.use_loclist then
        --- @type integer
        local win = output_opts.loclist_source_win or vim.api.nvim_get_current_win()
        return M._find_loclist_win(win)
    else
        return M._find_qf_win()
    end
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

--- @param opts {win?:integer}
--- @return integer, integer|nil
--- Get loclist information for a window
--- Opts:
--- - win: The window to check loclist information for
--- Returns:
--- - the qf_id and the open loclist winid, if it exists
function M._get_loclist_info(opts)
    opts = opts or {}
    vim.validate("opts.win", opts.win, { "nil", "number" })

    local win = opts.win or vim.api.nvim_get_current_win() --- @type integer
    local qf_id = vim.fn.getloclist(win, { id = 0 }).id --- @type integer
    if qf_id == 0 then
        return qf_id, nil
    end

    return qf_id, M._find_loclist_win(win, qf_id)
end

--- @param opts {win?:integer}
--- @return boolean
function M._has_any_loclist(opts)
    opts = opts or {}
    vim.validate("opts.win", opts.win, { "nil", "number" })

    local win = opts.win or vim.api.nvim_get_current_win() --- @type integer

    local max_nr = vim.fn.getloclist(win, { nr = "$" }).nr --- @type integer
    if max_nr == 0 then
        return false
    end

    for i = 1, max_nr do
        local size = vim.fn.getloclist(win, { nr = i, size = 0 }).size --- @type integer
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

--- @param output_opts QfRancherOutputOpts
--- @return nil|fun(table):any|nil
--- If no win is provided, the current win is used as a fallback
--- If no get_loclist value is provided or it is false, getqflist is always returned
--- If a win is provided but it cannot have a loclist, nil is returned
function M._get_getlist(output_opts)
    output_opts = output_opts or {}
    if vim.g.qf_rancher_debug_assertions then
        M._validate_output_opts(output_opts)
    end

    if not output_opts.use_loclist then
        return vim.fn.getqflist
    end

    local win = output_opts.loclist_source_win or vim.api.nvim_get_current_win() --- @type integer
    if not source_win_can_have_loclist(win) then
        return nil
    end

    return function(what)
        return what and vim.fn.getloclist(win, what) or vim.fn.getloclist(win)
    end
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
--- @param input_opts QfRancherInputOpts
--- @return string|nil
function M._resolve_pattern(prompt, input_opts)
    vim.validate("prompt", prompt, "string")
    vim.validate("input_opts", input_opts, "table")
    vim.validate("input_opts.pattern", input_opts.pattern, { "nil", "string" })

    if input_opts.pattern then
        return input_opts.pattern
    end

    local mode = vim.fn.mode() --- @type string
    local is_visual = mode == "v" or mode == "V" or mode == "\22" --- @type boolean
    if is_visual then
        return get_visual_pattern(mode)
    end

    return get_input(prompt)
end

--- @param output_opts QfRancherOutputOpts
--- @return function|nil
function M._get_setlist(output_opts)
    output_opts = output_opts or {}
    if vim.g.qf_rancher_debug_assertions then
        M._validate_output_opts(output_opts)
    end

    if not output_opts.use_loclist then
        return vim.fn.setqflist
    end

    local win = output_opts.loclist_source_win or vim.api.nvim_get_current_win()
    if not source_win_can_have_loclist(win) then
        return nil
    end

    return function(dict, a, b)
        local action, what
        if type(a) == "table" then
            action = ""
            what = a
        elseif type(a) == "string" and a ~= "" or a == "" then
            action = a
            what = b or {}
        elseif a == nil then
            action = ""
            what = b or {}
        else
            error("Invalid action: must be a non-nil string")
        end

        vim.fn.setloclist(win, dict, action, what)
    end
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

--- @param input_type QfRancherInputType
--- @return boolean
function M.validate_input_type(input_type)
    vim.validate("input_type", input_type, "string")
    return input_type == "insensitive"
        or input_type == "regex"
        or input_type == "sensitive"
        or input_type == "smart"
        or input_type == "vimsmart"
end

-- TODO: similar issue here where this should only be for validation, not changing

--- @param input_opts QfRancherInputOpts
function M._validate_input_opts(input_opts)
    vim.validate("input_opts", input_opts, "table")
    -- Allow nil input patterns to pass through. Each function should resolve individually
    vim.validate("input_opts.pattern", input_opts.pattern, { "nil", "string" })
    -- Since input type never *should* be blank, fix nils here
    vim.validate("input_opts.input_type", input_opts.input_type, { "nil", "string" })
    if type(input_opts.input_type) == "string" then
        M.validate_input_type(input_opts.input_type)
    else
        input_opts.input_type = "vimsmart"
    end
end

--- TODO: Move this to validations if the "output_opts" construct is still around

--- @param output_opts QfRancherOutputOpts
--- @return nil
function M._validate_output_opts(output_opts)
    vim.validate("output_opts", output_opts, "table")
    vim.validate("output_opts.action", output_opts.action, "string")
    vim.validate("output_opts.action", output_opts.action, function()
        return output_opts.action == "new"
            or output_opts.action == "replace"
            or output_opts.action == "add"
    end)

    vim.validate("output_opts.count", output_opts.count, { "nil", "number" })
    vim.validate("output_opts.is_loclist", output_opts.use_loclist, { "nil", "boolean" })
    vim.validate(
        "output_opts.loclist_source_win",
        output_opts.loclist_source_win,
        { "nil", "number" }
    )

    vim.validate("output_opts.list_item_type", output_opts.list_item_type, { "nil", "string" })
    vim.validate("output_opts.title", output_opts.title, { "nil", "string" })
end

--- @param output_opts QfRancherOutputOpts
--- @return nil
function M._clean_output_opts(output_opts)
    M._validate_output_opts(output_opts)
    --- TODO: Need to look at how this is used and see if it's correct. I think the idea is
    --- everything pipes into set_items, but there are ex_cmds where we want nil counts
    output_opts.count = output_opts.count or 0
    output_opts.use_loclist = output_opts.use_loclist == nil and false or output_opts.use_loclist
    --- TODO: Unsure if this is correct. If we want to manually set a source win, we can obviously
    --- do that on top of this, but that then makes this wasteful
    output_opts.loclist_source_win = output_opts.loclist_source_win == nil
            and vim.api.nvim_get_current_win()
        or output_opts.loclist_source_win
end

--- @param input QfRancherInputType
--- @return string
--- NOTE: This function assumes that an API input of "vimsmart" has already been resolved
function M._get_display_input_type(input)
    if input == "regex" then
        return "Regex"
    elseif input == "sensitive" then
        return "Case Sensitive"
    elseif input == "smart" then
        return "Smartcase"
    else
        return "Case Insensitive"
    end
end

--- @param input QfRancherInputType|nil
--- @return QfRancherInputType
function M._resolve_input_type(input)
    if not input then
        return "sensitive"
    end

    if input ~= "vimsmart" then
        return input
    end

    if vim.g.qf_rancher_use_smartcase == true then
        return "smart"
    -- Specifically compare with boolean false to ignore nils
    elseif vim.g.qf_rancher_use_smartcase == false then
        return "insensitive"
    end

    if vim.api.nvim_get_option_value("smartcase", { scope = "global" }) then
        return "smart"
    end

    return "insensitive"
end

--- TODO: I would like to remove the external reference to this in the filter file, then maybe
--- this would be re-inlined into the set list function
--- @param getlist function
--- @param output_opts QfRancherOutputOpts
--- @return integer
function M._get_dest_list_nr(getlist, output_opts)
    output_opts = output_opts or {}
    if vim.g.qf_rancher_debug_assertions then
        M._validate_output_opts(output_opts)
    end

    local count = output_opts.count > 0 and output_opts.count or 0
    count = (output_opts.count < 1 and vim.v.count > 0) and vim.v.count or 0
    if count > 0 then
        return math.min(count, getlist({ nr = "$" }).nr)
    end

    if output_opts.action == "overwrite" or output_opts.action == "merge" then
        return getlist({ nr = 0 }).nr
    end

    return getlist({ nr = "$" }).nr
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

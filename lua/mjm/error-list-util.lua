--- @class QfRancherUtils
local M = {}

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
function M.check_loclist_output(output_opts)
    if not output_opts.is_loclist then
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
function M.find_loclist_win(win, qf_id)
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
            return win
        end
    end

    return nil
end

--- @param output_opts? QfRancherOutputOpts
--- @return integer|nil
function M._find_list_win(output_opts)
    output_opts = output_opts or {}
    if vim.g.qf_rancher_debug_assertions then
        M.validate_output_opts(output_opts)
    end

    if output_opts.is_loclist then
        --- @type integer
        local win = output_opts.loclist_source_win or vim.api.nvim_get_current_win()
        return M.find_loclist_win(win)
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

    return qf_id, M.find_loclist_win(win, qf_id)
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
        M.validate_output_opts(output_opts)
    end

    if not output_opts.is_loclist then
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
        M.validate_output_opts(output_opts)
    end

    if not output_opts.is_loclist then
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
function M._check_str_list(table)
    if type(table) ~= "table" then
        return false
    end

    assert(type(table) == "table", "List is not a table")
    assert(#table > 0, "Table has no entries")

    for k, v in ipairs(table) do
        assert(type(k) == "number", "Key " .. vim.inspect(k) .. " is not a number")
        assert(type(v) == "string", "Item " .. vim.inspect(v) .. " is not a string")
    end
end

--- @param action QfRancherAction
--- @return boolean
function M.validate_action(action)
    return action == "new" or action == "replace" or action == "add"
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
function M.validate_input_opts(input_opts)
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

-- TODO: Need to change this so that the cleaning doesn't actualy happen here. Because this
-- function is re-used so much, only want to ensure state is correct. Cleanup should be its own
-- thing

--- @param output_opts QfRancherOutputOpts
function M.validate_output_opts(output_opts)
    vim.validate("output_opts", output_opts, "table")

    vim.validate("output_opts.is_loclist", output_opts.is_loclist, { "nil", "boolean" })
    output_opts.is_loclist = output_opts.is_loclist == nil and false or output_opts.is_loclist
    vim.validate(
        "output_opts.loclist_source_win",
        output_opts.loclist_source_win,
        { "nil", "number" }
    )

    -- If the caller does not specify, assume that it's for the current window
    output_opts.loclist_source_win = output_opts.loclist_source_win == nil
            and vim.api.nvim_get_current_win()
        or output_opts.loclist_source_win

    vim.validate("output_opts.action", output_opts.action, { "nil", "string" })
    if type(output_opts.action) == "string" then
        vim.validate("action", output_opts.action, function()
            return require("mjm.error-list-util").validate_action(output_opts.action)
        end)
    else
        -- Set the default here for consistency
        output_opts.action = "new" --- Cfilter default
    end

    -- Set a consistent default here as well to avoid having a bunch of different count handling
    -- methods
    vim.validate("output_opts.count", output_opts.count, { "nil", "number" })
    output_opts.count = output_opts.count or 0

    -- Leave nil titles be here, as each function might have its own way of assigning one
    vim.validate("output_opts.title", output_opts.title, { "nil", "string" })

    -- Leave nil here. We assume that, if the list_item_type is nil, we don't want to perform a
    -- manual edit. Individual functions might have their own ways of setting this up
    vim.validate("output_opts.list_item_type", output_opts.list_item_type, { "nil", "string" })
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

--- @param getlist function
--- @param output_opts QfRancherOutputOpts
--- @return integer
function M._get_dest_list_nr(getlist, output_opts)
    output_opts = output_opts or {}

    if vim.g.qf_rancher_debug_assertions then
        M.validate_output_opts(output_opts)
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

--- @param old_list table
--- @param opts? {new_list_nr?: integer|string, new_list_items?: table[], new_title?:string}
--- @return table
local function get_new_list(old_list, opts)
    opts = opts or {}
    vim.validate("old_list", old_list, "table")
    vim.validate("opts", opts, { "nil", "table" })
    vim.validate("opts.new_list_nr", opts.new_list_nr, { "nil", "number", "string" })
    vim.validate("opts.new_list_items", opts.new_list_items, { "nil", "table" })
    vim.validate("opts.new_title", opts.new_title, { "nil", "string" })

    local items = opts.new_list_items or old_list.items
    local list_nr = opts.new_list_nr or old_list.nr
    local title = opts.new_title or old_list.title

    return {
        context = old_list.context,
        idx = old_list.idx,
        items = items,
        nr = list_nr,
        quickfixtextfunc = old_list.quickfixtextfunc,
        title = title,
    }
end

--- @param getlist function
--- @param setlist function
--- @param start_list_nr integer|string
--- @return nil
function M.cycle_lists_down(getlist, setlist, start_list_nr)
    vim.validate("getlist", getlist, "callable")
    vim.validate("setlist", setlist, "callable")
    vim.validate("start_list_nr", start_list_nr, "number")
    vim.validate("start_list_nr", start_list_nr, function()
        return start_list_nr >= 1
    end)

    local max_nr = getlist({ nr = "$" }).nr --- @type integer
    assert(start_list_nr <= max_nr)

    for i = start_list_nr, 2, -1 do
        local list = getlist({ nr = i, all = true }) --- @type table
        local new_list = get_new_list(list, { new_list_nr = i - 1 })
        setlist({}, "r", new_list)
    end
end

--- @class QfRancherSetOpts
--- @field getlist? function
--- @field setlist? function
--- @field new_items table[]

--- @param set_opts QfRancherSetOpts
--- @param output_opts QfRancherOutputOpts
--- @return nil
function M.set_list_items(set_opts, output_opts)
    set_opts = set_opts or {}

    if vim.g.qf_rancher_debug_assertions then
        vim.validate("set_opts", set_opts, "table")
        vim.validate("set_opts.getlist", set_opts.getlist, { "callable", "nil" })
        vim.validate("set_opts.setlist", set_opts.setlist, { "callable", "nil" })

        M.validate_output_opts(output_opts)
    end

    local getlist = set_opts.getlist or M._get_getlist(output_opts)
    if not getlist then
        return
    end

    local setlist = set_opts.setlist or M._get_setlist(output_opts)
    if not setlist then
        return
    end

    local dest_list_nr = M._get_dest_list_nr(getlist, output_opts)

    -- TODO: Basically trying to address that if we have an empty list, the action doesn't matter
    -- and we're just making a new one. But then we kinda repeat the logic in the new case
    -- Feels hacky right now
    local max_list_nr = getlist({ nr = "$" }).nr
    if max_list_nr == 0 then
        setlist({}, " ", { items = set_opts.new_items, nr = "$", title = output_opts.title })
        return
    end

    if output_opts.action == "replace" then
        local old_list = getlist({ nr = dest_list_nr, all = true })
        local new_list = get_new_list(
            old_list,
            { new_list_items = set_opts.new_items, new_title = output_opts.title }
        )
        setlist({}, "r", new_list)
        return
    end

    if output_opts.action == "add" then
        local old_list = getlist({ nr = dest_list_nr, all = true })
        local new_list_items = M._merge_qf_lists(old_list.items, set_opts.new_items)
        --- NOTE: We simply have to assume here that calling functions know the sort is performed
        --- here and don't do one redundantly
        --- TODO: This does not properly handle diagnostics. I guess you could have a field in
        --- output_opts that says if the output list is supposed to be diagnostics
        --- TODO: This is also awkward if we're coming in from a sort. Probably need to have a
        --- sort predicate in the output opts, which is a lot but it will work
        table.sort(new_list_items, require("mjm.error-list-sort")._sort_fname_asc)
        local new_list = get_new_list(
            old_list,
            { new_list_items = new_list_items, new_title = output_opts.title }
        )
        setlist({}, "u", new_list)
        return
    end

    if dest_list_nr == max_list_nr then
        setlist(
            {},
            " ",
            { items = set_opts.new_items, nr = dest_list_nr, title = output_opts.title }
        )
        return
    end

    M.cycle_lists_down(getlist, setlist, dest_list_nr)
    setlist({}, "r", { items = set_opts.new_items, nr = dest_list_nr, title = output_opts.title })

    if not vim.g.qf_rancher_auto_open_changes then
        return
    end

    M._get_openlist(output_opts.is_loclist)({ always_resize = true })
    local cur_list = getlist({ nr = 0 }).nr
    if cur_list == dest_list_nr then
        return
    end

    require("mjm.error-list-stack")._get_gethistory(output_opts.is_loclist)(dest_list_nr)
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

-------------
--- Types ---
-------------

--- @class QfRancherDiagToListOpts
--- @field set_action? QfRancherSetlistAction
--- @field is_loclist? boolean
--- @field min_severity? integer
--- @field severity? integer
--- @field top_severity? boolean

local function get_top_severity(diags)
    local severity = vim.diagnostic.severity.HINT --- @type integer
    for _, diag in pairs(diags) do
        if diag.severity < severity then
            severity = diag.severity
        end
    end

    return severity
end

local function filter_diags_top_severity(diags)
    local top_severity = get_top_severity(diags)
    return vim.tbl_filter(function(diag)
        return diag.severity == top_severity
    end, diags)
end

local severity_map = {
    [vim.diagnostic.severity.ERROR] = "E",
    [vim.diagnostic.severity.WARN] = "W",
    [vim.diagnostic.severity.INFO] = "I",
    [vim.diagnostic.severity.HINT] = "H",
} ---@type table<integer, string>

---@param d vim.Diagnostic
---@return table
local function convert_diag(d)
    d = d or {}
    local source = d.source and d.source .. ": " or "" ---@type string
    return {
        bufnr = d.bufnr,
        col = d.col and (d.col + 1) or nil,
        end_col = d.end_col and (d.end_col + 1) or nil,
        end_lnum = d.end_lnum and (d.end_lnum + 1) or nil,
        lnum = d.lnum + 1,
        nr = tonumber(d.code),
        text = source .. (d.message or ""),
        type = severity_map[d.severity] or "E",
        valid = 1,
    }
end

--- @param opts? QfRancherDiagToListOpts
--- NOTE: To get all diagnostics, avoid passing in a severity opt. If vim.diagnostic.get does not
--- receive a severity option, it will simply compare all diagnostics to true, whereas if it
--- is given a severity filter, even a permissive one, each diag has to be compared against it
--- NOTE: severity overrides min_severity. Either can be mixed with top_severity
local function diags_to_list(opts)
    opts = opts or {}
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    local buf = opts.is_loclist and vim.api.nvim_win_get_buf(cur_win) or nil --- @type integer|nil
    local severity = (function()
        if opts.severity then
            return opts.severity
        elseif opts.min_severity then
            return { min = opts.min_severity }
        end
    end)() --- @type integer|{min:integer}|nil

    local raw_diags = vim.diagnostic.get(buf, { severity = severity }) --- @type vim.Diagnostic[]
    if #raw_diags == 0 then
        vim.api.nvim_echo({ { "No diagnostics", "" } }, false, {})
        return
    end

    if opts.top_severity then
        raw_diags = filter_diags_top_severity(raw_diags)
    end

    local converted_diags = vim.tbl_map(convert_diag, raw_diags) ---@type table[]
    local eu = require("mjm.error-list-util")
    local getlist = eu.get_getlist({ win = cur_win, get_loclist = opts.is_loclist })
    opts.set_action = opts.set_action or "new"
    local list_nr = eu.get_list_nr(getlist, opts.set_action)
    if opts.set_action == "add" then
        local cur_list = getlist({ nr = list_nr, items = true })
        converted_diags = eu.merge_qf_lists(converted_diags, cur_list.items)
    end

    table.sort(converted_diags, require("mjm.error-list-sort").sort_diag_fname_asc)
    local setlist = eu.get_setlist(opts.is_loclist, cur_win)
    local is_replace = opts.set_action == "add" or opts.set_action == "overwrite"
    local action = is_replace and "r" or " "
    local title = "vim.diagnostic.get()"
    setlist({}, action, { items = converted_diags, nr = list_nr, title = title })

    if opts.set_action == "add" or opts.set_action == "overwrite" then
        require("mjm.error-list-stack").get_history(opts.is_loclist)(list_nr)
    end

    eu.get_openlist(opts.is_loclist)({ always_resize = true })
end
---
--- TODO: Naming conventions:
--- - Qdiag
--- - Qdiagadd
--- - Qdiagreplace (?)
--- - Qdiag top (top severity)
--- - Qdiag info (min severity info)
--- - Qdiag info only (only show info)

vim.keymap.set("n", "<leader>qin", function()
    diags_to_list()
end)

vim.keymap.set("n", "<leader>qif", function()
    diags_to_list({ min_severity = vim.diagnostic.severity.INFO })
end)

vim.keymap.set("n", "<leader>qiw", function()
    diags_to_list({ min_severity = vim.diagnostic.severity.WARN })
end)

vim.keymap.set("n", "<leader>qie", function()
    diags_to_list({ min_severity = vim.diagnostic.severity.ERROR })
end)

vim.keymap.set("n", "<leader>qiN", function()
    diags_to_list({ severity = vim.diagnostic.severity.HINT })
end)

vim.keymap.set("n", "<leader>qiF", function()
    diags_to_list({ severity = vim.diagnostic.severity.INFO })
end)

vim.keymap.set("n", "<leader>qiW", function()
    diags_to_list({ severity = vim.diagnostic.severity.WARN })
end)

vim.keymap.set("n", "<leader>qiE", function()
    diags_to_list({ severity = vim.diagnostic.severity.ERROR })
end)

vim.keymap.set("n", "<leader>qit", function()
    diags_to_list({ top_severity = true })
end)

vim.keymap.set("n", "<leader>qIn", function()
    diags_to_list({ set_action = "overwrite" })
end)

vim.keymap.set("n", "<leader>qIf", function()
    diags_to_list({ set_action = "overwrite", min_severity = vim.diagnostic.severity.INFO })
end)

vim.keymap.set("n", "<leader>qIw", function()
    diags_to_list({ set_action = "overwrite", min_severity = vim.diagnostic.severity.WARN })
end)

vim.keymap.set("n", "<leader>qIe", function()
    diags_to_list({ set_action = "overwrite", min_severity = vim.diagnostic.severity.ERROR })
end)

vim.keymap.set("n", "<leader>qIN", function()
    diags_to_list({ set_action = "overwrite", severity = vim.diagnostic.severity.HINT })
end)

vim.keymap.set("n", "<leader>qIF", function()
    diags_to_list({ set_action = "overwrite", severity = vim.diagnostic.severity.INFO })
end)

vim.keymap.set("n", "<leader>qIW", function()
    diags_to_list({ set_action = "overwrite", severity = vim.diagnostic.severity.WARN })
end)

vim.keymap.set("n", "<leader>qIE", function()
    diags_to_list({ set_action = "overwrite", severity = vim.diagnostic.severity.ERROR })
end)

vim.keymap.set("n", "<leader>qIt", function()
    diags_to_list({ set_action = "overwrite", top_severity = true })
end)

vim.keymap.set("n", "<leader>q<C-i>n", function()
    diags_to_list({ set_action = "add" })
end)

vim.keymap.set("n", "<leader>q<C-i>f", function()
    diags_to_list({ set_action = "add", min_severity = vim.diagnostic.severity.INFO })
end)

vim.keymap.set("n", "<leader>q<C-i>w", function()
    diags_to_list({ set_action = "add", min_severity = vim.diagnostic.severity.WARN })
end)

vim.keymap.set("n", "<leader>q<C-i>e", function()
    diags_to_list({ set_action = "add", min_severity = vim.diagnostic.severity.ERROR })
end)

vim.keymap.set("n", "<leader>q<C-i>N", function()
    diags_to_list({ set_action = "add", severity = vim.diagnostic.severity.HINT })
end)

vim.keymap.set("n", "<leader>q<C-i>F", function()
    diags_to_list({ set_action = "add", severity = vim.diagnostic.severity.INFO })
end)

vim.keymap.set("n", "<leader>q<C-i>W", function()
    diags_to_list({ set_action = "add", severity = vim.diagnostic.severity.WARN })
end)

vim.keymap.set("n", "<leader>q<C-i>E", function()
    diags_to_list({ set_action = "add", severity = vim.diagnostic.severity.ERROR })
end)

vim.keymap.set("n", "<leader>q<C-i>t", function()
    diags_to_list({ set_action = "add", top_severity = true })
end)

vim.keymap.set("n", "<leader>lin", function()
    diags_to_list({ is_loclist = true })
end)

vim.keymap.set("n", "<leader>lif", function()
    diags_to_list({ is_loclist = true, min_severity = vim.diagnostic.severity.INFO })
end)

vim.keymap.set("n", "<leader>liw", function()
    diags_to_list({ is_loclist = true, min_severity = vim.diagnostic.severity.WARN })
end)

vim.keymap.set("n", "<leader>lie", function()
    diags_to_list({ is_loclist = true, min_severity = vim.diagnostic.severity.ERROR })
end)

vim.keymap.set("n", "<leader>liN", function()
    diags_to_list({ is_loclist = true, severity = vim.diagnostic.severity.HINT })
end)

vim.keymap.set("n", "<leader>liF", function()
    diags_to_list({ is_loclist = true, severity = vim.diagnostic.severity.INFO })
end)

vim.keymap.set("n", "<leader>liW", function()
    diags_to_list({ is_loclist = true, severity = vim.diagnostic.severity.WARN })
end)

vim.keymap.set("n", "<leader>liE", function()
    diags_to_list({ is_loclist = true, severity = vim.diagnostic.severity.ERROR })
end)

vim.keymap.set("n", "<leader>lit", function()
    diags_to_list({ is_loclist = true, top_severity = true })
end)

vim.keymap.set("n", "<leader>lIn", function()
    diags_to_list({ is_loclist = true, set_action = "overwrite" })
end)

vim.keymap.set("n", "<leader>lIf", function()
    diags_to_list({
        is_loclist = true,
        set_action = "overwrite",
        min_severity = vim.diagnostic.severity.INFO,
    })
end)

vim.keymap.set("n", "<leader>lIw", function()
    diags_to_list({
        is_loclist = true,
        set_action = "overwrite",
        min_severity = vim.diagnostic.severity.WARN,
    })
end)

vim.keymap.set("n", "<leader>lIe", function()
    diags_to_list({
        is_loclist = true,
        set_action = "overwrite",
        min_severity = vim.diagnostic.severity.ERROR,
    })
end)

vim.keymap.set("n", "<leader>lIN", function()
    diags_to_list({
        is_loclist = true,
        set_action = "overwrite",
        severity = vim.diagnostic.severity.HINT,
    })
end)

vim.keymap.set("n", "<leader>lIF", function()
    diags_to_list({
        is_loclist = true,
        set_action = "overwrite",
        severity = vim.diagnostic.severity.INFO,
    })
end)

vim.keymap.set("n", "<leader>lIW", function()
    diags_to_list({
        is_loclist = true,
        set_action = "overwrite",
        severity = vim.diagnostic.severity.WARN,
    })
end)

vim.keymap.set("n", "<leader>lIE", function()
    diags_to_list({
        is_loclist = true,
        set_action = "overwrite",
        severity = vim.diagnostic.severity.ERROR,
    })
end)

vim.keymap.set("n", "<leader>lIt", function()
    diags_to_list({ is_loclist = true, set_action = "overwrite", top_severity = true })
end)

vim.keymap.set("n", "<leader>l<C-i>n", function()
    diags_to_list({ is_loclist = true, set_action = "add" })
end)

vim.keymap.set("n", "<leader>l<C-i>f", function()
    diags_to_list({
        is_loclist = true,
        set_action = "add",
        min_severity = vim.diagnostic.severity.INFO,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>w", function()
    diags_to_list({
        is_loclist = true,
        set_action = "add",
        min_severity = vim.diagnostic.severity.WARN,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>e", function()
    diags_to_list({
        is_loclist = true,
        set_action = "add",
        min_severity = vim.diagnostic.severity.ERROR,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>N", function()
    diags_to_list({
        is_loclist = true,
        set_action = "add",
        severity = vim.diagnostic.severity.HINT,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>F", function()
    diags_to_list({
        is_loclist = true,
        set_action = "add",
        severity = vim.diagnostic.severity.INFO,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>W", function()
    diags_to_list({
        is_loclist = true,
        set_action = "add",
        severity = vim.diagnostic.severity.WARN,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>E", function()
    diags_to_list({
        is_loclist = true,
        set_action = "add",
        severity = vim.diagnostic.severity.ERROR,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>t", function()
    diags_to_list({ is_loclist = true, set_action = "add", top_severity = true })
end)

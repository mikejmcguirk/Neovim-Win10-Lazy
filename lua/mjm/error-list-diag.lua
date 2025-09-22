--- TODO:
--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation

-------------
--- Types ---
-------------

--- MAYBE: You could allow passing win and buf options so this option could be called in scripts,
--- but that creates complexities around how you prioritize the different options. Omitting since
--- for now this is a hypothetical use case

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

-- PERF: Could pre-allocate the return table, but I don't see a consistent solution for how to
-- handle for lengths only known at runtime in LuaJIT/5.1. Should not matter in practice
local function filter_diags_by_severity(diags)
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

-- what diag level
-- create new, overwrite, merge
-- if there is a count
-- what list it goes to
-- buf diags or all diags

--- @param opts? QfRancherDiagToListOpts
--- NOTE: To get all diagnostics, avoid passing in a severity opt. If vim.diagnostic.get does not
--- receive a severity option, it will simply compare all diagnostics to true, whereas if it
--- is given a severity filter, even a permissive one, each diag has to be compared against it
--- NOTE: severity overrides min_severity. Either can be mixed with top_severity
local function diags_to_list(opts)
    opts = opts or {}
    local cur_win = vim.api.nvim_get_current_win() --- @type integer
    --- MAYBE: It makes this function less flexible if sending to a location list automatically
    --- restricts to current buf. But given that I'm not sure what the use case is for how win
    --- and buf specfic options would be used, I don't want to create contrived logic to handle
    --- hypotheticals
    local buf = opts.is_loclist and vim.api.nvim_win_get_buf(cur_win) or nil --- @type integer|nil

    local severity = (function()
        if opts.severity then
            return opts.severity
        elseif opts.min_severity then
            return { min = opts.min_severity }
        end
    end)() --- @type integer|{min:integer}|nil

    --- @type vim.Diagnostic[]
    local raw_diags = vim.diagnostic.get(buf, { severity = severity })
    if #raw_diags == 0 then
        -- TODO: Print more specific messages based on severity opts
        vim.api.nvim_echo({ { "No diagnostics", "" } }, false, {})
        return
    end

    if opts.top_severity then
        raw_diags = filter_diags_by_severity(raw_diags)
    end

    local converted_diags = vim.tbl_map(convert_diag, raw_diags) ---@type table[]

    local eu = require("mjm.error-list-util")
    local getlist = eu.get_getlist({ win = cur_win, get_loclist = opts.is_loclist })
    opts.set_action = opts.set_action or "new"
    local list_nr = eu.get_list_nr(getlist, opts.set_action)

    if opts.set_action == "merge" then
        local cur_list = getlist({ nr = list_nr, items = true })
        converted_diags = eu.merge_qf_lists(converted_diags, cur_list.items)
    end

    --- PERF: Right now, the diag severities are mapped to the qf types, then un-mapped again
    --- in the sort function. In theory, the types should be put into the list items as raw
    --- values, the converted on sort. In practice, this creates complexity + room for error
    --- Unsure if there's a worthwhile performance gain here, though this is a hot loop
    table.sort(converted_diags, require("mjm.error-list-sort").sort_diag_fname_asc)
    local setlist = eu.get_setlist(opts.is_loclist, cur_win)
    local is_replace = opts.set_action == "merge" or opts.set_action == "overwrite"
    local action = is_replace and "r" or " "
    -- TODO: more specific title based on query
    local title = "Diagnostics"
    setlist({}, action, { items = converted_diags, nr = list_nr, title = title })
    -- vim.fn.setqflist({}, " ", { items = converted_diags, nr = list_nr, title = title })

    -- TODO: This is silly because we have to scan the wins for the open and then scan again, and
    -- build the views table, for the resize. One option, that's concise but somewhat unclear, is
    -- to allow the open function to perform a resize if it finds an open win. For clarity, the
    -- default behavior can function as a pure open, and then the resize functions can basically
    -- serve as option wrappers for the open. Another is for the open function to return the win
    -- if found, but I have no idea what the implications of that would be. The first solution is
    -- a bit design patterny, but also seems like the simplest
    -- An additional issue here is, because history is run after this, you get one set height
    -- for the current open, and then we move to history. Right now, this means we are setting
    -- height for the current list but not the next one, which creates unpleasing results. But
    -- even with more fixed code, we are setting heigh twice, which is inefficient/cound create
    -- flicker
    local did_openlist = eu.get_openlist(opts.is_loclist)()
    if opts.set_action == "merge" or opts.set_action == "overwrite" then
        -- TODO: Also set if number? I forget if this is automatic
        if opts.is_loclist then
            vim.cmd(list_nr .. "lhistory")
        else
            vim.cmd(list_nr .. "chistory")
        end
    end

    if not did_openlist then
        eu.get_resizelist(opts.is_loclist)()
    end

    -- TODO:
    -- an issue with modularizing the write functions is - is there anything we can do to early
    -- exit before we go through the business of working the diags?
    -- an additional issue is, AFAIK, the system functions send, or at least get, a full dict of
    -- qf values, whereas this one is just the items
    -- And even if that's not true, if we're thinking about how to create the abstraction, it then
    -- needs to be able to handle any type of qf data it throws at it and be able to perform the
    -- proper sets. And you need to be able to send a dict of the various actions you want to throw
    -- at it.
    -- It is definitely correct to throw the various pieces of logic for setting into a utils
    -- folder so they are composable pieces for other functions. But I'm less and less convinced
    -- that actually turning the qf writing into a separate module is correct, because there are
    -- a lot of theoretical corner cases to handle and not enough concrete examples to point to
    -- how to work through them without creating a contrived, and I worry premature, abstraction
end

-- TODO: Almost 300 lines of setting keymaps is in poor taste
-- Gets to broader issue: The push right now in plugins is to provide plugin maps and not defaults,
-- but even if you provide a default config to copy, will still be *a lot* of maps across all
-- functions. Need to not only provide defaults, but a few days of customizing them, because
-- doing it custom is a non-trivial lift.
-- You need global enable/disable, as well as enable/disable for each broad category (diags,
-- grep, filter, sort). You also need global settings for the lsit prefix (<leaderq/<leader>l)
-- Where things get tricker then is the sub commands. Right now we are roughly saying qi is diag,
-- qg (should be qe!) is grep, and so on. Okay so you offer the ability to change the middle
-- prefix. Sure.
-- But now do you offer the ability to change what the derivations of the prefix mean? right now,
-- lowercase is new, uppercase is overwrite, and ctrl is merge. The config for that would be
-- complicated to write, and I have a feeling that, for a user to understand it, would be more
-- work than just doing their own plug mappings
-- And I also feel that way about the individual commands and their meanings

--- MAYBE: Ideas for ctrl-diag_type mappings:
--- --- Min severity + sort by type > lnum (sort maps already exist though)
--- --- Use the diag type as the max severity

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
    diags_to_list({ set_action = "merge" })
end)

vim.keymap.set("n", "<leader>q<C-i>f", function()
    diags_to_list({ set_action = "merge", min_severity = vim.diagnostic.severity.INFO })
end)

vim.keymap.set("n", "<leader>q<C-i>w", function()
    diags_to_list({ set_action = "merge", min_severity = vim.diagnostic.severity.WARN })
end)

vim.keymap.set("n", "<leader>q<C-i>e", function()
    diags_to_list({ set_action = "merge", min_severity = vim.diagnostic.severity.ERROR })
end)

vim.keymap.set("n", "<leader>q<C-i>N", function()
    diags_to_list({ set_action = "merge", severity = vim.diagnostic.severity.HINT })
end)

vim.keymap.set("n", "<leader>q<C-i>F", function()
    diags_to_list({ set_action = "merge", severity = vim.diagnostic.severity.INFO })
end)

vim.keymap.set("n", "<leader>q<C-i>W", function()
    diags_to_list({ set_action = "merge", severity = vim.diagnostic.severity.WARN })
end)

vim.keymap.set("n", "<leader>q<C-i>E", function()
    diags_to_list({ set_action = "merge", severity = vim.diagnostic.severity.ERROR })
end)

vim.keymap.set("n", "<leader>q<C-i>t", function()
    diags_to_list({ set_action = "merge", top_severity = true })
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
    diags_to_list({ is_loclist = true, set_action = "merge" })
end)

vim.keymap.set("n", "<leader>l<C-i>f", function()
    diags_to_list({
        is_loclist = true,
        set_action = "merge",
        min_severity = vim.diagnostic.severity.INFO,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>w", function()
    diags_to_list({
        is_loclist = true,
        set_action = "merge",
        min_severity = vim.diagnostic.severity.WARN,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>e", function()
    diags_to_list({
        is_loclist = true,
        set_action = "merge",
        min_severity = vim.diagnostic.severity.ERROR,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>N", function()
    diags_to_list({
        is_loclist = true,
        set_action = "merge",
        severity = vim.diagnostic.severity.HINT,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>F", function()
    diags_to_list({
        is_loclist = true,
        set_action = "merge",
        severity = vim.diagnostic.severity.INFO,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>W", function()
    diags_to_list({
        is_loclist = true,
        set_action = "merge",
        severity = vim.diagnostic.severity.WARN,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>E", function()
    diags_to_list({
        is_loclist = true,
        set_action = "merge",
        severity = vim.diagnostic.severity.ERROR,
    })
end)

vim.keymap.set("n", "<leader>l<C-i>t", function()
    diags_to_list({ is_loclist = true, set_action = "merge", top_severity = true })
end)

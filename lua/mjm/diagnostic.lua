local main_diag_cfg = {
    float = { source = "always", border = Border },
    severity_sort = true,
    signs = {
        severity = {
            min = vim.diagnostic.severity.HINT,
        },
    },
} ---@type table

local virtual_text_cfg = {
    virtual_lines = false,
    virtual_text = {
        severity = {
            min = vim.diagnostic.severity.HINT,
        },
        current_line = true,
    },
} ---@type table

local virtual_lines_cfg = {
    virtual_lines = { current_line = true },
    virtual_text = false,
} ---@type table

local default_diag_cfg = vim.tbl_extend("force", main_diag_cfg, virtual_text_cfg)
local alt_diag_cfg = vim.tbl_extend("force", main_diag_cfg, virtual_lines_cfg)
vim.diagnostic.config(default_diag_cfg)
vim.keymap.set("n", "grd", function()
    local current_config = vim.diagnostic.config() or {} ---@type vim.diagnostic.Opts
    if current_config.virtual_lines == false then
        vim.diagnostic.config(alt_diag_cfg)
    else
        vim.diagnostic.config(default_diag_cfg)
    end
end)

local ut = require("mjm.utils")
vim.keymap.set("n", "[w", function()
    vim.diagnostic.jump({ count = -vim.v.count1, severity = ut.get_top_severity({ buf = 0 }) })
end)

vim.keymap.set("n", "]w", function()
    vim.diagnostic.jump({ count = vim.v.count1, severity = ut.get_top_severity({ buf = 0 }) })
end)

-- For whatever reason, [D/]D on my computer cause Neovim to lock up. Even when just using large
-- numbers for count, they don't reliably find the top and bottom diag. Instead, just search
-- for the first/last diag manually and jump to it
local function get_first_or_last_diag(opts)
    opts = opts or {}
    local diagnostics
    if opts.severity then
        diagnostics = vim.diagnostic.get(0, { severity = opts.severity })
    else
        diagnostics = vim.diagnostic.get(0)
    end

    if #diagnostics == 0 then
        vim.notify("No diagnostics in current buffer")
        return nil
    end

    table.sort(diagnostics, function(a, b)
        if a.lnum ~= b.lnum then
            return a.lnum < b.lnum
        end

        if a.severity ~= b.severity then
            return a.severity < b.severity
        end

        if a.end_lnum ~= b.end_lnum then
            return a.end_lnum < b.end_lnum
        end

        if a.col ~= b.col then
            return a.col < b.col
        end

        return a.end_col < b.end_col
    end)

    return opts.last and diagnostics[#diagnostics] or diagnostics[1]
end

vim.keymap.set("n", "[D", function()
    local diagnostic = get_first_or_last_diag()
    if not diagnostic then
        return
    end
    vim.diagnostic.jump({
        diagnostic = diagnostic,
    })
end)

vim.keymap.set("n", "]D", function()
    local diagnostic = get_first_or_last_diag({ last = true })
    if not diagnostic then
        return
    end
    vim.diagnostic.jump({
        diagnostic = diagnostic,
    })
end)

vim.keymap.set("n", "[W", function()
    local severity = ut.get_top_severity({ buf = 0 })
    local diagnostic = get_first_or_last_diag({ severity = severity })
    if not diagnostic then
        return
    end
    vim.diagnostic.jump({
        diagnostic = diagnostic,
    })
end)

vim.keymap.set("n", "]W", function()
    local severity = ut.get_top_severity({ buf = 0 })
    local diagnostic = get_first_or_last_diag({ severity = severity, last = true })
    if not diagnostic then
        return
    end
    vim.diagnostic.jump({
        diagnostic = diagnostic,
    })
end)

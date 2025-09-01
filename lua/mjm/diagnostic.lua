local diag_main_cfg = {
    float = { source = true, border = Border },
    severity_sort = true,
} ---@type table

local virt_text_cfg = {
    virtual_lines = false,
    virtual_text = {
        current_line = true,
    },
} ---@type table

local virt_lines_cfg = {
    virtual_lines = { current_line = true },
    virtual_text = false,
} ---@type table

local diag_text_cfg = vim.tbl_extend("force", diag_main_cfg, virt_text_cfg)
local diag_lines_cfg = vim.tbl_extend("force", diag_main_cfg, virt_lines_cfg)
vim.diagnostic.config(diag_text_cfg)

-- FUTURE: Not the right keymap since this isn't an LSP feature
Map("n", "\\D", function()
    local cur_cfg = vim.diagnostic.config() or {}
    vim.diagnostic.config((not cur_cfg.virtual_lines) and diag_lines_cfg or diag_text_cfg)
end)

Map("n", "[<C-d>", function()
    vim.diagnostic.jump({
        count = -vim.v.count1,
        severity = require("mjm.utils").get_top_severity({ buf = 0 }),
    })
end)

Map("n", "]<C-d>", function()
    vim.diagnostic.jump({
        count = vim.v.count1,
        severity = require("mjm.utils").get_top_severity({ buf = 0 }),
    })
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

Map("n", "[D", function()
    local diagnostic = get_first_or_last_diag()
    if not diagnostic then
        return
    end
    vim.diagnostic.jump({
        diagnostic = diagnostic,
    })
end)

Map("n", "]D", function()
    local diagnostic = get_first_or_last_diag({ last = true })
    if not diagnostic then
        return
    end
    vim.diagnostic.jump({
        diagnostic = diagnostic,
    })
end)

Map("n", "[<M-d>", function()
    local severity = require("mjm.utils").get_top_severity({ buf = 0 })
    local diagnostic = get_first_or_last_diag({ severity = severity })
    if not diagnostic then
        return
    end
    vim.diagnostic.jump({
        diagnostic = diagnostic,
    })
end)

Map("n", "]<M-d>", function()
    local severity = require("mjm.utils").get_top_severity({ buf = 0 })
    local diagnostic = get_first_or_last_diag({ severity = severity, last = true })
    if not diagnostic then
        return
    end
    vim.diagnostic.jump({
        diagnostic = diagnostic,
    })
end)

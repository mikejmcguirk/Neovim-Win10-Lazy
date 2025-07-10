local main_diag_cfg = {
    severity_sort = true,
    float = { source = "always", border = Border },
    signs = {
        severity = {
            min = vim.diagnostic.severity.HINT,
        },
    },
} ---@type table

local virtual_text_cfg = {
    virtual_text = {
        severity = {
            min = vim.diagnostic.severity.HINT,
        },
        current_line = true,
    },
    virtual_lines = false,
} ---@type table

local virtual_lines_cfg = {
    virtual_text = false,
    virtual_lines = { current_line = true },
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
vim.keymap.set("n", "]w", function()
    vim.diagnostic.jump({ count = vim.v.count1, severity = ut.get_highest_severity({ buf = 0 }) })
end, { desc = "Jump to the next diagnostic in the current buffer prioritized by severity" })

vim.keymap.set("n", "[w", function()
    vim.diagnostic.jump({ count = -vim.v.count1, severity = ut.get_highest_severity({ buf = 0 }) })
end, { desc = "Jump to the previous diagnostic in the current buffer priotizied by severity" })

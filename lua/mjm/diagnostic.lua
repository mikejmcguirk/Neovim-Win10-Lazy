local main_diag_cfg = {
    severity_sort = true,
    float = { source = "always", border = Border },
    signs = {
        severity = {
            min = vim.diagnostic.severity.HINT,
        },
    },
}

local virtual_text_cfg = {
    virtual_text = {
        severity = {
            min = vim.diagnostic.severity.HINT,
        },
        current_line = true,
    },
    virtual_lines = false,
}

local virtual_lines_cfg = {
    virtual_text = false,
    virtual_lines = { current_line = true },
}

local default_diag_cfg = vim.tbl_extend("force", main_diag_cfg, virtual_text_cfg)
local alt_diag_cfg = vim.tbl_extend("force", main_diag_cfg, virtual_lines_cfg)
vim.diagnostic.config(default_diag_cfg)
vim.keymap.set("n", "grd", function()
    local current_config = vim.diagnostic.config() or {}
    if current_config.virtual_lines == false then
        vim.diagnostic.config(alt_diag_cfg)
    else
        vim.diagnostic.config(default_diag_cfg)
    end
end)

-- Taken from nvim-overfly
local function get_severity()
    local has_warn = false
    local has_info = false
    local has_hint = false

    for _, d in ipairs(vim.diagnostic.get(0)) do
        if d.severity == vim.diagnostic.severity.ERROR then
            return vim.diagnostic.severity.ERROR
        elseif d.severity == vim.diagnostic.severity.WARN then
            has_warn = true
        elseif d.severity == vim.diagnostic.severity.INFO then
            has_info = true
        elseif d.severity == vim.diagnostic.severity.HINT then
            has_hint = true
        end
    end

    if has_warn then
        return vim.diagnostic.severity.WARN
    elseif has_info then
        return vim.diagnostic.severity.INFO
    elseif has_hint then
        return vim.diagnostic.severity.HINT
    else
        return nil
    end
end

vim.keymap.set("n", "]w", function()
    vim.diagnostic.jump({ count = vim.v.count1, severity = get_severity() })
end, { desc = "Jump to the next diagnostic in the current buffer prioritized by severity" })

vim.keymap.set("n", "[w", function()
    vim.diagnostic.jump({ count = -vim.v.count1, severity = get_severity() })
end, { desc = "Jump to the previous diagnostic in the current buffer priotizied by severity" })

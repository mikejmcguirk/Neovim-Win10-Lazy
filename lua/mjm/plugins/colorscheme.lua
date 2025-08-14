vim.cmd.packadd({
    vim.fn.escape("fluoromachine.nvim", " "),
    bang = true,
    magic = { file = false },
})

require("fluoromachine").setup({
    brightness = 0.01,
    glow = false,
    theme = "delta",
    transparent = true,
})

vim.cmd("colorscheme fluoromachine")

local old_norm_float = vim.api.nvim_get_hl(0, { name = "NormalFloat" })
local new_norm_float = vim.tbl_extend("force", old_norm_float, { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", new_norm_float)

local old_float_border = vim.api.nvim_get_hl(0, { name = "FloatBorder" })
local new_float_border = vim.tbl_extend("force", old_float_border, { bg = "none" })
vim.api.nvim_set_hl(0, "FloatBorder", new_float_border)

local old_win_border = vim.api.nvim_get_hl(0, { name = "WinSeparator" })
local new_win_border = vim.tbl_extend("force", old_win_border, { bg = "none" })
vim.api.nvim_set_hl(0, "WinSeparator", new_win_border)

local number_hl = vim.api.nvim_get_hl(0, { name = "Number" })
local cur_search = vim.api.nvim_get_hl(0, { name = "CurSearch" })
vim.api.nvim_set_hl(0, "EolSpace", { bg = cur_search.bg, fg = number_hl.fg })

local color_col = vim.api.nvim_get_hl(0, { name = "ColorColumn" })
local old_cursorline = vim.api.nvim_get_hl(0, { name = "CursorLine" })
local new_cursorline = vim.tbl_extend("force", old_cursorline, { bg = color_col.bg })
vim.api.nvim_set_hl(0, "CursorLine", new_cursorline)

local old_stl_nc = vim.api.nvim_get_hl(0, { name = "StatusLineNC" })
local stl = vim.api.nvim_get_hl(0, { name = "StatusLine" })
local new_stl_nc = vim.tbl_extend("force", old_stl_nc, { fg = stl.fg })
vim.api.nvim_set_hl(0, "StatusLineNC", new_stl_nc)

local diag_text_groups = {
    ["DiagnosticError"] = "DiagnosticUnderlineError",
    ["DiagnosticWarn"] = "DiagnosticUnderlineWarn",
    ["DiagnosticInfo"] = "DiagnosticUnderlineInfo",
    ["DiagnosticHint"] = "DiagnosticUnderlineHint",
    ["DiagnosticOk"] = "DiagnosticUnderlineOk",
}

for base, uline in pairs(diag_text_groups) do
    local old = vim.api.nvim_get_hl(0, { name = uline })
    local new_fg = vim.api.nvim_get_hl(0, { name = base }).fg
    local new = vim.tbl_extend("force", old, { fg = new_fg, underline = true })

    vim.api.nvim_set_hl(0, uline, new)
end

-- Works with the Quickscope plugin. Good hl_groups in general
vim.api.nvim_set_hl(0, "QuickScopePrimary", {
    bg = vim.api.nvim_get_hl(0, { name = "Boolean" }).fg,
    fg = "#000000",
    ctermbg = 14,
    ctermfg = 0,
})

vim.api.nvim_set_hl(0, "QuickScopeSecondary", {
    bg = vim.api.nvim_get_hl(0, { name = "Keyword" }).fg,
    fg = "#000000",
    ctermbg = 207,
    ctermfg = 0,
})

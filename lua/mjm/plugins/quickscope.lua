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

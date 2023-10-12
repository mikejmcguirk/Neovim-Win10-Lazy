return {
    "unblevable/quick-scope",
    config = function()
        if Env_Theme == "blue" then
            vim.api.nvim_set_hl(0, "QuickScopePrimary",
                { bg = "#98FFFB", fg = "#000000", ctermbg = 14, ctermfg = 0 })
            vim.api.nvim_set_hl(0, "QuickScopeSecondary",
                { bg = "#EDFF98", fg = "#000000", ctermbg = 226, ctermfg = 0 })
        else
            vim.api.nvim_set_hl(0, "QuickScopePrimary",
                { bg = "#98FFFB", fg = "#000000", ctermbg = 14, ctermfg = 0 })
            vim.api.nvim_set_hl(0, "QuickScopeSecondary",
                { bg = "#FF67D4", fg = "#000000", ctermbg = 207, ctermfg = 0 })
        end
    end,
    init = function()
        vim.g.qs_highlight_on_keys = { "f", "F", "t", "T" }
        vim.g.qs_max_chars = 510
    end,
}

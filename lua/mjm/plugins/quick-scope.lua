return {
    "unblevable/quick-scope",
    init = function()
        vim.api.nvim_set_var("qs_highlight_on_keys", { "f", "F", "t", "T" })
        vim.api.nvim_set_var("qs_max_chars", 9999)
        vim.api.nvim_set_hl(0, "QuickScopePrimary", { reverse = true })
        vim.api.nvim_set_hl(0, "QuickScopeSecondary", { undercurl = true })
    end,
}

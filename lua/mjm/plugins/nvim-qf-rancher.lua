return {
    "mikejmcguirk/nvim-qf-rancher",
    -- dir = "~/Documents/nvim-plugin-dev/nvim-qf-rancher/",
    init = function()
        -- vim.api.nvim_set_var("qfr_create_loclist_autocmds", false) -- For debugging
        vim.api.nvim_set_var("qfr_debug_assertions", true)
        vim.api.nvim_set_var("qfr_preview_debounce", 50)
        vim.api.nvim_set_var("qfr_preview_show_title", false)

        -- TODO: Add qP/lP maps to resize list only

        vim.keymap.set("n", "[<M-q>", "<Plug>(qfr-qf-older)")
        vim.keymap.set("n", "]<M-q>", "<Plug>(qfr-qf-newer)")
        vim.keymap.set("n", "[<M-l>", "<Plug>(qfr-ll-older)")
        vim.keymap.set("n", "]<M-l>", "<Plug>(qfr-ll-newer)")
    end,
}

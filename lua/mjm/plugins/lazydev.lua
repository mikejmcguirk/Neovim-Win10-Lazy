-- NOTE: Cmp pulls this in as a source

return {
    -- "folke/lazydev.nvim",
    "Jari27/lazydev.nvim",
    ft = "lua",
    branch = "deprecate_client_notify",
    opts = {
        library = {
            -- Load luvit types when the `vim.uv` word is found
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        },
    },
}

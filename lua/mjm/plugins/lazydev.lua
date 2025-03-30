return {
    "folke/lazydev.nvim",
    -- No lazy load in recommended config
    ft = "lua",
    opts = {
        library = {
            -- Load luvit types when the `vim.uv` word is found
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        },
    },
}

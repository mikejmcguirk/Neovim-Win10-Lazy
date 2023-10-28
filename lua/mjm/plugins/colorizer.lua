return {
    'NvChad/nvim-colorizer.lua',
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        require("colorizer").setup {
            filetypes = { "*" },
            user_default_options = {
                RGB = false,
                RRGGBB = true,
                names = false,
                RRGGBBAA = false,
                AARRGGBB = false,
                rgb_fn = false,
                hsl_fn = false,
                css = false,
                css_fn = false,

                mode = "background",

                tailwind = false,

                sass = { enable = false, parsers = { "css" }, },
                virtualtext = "■",

                always_update = false
            },
            buftypes = {},
        }

        vim.keymap.set("n", "<leader>ot", "<cmd>ColorizerToggle<cr>")
        vim.keymap.set("n", "<leader>oa", "<cmd>ColorizerAttachToBuffer<cr>")
        vim.keymap.set("n", "<leader>od", "<cmd>ColorizerDetachFromBuffer<cr>")
        vim.keymap.set("n", "<leader>or", "<cmd>ColorizerReloadAllBuffers<cr>")
    end,
}

return {
    "NvChad/nvim-colorizer.lua",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        require("colorizer").setup({
            user_default_options = {
                names = false,
            },
        })

        vim.keymap.set("n", "<leader>ot", "<cmd>ColorizerToggle<cr>")
        vim.keymap.set("n", "<leader>oa", "<cmd>ColorizerAttachToBuffer<cr>")
        vim.keymap.set("n", "<leader>od", "<cmd>ColorizerDetachFromBuffer<cr>")
        vim.keymap.set("n", "<leader>or", "<cmd>ColorizerReloadAllBuffers<cr>")
    end,
}

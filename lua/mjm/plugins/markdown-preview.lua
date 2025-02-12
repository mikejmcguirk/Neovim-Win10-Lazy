return {
    "iamcco/markdown-preview.nvim",
    ft = "markdown",
    config = function()
        vim.fn["mkdp#util#install"]()

        vim.g.mkdp_theme = "light"

        vim.keymap.set("n", "<leader>me", "<cmd>MarkdownPreview<cr>")
        vim.keymap.set("n", "<leader>ms", "<cmd>MarkdownPreviewStop<cr>")
        vim.keymap.set("n", "<leader>mt", "<cmd>MarkdownPreviewToggle<cr>")
    end,
}

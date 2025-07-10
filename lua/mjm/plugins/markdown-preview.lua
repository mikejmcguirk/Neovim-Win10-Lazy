return {
    "iamcco/markdown-preview.nvim",
    ft = "markdown",
    config = function()
        vim.fn["mkdp#util#install"]()

        vim.keymap.set("n", "<leader>me", "<cmd>MarkdownPreview<cr>")
        vim.keymap.set("n", "<leader>ms", "<cmd>MarkdownPreviewStop<cr>")
        vim.keymap.set("n", "<leader>mm", "<cmd>MarkdownPreviewToggle<cr>")
    end,
}

local function setup_markdown_preview()
    vim.fn["mkdp#util#install"]()

    vim.keymap.set("n", "<leader>me", "<cmd>MarkdownPreview<cr>")
    vim.keymap.set("n", "<leader>ms", "<cmd>MarkdownPreviewStop<cr>")
    vim.keymap.set("n", "<leader>mm", "<cmd>MarkdownPreviewToggle<cr>")
end

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("setup-md-preview", { clear = true }),
    pattern = "markdown",
    once = true,
    callback = function()
        setup_markdown_preview()
    end,
})

return {
    'nvim-treesitter/playground',
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { 'nvim-treesitter' },
    config = function()
        vim.keymap.set("n", "<leader>it", "<cmd>TSPlaygroundToggle<cr>")
        vim.keymap.set("n", "<leader>ih", "<cmd>TSHighlightCapturesUnderCursor<cr>")
    end
}

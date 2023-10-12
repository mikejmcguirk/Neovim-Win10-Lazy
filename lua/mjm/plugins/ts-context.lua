return {
    'nvim-treesitter/nvim-treesitter-context',
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        require('treesitter-context').setup({
            separator = '-'
        })

        vim.keymap.set("n", "<leader>eo", "<cmd>TSContextToggle<cr>")
    end
}

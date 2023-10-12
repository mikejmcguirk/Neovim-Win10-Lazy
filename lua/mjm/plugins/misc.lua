return {
    {
        'christoomey/vim-tmux-navigator',
        lazy = false,
    },
    {
        'tpope/vim-fugitive',
    },
    {
        'numToStr/Comment.nvim',
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require('Comment').setup()
        end,
    },
    {
        'tpope/vim-surround',
        event = { "BufReadPre", "BufNewFile" }
    },
    {
        'windwp/nvim-autopairs',
        event = "InsertEnter",
        opts = ({}) -- Blank explicitly specified as per the repo
    },
}

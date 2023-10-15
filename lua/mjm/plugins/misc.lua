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
        config = function()
            require('nvim-autopairs').setup({
                check_ts = true,
                ts_config = {
                    lua = { 'string' }, -- it will not add pair on that treesitter node
                    javascript = { 'template_string' },
                    java = false,       -- don't check treesitter on java
                }
            })
        end,
    },
    {
        'windwp/nvim-ts-autotag',
        event = "BufReadPre",
    },
}

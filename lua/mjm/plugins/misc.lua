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
        "kylechui/nvim-surround",
        version = "*", -- Use for stability; omit to use `main` branch for the latest features
        event = "VeryLazy",
        config = function()
            require("nvim-surround").setup({})
        end
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
        event = { "BufReadPre", "BufNewFile" },
    },
}

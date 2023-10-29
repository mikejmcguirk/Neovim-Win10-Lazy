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
    {
        'github/copilot.vim',
        init = function()
            if Env_Disable_Copilot == "true" then
                vim.g.copilot_enabled = false
            elseif Env_Copilot_Node then
                vim.g.copilot_node_command = Env_Copilot_Node
            else
                print(
                    "NvimCopilotNode system variable not set. " ..
                    "Node 18.18.0 is the highest supported version. " ..
                    "Default Node path will be used if it exists"
                )
            end
        end,
    }
}

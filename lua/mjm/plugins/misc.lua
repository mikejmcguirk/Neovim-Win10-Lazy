return {
    {
        "christoomey/vim-tmux-navigator",
        lazy = false,
    },
    {
        "tpope/vim-fugitive",
    },
    {
        "Wansmer/treesj",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        config = function()
            local treesj = require("treesj")

            treesj.setup({})

            vim.keymap.set("n", "<leader>j", function()
                treesj.toggle({ split = { recursive = true } })
            end, Opts)
        end,
    },
    {
        "github/copilot.vim",
        event = { "BufReadPre", "BufNewFile" },
        init = function()
            if Env_Disable_Copilot == "true" then
                vim.g.copilot_enabled = false
            elseif Env_Copilot_Node then
                vim.g.copilot_node_command = Env_Copilot_Node
            else
                print(
                    "NvimCopilotNode system variable not set. "
                        .. "Node 18.18.0 is the highest supported version. "
                        .. "Default Node path will be used if it exists"
                )
            end
        end,
    },
    {
        "j-hui/fidget.nvim",
        tag = "legacy",
        event = "LspAttach",
        opts = {},
    },
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("lspconfig.ui.windows").default_options = {
                border = "single",
            }
        end,
    },
}

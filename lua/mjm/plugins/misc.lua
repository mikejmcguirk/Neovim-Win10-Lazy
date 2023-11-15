return {
    {
        "christoomey/vim-tmux-navigator",
        lazy = false,
    },
    {
        "tpope/vim-fugitive",
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("ibl").setup({
                indent = { char = "│" },
                scope = {
                    show_start = false,
                    show_end = false,
                    -- highlight = { "@Type" },
                },
                whitespace = { highlight = { "Normal" } },
                debounce = 200,
            })
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

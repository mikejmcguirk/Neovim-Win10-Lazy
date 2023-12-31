return {
    {
        "christoomey/vim-tmux-navigator",
        lazy = false,
    },
    {
        "github/copilot.vim",
        event = { "BufReadPre", "BufNewFile" },
        init = function()
            if Env_Disable_Copilot == "true" then
                vim.g.copilot_enabled = false
            elseif Env_Copilot_Node then
                vim.g.copilot_node_command = Env_Copilot_Node
                vim.g.copilot_no_tab_map = true
                -- vim.g.copilot_assume_mapped = true

                vim.keymap.set("i", "<C-l>", 'copilot#Accept("")', {
                    expr = true,
                    replace_keycodes = false,
                })
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

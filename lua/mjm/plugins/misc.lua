return {
    {
        "christoomey/vim-tmux-navigator",
        lazy = false,
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

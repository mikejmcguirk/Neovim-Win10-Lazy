return {
    {
        "j-hui/fidget.nvim",
        tag = "legacy",
        event = "LspAttach",
        opts = {},
    },
    {
        -- TODO: Obvious candidate to move to internal package manager
        "neovim/nvim-lspconfig",
        lazy = false,
    },
}

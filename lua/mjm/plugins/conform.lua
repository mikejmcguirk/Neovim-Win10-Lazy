return {
    {
        "stevearc/conform.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    json = { "prettier" }, -- TODO: Should be prettierd
                    lua = { "stylua" },
                    markdown = { "prettier" }, -- TODO: Should be prettierd
                    python = { "ruff_format", "isort" },
                    rust = { "rustfmt" },
                    sh = { "beautysh" },
                    toml = { "taplo" },
                },
            })
        end,
    },
}

return {
    {
        "stevearc/conform.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    lua = { "stylua" },
                    markdown = { "prettier" },
                    python = { "ruff_format", "isort" },
                    sh = { "beautysh" },
                    toml = { "taplo" },
                    rust = { "rustfmt" },
                    -- TODO: This should be prettierd
                    json = { "prettier" },
                },
            })
        end,
    },
}

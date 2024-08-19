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
                },
            })
        end,
    },
}

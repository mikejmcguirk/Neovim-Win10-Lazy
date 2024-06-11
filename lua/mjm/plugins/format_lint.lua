return {
    {
        "stevearc/conform.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    cs = { "csharpier" },
                    css = { "prettier" },
                    html = { "prettier" },
                    javascript = { "eslint_d", "prettier" },
                    json = { "prettier" },
                    lua = { "stylua" },
                    markdown = { "prettier" },
                    python = { "ruff_format", "isort" },
                    rust = { "rustfmt" },
                    sh = { "beautysh" },
                    toml = { "taplo" },
                    typescript = { "prettier" },
                },
            })
        end,
    },
    {
        "mfussenegger/nvim-lint",
        event = { "BufWritePre", "BufNewFile" },
        config = function()
            local lint = require("lint")
            lint.linters_by_ft = {
                markdown = { "markdownlint" },
            }

            vim.api.nvim_create_autocmd("BufWritePost", {
                group = vim.api.nvim_create_augroup("lint_group", { clear = true }),
                pattern = "*",
                callback = function()
                    lint.try_lint()
                end,
            })
        end,
    },
}

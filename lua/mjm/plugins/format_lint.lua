return {
    {
        "stevearc/conform.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    cs = { "csharpier" },
                    javascript = { "eslint_d", "prettierd" },
                    typescript = { "prettierd" },
                    markdown = { "prettierd" },
                    css = { "prettierd" },
                    html = { "prettierd" },
                    json = { "prettierd" },
                    sh = { "beautysh" },
                    lua = { "stylua" },
                    python = { "ruff_format", "isort" },
                    rust = { "rustfmt" },
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

return {
    {
        "stevearc/conform.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            local conform = require("conform")

            conform.setup({
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
                },
                format_on_save = {
                    lsp_fallback = false,
                    async = false,
                    timeout_ms = 5000,
                },
            })
        end,
    },
    {
        "rust-lang/rust.vim",
        ft = "rust",
        init = function()
            vim.g.rustfmt_autosave = 0
            vim.g.rustfmt_fail_silently = 1
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

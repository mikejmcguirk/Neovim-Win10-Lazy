return {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        local conform = require("conform")

        conform.setup({
            formatters_by_ft = {
                javascript = { "prettier" },
                typescript = { "prettier" },
                markdown = { "prettier" },
                css = { "prettier" },
                html = { "prettier" },
                json = { "prettier" },
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
}

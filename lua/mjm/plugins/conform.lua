return {
    {
        "stevearc/conform.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    json = { "prettier" }, -- TODO: Should be prettierd
                    lua = { "stylua" },
                    -- Markdown formatting does too many unpredictable things
                    -- Maybe at some point in the future it can come back
                    -- markdown = { "prettier" }, -- TODO: Should be prettierd
                    python = { "ruff_format" },
                    rust = { "rustfmt" },
                    sh = { "beautysh" },
                    toml = { "taplo" },
                },
            })
        end,
    },
}

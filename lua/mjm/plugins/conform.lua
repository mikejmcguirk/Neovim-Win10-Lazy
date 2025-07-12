return {
    {
        -- FUTURE: Figure out a way, in a Dadbod buffer, to determine what type of SQL server
        -- we're connected to and then run the appropriate formatter over it
        "stevearc/conform.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    css = { "prettier" },
                    go = { "gofumpt" },
                    html = { "prettier" },
                    json = { "prettier" },
                    lua = { "stylua" },
                    python = { "ruff_format" },
                    rust = { "rustfmt" },
                    sh = { "shfmt" },
                    toml = { "taplo" },
                },
            })

            local valid_filetypes = {
                "css",
                "go",
                "html",
                "json",
                "lua",
                "python",
                "rust",
                "sh",
                "toml",
            }

            vim.api.nvim_create_autocmd("BufWritePre", {
                group = vim.api.nvim_create_augroup("conformer", { clear = true }),
                pattern = "*",
                callback = function(ev)
                    if not vim.tbl_contains(valid_filetypes, vim.bo[ev.buf].filetype) then
                        return
                    end

                    require("conform").format({
                        bufnr = ev.buf,
                        lsp_fallback = false,
                        async = false,
                        timeout_ms = 1000,
                    })
                end,
            })
        end,
    },
}

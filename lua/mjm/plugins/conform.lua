return {
    {
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
                    -- Markdown formatting does too many unpredictable things
                    -- Maybe at some point in the future it can come back
                    -- markdown = { "prettier" },
                    python = { "ruff_format" },
                    rust = { "rustfmt" },
                    sh = { "shfmt" },
                    -- sh = { "beautysh" },
                    toml = { "taplo" },
                    -- TODO: This is tough to swing with dadbod-ui because it stores queries in
                    -- tmp or a local dir. You could edit the g variables or something but iunno
                    -- sql = { "sqlfluff" },
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

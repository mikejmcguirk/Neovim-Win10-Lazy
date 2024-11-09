return {
    {
        "j-hui/fidget.nvim",
        tag = "legacy",
        event = "LspAttach",
        opts = {},
    },
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("lspconfig.ui.windows").default_options = {
                border = "single",
            }

            local lspconfig = require("lspconfig")
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            local cmp_capabilities = vim.tbl_deep_extend(
                "force",
                capabilities,
                require("cmp_nvim_lsp").default_capabilities()
            )

            -- Bash
            lspconfig.bashls.setup({ capabilities = cmp_capabilities })

            -- Lua
            lspconfig.lua_ls.setup({ capabilities = cmp_capabilities })

            -- Markdown
            lspconfig.marksman.setup({ capabilities = cmp_capabilities })

            -- Python
            lspconfig.pylsp.setup({
                capabilities = cmp_capabilities,
                settings = {
                    pylsp = {
                        plugins = {
                            pycodestyle = {
                                maxLineLength = 99,
                                ignore = {
                                    "E201",
                                    "E202",
                                    "E203", -- Whitespace before ':' (Contradicts ruff formatter)
                                    "E211",
                                    "E226", -- Missing whitespace around arithmetic operator
                                    "E261",
                                    "E262",
                                    "E265",
                                    "E302",
                                    "E303",
                                    "E305",
                                    "E501",
                                    "E741", -- Ambiguous variable name
                                    "W293",
                                    "W391",
                                },
                            },
                        },
                    },
                },
            })
            lspconfig.ruff.setup({ capabilities = cmp_capabilities })

            -- Toml
            lspconfig.taplo.setup({ capabilities = cmp_capabilities })

            -- Rust
            lspconfig.rust_analyzer.setup({
                capabilities = cmp_capabilities,
                settings = {
                    ["rust-analyzer"] = {
                        checkOnSave = {
                            command = "clippy",
                        },
                    },
                },
            })
        end,
    },
}

return {
    "neovim/nvim-lspconfig",
    event = "BufReadPre",
    config = function()

        ---------
        -- cmp --
        ---------

        local cmp = require("cmp")
        local cmp_select = {behavior = cmp.SelectBehavior.Select}
        local lspkind = require("lspkind")

        local winHighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None"

        cmp.setup({
            enabled = function()
                local context = require "cmp.config.context"

                if vim.api.nvim_get_mode().mode == "c" then
                    return true
                elseif vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
                    return false
                else
                    return not context.in_treesitter_capture("comment")
                        and not context.in_syntax_group("Comment")
                end
            end,
            snippet = {
                expand = function(args)
                    vim.fn["vsnip#anonymous"](args.body)
                end,
            },
            window = {
                completion = {
                    border = "single",
                    winhighlight = winHighlight,
                },
                documentation = {
                    border = "single",
                    winhighlight = winHighlight
                }
            },
            mapping = cmp.mapping.preset.insert({
                ["<C-d>"] = cmp.mapping.scroll_docs(4),
                ["<C-u>"] = cmp.mapping.scroll_docs(-4),

                ["<C-e>"] = cmp.mapping {
                    i = cmp.mapping.abort(),
                    c = cmp.mapping.close(),
                },

                ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
                ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
                ["<C-y>"] = cmp.mapping.confirm({select = true}),
                ["<C-Space>"] = cmp.mapping.complete(),

                ["<Tab>"] = nil,
                ["<S-Tab>"] = nil,
                ["<CR>"] = nil,
            }),
            sources = cmp.config.sources({
                {name = "nvim_lsp"},
                {name = "vsnip"},
                {
                    name = "buffer",
                    option = {
                        get_bufnrs = function()
                            return vim.api.nvim_list_bufs()
                        end
                    }
                },
                {
                    name = "async_path",
                    option = {
                        trailing_slash = true,
                        label_trailing_slash = true,
                    },
                },
                {name = "nvim_lsp_signature_help"},
            }),
            formatting = {
                format = lspkind.cmp_format({
                    mode = "text",
                    menu = {
                        buffer = "[Buffer]",
                        nvim_lsp = "[LSP]",
                        vsnip = "[Vsnip]",
                        path = "[Path]",
                    },
                }),
                fields = {"abbr", "kind", "menu"}
            }

        })

        local cmp_autopairs = require("nvim-autopairs.completion.cmp")
        cmp.event:on(
            "confirm_done",
            cmp_autopairs.on_confirm_done()
        )

        -----------------
        -- Diagnostics --
        -----------------

        vim.diagnostic.config({
            update_in_insert = false,
            float = {
                border = "single",
                style = "minimal"
            }
        })

        ---------
        -- LSP --
        ---------

        vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
            vim.lsp.handlers.hover, {
                border = "single",
                style = "minimal"
            }
        )

        local capabilities = require("cmp_nvim_lsp").default_capabilities()
        local lspconfig = require("lspconfig")

        lspconfig.taplo.setup({
            capabilities = capabilities,
        })

        lspconfig.rust_analyzer.setup ({
            capabilities = capabilities,

            settings = {
                ["rust-analyzer"] = {
                    cargo = {
                        features = "all",
                    },
                    checkOnSave = {
                        command = "clippy"
                    },
                }
            }
        })

        lspconfig.tsserver.setup({
            capabilities = capabilities,
        })

        lspconfig.eslint.setup({
            capabilities = capabilities,

            on_attach = function(client, bufnr)
                vim.api.nvim_create_autocmd("BufWritePre", {
                    buffer = bufnr,
                    callback = function()
                        vim.cmd([[EslintFixAll]]) -- This will run before :ALEFix
                    end
                })
            end,
        })

        require"lspconfig".pylsp.setup({
            capabilities = capabilities,

            settings = {
                pylsp = {
                    plugins = {
                        pycodestyle = {
                            maxLineLength = 99,
                            ignore = {
                                "E302",
                                "E305"
                            }
                        }
                    }
                }
            }
        })

        lspconfig.omnisharp.setup ({
            capabilities = capabilities,

            cmd = {"dotnet", "C:\\omnisharp-win-x64\\omnisharp.dll"},

            handlers = {
                ["textDocument/definition"] = require("omnisharp_extended").handler,
            },

            enable_editorconfig_support = true,

            -- If true, MSBuild project system will only load projects for files that
            -- were opened in the editor. This setting is useful for big C# codebases
            -- and allows for faster initialization of code navigation features only
            -- for projects that are relevant to code that is being edited. With this
            -- setting enabled OmniSharp may load fewer projects and may thus display
            -- incomplete reference lists for symbols.
            enable_ms_build_load_projects_on_demand = false,

            -- Enables support for roslyn analyzers, code fixes and rulesets.
            enable_roslyn_analyzers = false,

            organize_imports_on_format = true,

            -- Enables support for showing unimported types and unimported extension
            -- methods in completion lists. When committed, the appropriate using
            -- directive will be added at the top of the current file. This option can
            -- have a negative impact on initial completion responsiveness,
            -- particularly for the first few completion sessions after opening a
            -- solution.
            enable_import_completion = false,

            -- Specifies whether to include preview versions of the .NET SDK when
            -- determining which version to use for project loading.
            sdk_include_prereleases = true,

            analyze_open_documents_only = false,
        })

        lspconfig.lua_ls.setup ({
            capabilities = capabilities,

            settings = {
                Lua = {
                    workspace = {
                        -- This imports Neovim"s runtime files for use in the LSP,
                        -- suppressing the "Undefined global" warning for "vim"
                        -- But this also makes the LSP think the runtime is available
                        -- in any other project
                        library = vim.api.nvim_get_runtime_file("", true),
                        checkThirdParty = false
                    },
                    telemetry = {
                        enable = false,
                    },
                },
            },
        })

    end,
    dependencies = {
        "Hoffs/omnisharp-extended-lsp.nvim",

        "hrsh7th/nvim-cmp", -- Main CMP Plugin
        "hrsh7th/vim-vsnip", -- Snippets engine

        "hrsh7th/cmp-vsnip", -- From vsnip
        "hrsh7th/cmp-nvim-lsp", -- From LSPs

        "hrsh7th/cmp-buffer", -- From the buffer
        "FelipeLema/cmp-async-path", -- From the path's files
        -- Show function signatures with emphasis on current parameter
        "hrsh7th/cmp-nvim-lsp-signature-help",

        "onsails/lspkind.nvim", -- To configure appearance

        'github/copilot.vim', -- Uses LSP
    },
}

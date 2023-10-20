local cmp_config = function()
    local cmp = require("cmp")
    local lspkind = require("lspkind")

    local cmp_select = { behavior = cmp.SelectBehavior.Select }
    local win_highlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None"
    vim.opt.completeopt = { "menu", "menuone", "noselect" }

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
                winhighlight = win_highlight,
            },
            documentation = {
                border = "single",
                winhighlight = win_highlight
            }
        },
        mapping = cmp.mapping.preset.insert({
            ["<C-d>"] = cmp.mapping.scroll_docs(4),
            ["<C-u>"] = cmp.mapping.scroll_docs(-4),

            ["<C-e>"] = cmp.mapping.abort(),
            ["<C-c>"] = function()
                cmp.mapping.abort()
                vim.cmd("stopinsert")
            end,

            ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
            ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
            ["<C-y>"] = cmp.mapping.confirm({ select = true }),
            -- ["<C-<space>>"] = cmp.mapping.complete(),

            ["<Tab>"] = nil,
            ["<S-Tab>"] = nil,
            ["<CR>"] = nil,
        }),
        sources = {
            { name = "nvim_lsp" },
            { name = "vsnip" },
            {
                name = "buffer",
                option = {
                    get_bufnrs = function()
                        return vim.api.nvim_list_bufs()
                    end
                }
            },
            { name = "async_path" },
            { name = "nvim_lsp_signature_help" },
            {
                name = "spell",
                option = {
                    keep_all_entries = false,
                    enable_in_context = function()
                        return true
                    end,
                },
            },
        },
        formatting = {
            format = lspkind.cmp_format({
                mode = "text",
                menu = {
                    buffer = "[Buffer]",
                    nvim_lsp = "[LSP]",
                    vsnip = "[Vsnip]",
                    async_path = "[Path]",
                    spell = "[Spell]",
                },
            }),
            fields = { "abbr", "kind", "menu" }
        }
    })

    local cmp_autopairs = require("nvim-autopairs.completion.cmp")
    cmp.event:on(
        "confirm_done",
        cmp_autopairs.on_confirm_done()
    )
end

local diagnosticConfig = function()
    vim.diagnostic.config({
        update_in_insert = false,
        float = {
            border = "single",
            style = "minimal"
        }
    })

    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
    vim.keymap.set("n", "<leader>vl", vim.diagnostic.open_float)
end

local lspConfig = function()
    vim.lsp.set_log_level("ERROR")

    -- LSP windows use floating windows, documented in nvim_open_win
    -- The borders use the "FloatBorder" highlight group

    vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
        vim.lsp.handlers.hover, {
            border = "single",
            style = "minimal"
        }
    )

    vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
        vim.lsp.handlers.signature_help, {
            border = "single",
            style = "minimal"
        }
    )

    require("lspconfig.ui.windows").default_options = {
        border = "single",
    }

    local setLSPkeymaps = function()
        vim.keymap.set("n", "gd", vim.lsp.buf.definition)
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration)
        vim.keymap.set("n", "gI", vim.lsp.buf.implementation)
        vim.keymap.set("n", "gr", vim.lsp.buf.references)
        vim.keymap.set("n", "gT", vim.lsp.buf.type_definition)

        vim.keymap.set("n", "K", vim.lsp.buf.hover)
        vim.keymap.set("n", "<C-e>", vim.lsp.buf.signature_help)

        vim.keymap.set("n", "<leader>va", vim.lsp.buf.add_workspace_folder)
        vim.keymap.set("n", "<leader>vd", vim.lsp.buf.remove_workspace_folder)

        -- For reference only
        -- vim.keymap.set("n", "<leader>vf", function()
        --     print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        -- end)

        -- For reference only. Can find these in Telescope
        -- vim.keymap.set("n", "<leader>vs", vim.lsp.buf.workspace_symbol())

        vim.keymap.set("n", "<leader>vr", vim.lsp.buf.rename)

        vim.keymap.set("n", "<leader>vc", vim.lsp.buf.code_action)
    end

    local defaultAttach = function(bufnr)
        vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            callback = function()
                vim.lsp.buf.format({ async = false })
            end
        })

        setLSPkeymaps()
    end

    local capabilities = require("cmp_nvim_lsp").default_capabilities()
    local lspconfig = require("lspconfig")

    -- No additional linter installed
    lspconfig.taplo.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            defaultAttach(bufnr)
        end,
    })

    -- Formatting is handled with the built-in RustFmt function + rust.vim plugin
    lspconfig.rust_analyzer.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            setLSPkeymaps()
        end,

        settings = {
            ["rust-analyzer"] = {
                cargo = {
                    features = "all",
                },
                checkOnSave = {
                    command = "clippy" --linting
                },
            }
        }
    })

    -- Linting is handled below using the ESLint LSP
    -- Formatting handled with Prettier through conform.nvim
    lspconfig.tsserver.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            setLSPkeymaps()
        end,
    })

    lspconfig.eslint.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            vim.api.nvim_create_autocmd("BufWritePre", {
                buffer = bufnr,
                callback = function()
                    vim.cmd([[EslintFixAll]])
                end
            })
        end,
    })

    -- No separate linter installed
    lspconfig.dockerls.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            defaultAttach(bufnr)
        end,
    })

    -- No separate linter installed. Formatting handled with Prettier through conform.nvim
    lspconfig.marksman.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            setLSPkeymaps()
        end,
    })

    -- No specific formatter or linter configured at this time
    require "lspconfig".pylsp.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            defaultAttach(bufnr)
        end,

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

    if not Env_OmniSharp_DLL then
        print("Warning: " .. Env_OmniSharp_DLL_Name .. " environment variable not found. " ..
            "Cannot attach OmniSharp")
        Env_OmniSharp_DLL = " "
    end

    -- No additional linter installed
    lspconfig.omnisharp.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            defaultAttach(bufnr)
        end,

        cmd = { "dotnet", Env_OmniSharp_DLL },

        handlers = {
            ["textDocument/definition"] = require("omnisharp_extended").handler,
        },

        enable_editorconfig_support = true,

        -- If true, MSBuild project system will only load projects for files that
        -- were opened in the editor. This setting is useful for big C# code bases
        -- and allows for faster initialization of code navigation features only
        -- for projects that are relevant to code that is being edited. With this
        -- setting enabled OmniSharp may load fewer projects and may thus display
        -- incomplete reference lists for symbols.
        enable_ms_build_load_projects_on_demand = false,

        -- Enables support for Roslyn analyzers, code fixes and rule sets.
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

    -- Use beautysh/conform.nvim for formatting
    -- ShellCheck used for linting
    lspconfig.bashls.setup {
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            setLSPkeymaps()
        end,
    }

    -- Use Prettier/conform.nvim for formatting. No linter
    lspconfig.html.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            setLSPkeymaps()
        end,

        init_options = {
            provideFormatter = false
        }
    })

    -- Use Prettier/conform.nvim for formatting. No linter
    lspconfig.cssls.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            setLSPkeymaps()
        end,
    })

    -- No additional linter installed
    lspconfig.lua_ls.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            defaultAttach(bufnr)
        end,

        on_init = function(client)
            local path = client.workspace_folders[1].name
            if not vim.loop.fs_stat(path .. '/.luarc.json')
                and not vim.loop.fs_stat(path .. '/.luarc.jsonc') then
                client.config.settings = vim.tbl_deep_extend('force', client.config.settings, {
                    Lua = {
                        runtime = {
                            version = 'LuaJIT' -- Most likely for Neovim
                        },
                        workspace = {
                            checkThirdParty = false,
                            library = vim.api.nvim_get_runtime_file("", true)
                        },
                        settings = {
                            Lua = {
                                telemetry = {
                                    enable = false,
                                },
                            },
                        },
                    }
                })

                client.notify(
                    "workspace/didChangeConfiguration",
                    { settings = client.config.settings }
                )
            else
                client.config.settings = vim.tbl_deep_extend('force', client.config.settings, {
                    settings = {
                        Lua = {
                            telemetry = {
                                enable = false,
                            },
                        }
                    }
                })
            end
            return true
        end,

    })
end

return {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        cmp_config()
        diagnosticConfig()
        lspConfig()
    end,
    dependencies = {
        "Hoffs/omnisharp-extended-lsp.nvim",

        "hrsh7th/nvim-cmp",                    -- Main cmp Plugin
        "hrsh7th/vim-vsnip",                   -- Snippets engine
        "rafamadriz/friendly-snippets",        -- Snippets

        "hrsh7th/cmp-vsnip",                   -- From vsnip
        "hrsh7th/cmp-nvim-lsp",                -- From LSPs

        "hrsh7th/cmp-buffer",                  -- From open buffers
        "hrsh7th/cmp-nvim-lsp-signature-help", -- Show current function signature
        "f3fora/cmp-spell",                    -- From Nvim's built-in spell check
        "FelipeLema/cmp-async-path",           -- From filesystem

        "onsails/lspkind.nvim",                -- To configure appearance

        'github/copilot.vim',                  -- Uses LSP
    },
    init = function()
        if Env_Disable_Copilot == "true" then
            vim.g.copilot_enabled = false
        elseif Env_Copilot_Node then
            vim.g.copilot_node_command = Env_Copilot_Node
        else
            print(
                "NvimCopilotNode system variable not set. " ..
                "Node 16.15.0 is the highest supported version. " ..
                "Default Node path will be used if it exists"
            )
        end
    end,
}

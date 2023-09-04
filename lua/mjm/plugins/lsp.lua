local loudOpts = { noremap = true, silent = false }

local cmpConfig = function()
    local cmp = require("cmp")
    local lspkind = require("lspkind")

    local winHighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None"
    local cmp_select = { behavior = cmp.SelectBehavior.Select }

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
            ["<C-y>"] = cmp.mapping.confirm({ select = true }),
            ["<C-Space>"] = cmp.mapping.complete(),

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
            { name = "nvim_lsp_signature_help" },
            {
                name = 'spell',
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

    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, loudOpts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, loudOpts)
    vim.keymap.set("n", "<leader>vl", vim.diagnostic.open_float, loudOpts)
    -- Listed for reference only
    -- vim.keymap.set("n", "<leader>vq", vim.diagnostic.setloclist, loudOpts)
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
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, loudOpts)
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, loudOpts)
        vim.keymap.set("n", "gI", vim.lsp.buf.implementation, loudOpts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, loudOpts)
        vim.keymap.set("n", "gT", vim.lsp.buf.type_definition, loudOpts)

        vim.keymap.set("n", "K", vim.lsp.buf.hover, loudOpts)
        vim.keymap.set("n", "<C-e>", vim.lsp.buf.signature_help, loudOpts)

        vim.keymap.set("n", "<leader>va", vim.lsp.buf.add_workspace_folder, loudOpts)
        vim.keymap.set("n", "<leader>vd", vim.lsp.buf.remove_workspace_folder, loudOpts)

        -- For reference only
        -- vim.keymap.set("n", "<leader>vf", function()
        --     print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        -- end, loudOpts)

        -- For reference only. Can find these in Telescope
        -- vim.keymap.set("n", "<leader>vs", vim.lsp.buf.workspace_symbol(), loudOpts)

        vim.keymap.set("n", "<leader>vr", vim.lsp.buf.rename, loudOpts)

        vim.keymap.set("n", "<leader>vc", vim.lsp.buf.code_action, loudOpts)

        vim.keymap.set("n", "<leader>vo", function()
            vim.lsp.buf.format { async = true }
        end, loudOpts)
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
    -- Formatting is handled through prettier using ALE
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
                    vim.cmd([[EslintFixAll]]) -- This will run before :ALEFix

                    setLSPkeymaps()
                end
            })
        end,
    })

    -- No separate linter installed. Formatting is done using prettier through ALE
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

    local omniSharpDLLenvName = "OmniSharpDLL"
    local omniSharpDLL = os.getenv(omniSharpDLLenvName)

    if not os.getenv(omniSharpDLLenvName) then
        print("Warning: " .. omniSharpDLLenvName .. " environment variable not found. " ..
            "Cannot attach OmniSharp")
        omniSharpDLL = " "
    end

    lspconfig.omnisharp.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            defaultAttach(bufnr)
        end,

        cmd = { "dotnet", omniSharpDLL },

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

    -- No additional linter installed
    lspconfig.lua_ls.setup({
        capabilities = capabilities,

        on_attach = function(client, bufnr)
            defaultAttach(bufnr)
        end,

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
end

return {
    "neovim/nvim-lspconfig",
    event = "BufReadPre",
    config = function()
        cmpConfig()
        diagnosticConfig()
        lspConfig()
    end,
    dependencies = {
        "Hoffs/omnisharp-extended-lsp.nvim",

        "hrsh7th/nvim-cmp",                    -- Main cmp Plugin
        "hrsh7th/vim-vsnip",                   -- Snippets engine

        "hrsh7th/cmp-vsnip",                   -- From vsnip
        "hrsh7th/cmp-nvim-lsp",                -- From LSPs

        "hrsh7th/cmp-buffer",                  -- From open buffers
        "hrsh7th/cmp-nvim-lsp-signature-help", -- Show current function signature
        "f3fora/cmp-spell",                    -- From Nvim's built-in spell check

        "onsails/lspkind.nvim",                -- To configure appearance

        'github/copilot.vim',                  -- Uses LSP
    },
}

-- LOW: Weird issue where workspace update is triggered due to FzfLua require, and Semantic
-- Tokens do not consistently refresh afterwards

local ut = require("mjm.utils")

vim.lsp.log.set_level(vim.log.levels.ERROR)

-- By default, mapped in non-LSP buffers and without checking for LSP method support
vim.keymap.del("n", "grn")
vim.keymap.del("n", "gra")
vim.keymap.del("n", "grr")
vim.keymap.del("n", "gri")
vim.keymap.del("n", "grt")
vim.keymap.del("n", "gO")
vim.keymap.del("i", "<C-S>")

local lsp_group = vim.api.nvim_create_augroup("LSP_Augroup", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = function(ev)
        local buf = ev.buf ---@type integer
        local client = assert(vim.lsp.get_client_by_id(ev.data.client_id)) ---@type vim.lsp.Client
        local methods = vim.lsp.protocol.Methods ---@type table
        local ok, fzf_lua = pcall(require, "fzf-lua")

        -------------------------
        -- Overwrite vim defaults
        -------------------------

        vim.keymap.set("n", "gr", "<nop>", { buffer = buf })

        if client:supports_method(methods.textDocument_definition) then
            if ok then
                vim.keymap.set("n", "gd", fzf_lua.lsp_definitions, { buffer = buf })
            else
                vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = buf })
            end
        end

        if client:supports_method(methods.textDocument_declaration) then
            if ok then
                vim.keymap.set("n", "gD", fzf_lua.lsp_declarations, { buffer = buf })
            else
                vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = buf })
            end
        end

        ------------------------------------------------------
        -- Recreate/replace Nvim defaults (:help lsp-defaults)
        ------------------------------------------------------

        if client:supports_method(methods.textDocument_rename) then
            vim.keymap.set("n", "grn", function()
                local input = ut.get_input("Rename: ")
                if string.find(input, "%s") then
                    vim.notify(string.format("'%s' contains spaces", input))
                elseif #input > 0 then
                    vim.lsp.buf.rename(input)
                end
            end, { buffer = buf })
        end

        if client:supports_method(methods.textDocument_implementation) then
            if ok then
                vim.keymap.set("n", "gI", fzf_lua.lsp_implementations, { buffer = buf })
            else
                vim.keymap.set("n", "gI", vim.lsp.buf.implementation, { buffer = buf })
            end
        end

        if client:supports_method(methods.textDocument_codeAction) then
            vim.keymap.set("n", "gra", vim.lsp.buf.code_action, { buffer = buf })
        end

        if client:supports_method(methods.textDocument_references) then
            if ok then
                vim.keymap.set("n", "grr", function()
                    fzf_lua.lsp_references({ includeDeclaration = false })
                end, { buffer = buf })
            else
                vim.keymap.set("n", "grr", function()
                    vim.lsp.buf.references({ includeDeclaration = false })
                end, { buffer = buf })
            end
        end

        if client:supports_method(methods.textDocument_hover) then
            vim.keymap.set("n", "K", function()
                vim.lsp.buf.hover({ border = Border })
            end, { buffer = buf })
        end

        if client:supports_method(methods.textDocument_signatureHelp) then
            vim.keymap.set({ "i", "s" }, "<C-S>", function()
                vim.lsp.buf.signature_help({ border = Border })
            end, { buffer = buf })
        end

        if client:supports_method(methods.textDocument_typeDefinition) then
            if ok then
                vim.keymap.set("n", "grt", fzf_lua.lsp_typedefs, { buffer = buf })
            else
                vim.keymap.set("n", "grt", vim.lsp.buf.type_definition, { buffer = buf })
            end
        end

        if client:supports_method(methods.textDocument_documentSymbol) then
            if ok then
                vim.keymap.set("n", "gO", fzf_lua.lsp_document_symbols, { buffer = buf })
            else
                vim.keymap.set("n", "gO", vim.lsp.buf.document_symbol, { buffer = buf })
            end
        end

        --------
        -- Other
        --------

        -- Kickstart mapping
        if client:supports_method(methods.workspace_symbol) then
            if ok then
                vim.keymap.set("n", "gW", fzf_lua.lsp_live_workspace_symbols, { buffer = buf })
            else
                vim.keymap.set("n", "gW", vim.lsp.buf.workspace_symbol, { buffer = buf })
            end
        end

        -- Patternful with the rest of the defaults
        if client:supports_method(methods.textDocument_documentHighlight) then
            vim.keymap.set("n", "grh", vim.lsp.buf.document_highlight, { buffer = buf })
        end

        if client:supports_method(methods.textDocument_inlayHint) then
            vim.keymap.set("n", "grl", function()
                vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ buffer = buf }))
            end)
        end

        if client:supports_method(methods.textDocument_documentColor) then
            -- Maria Solano map (kinda)
            vim.keymap.set("n", "grc", function()
                -- vim.lsp.document_color.color_presentation()
                vim.lsp.document_color.enable(not vim.lsp.document_color.is_enabled())
            end, { buffer = buf })
        end

        vim.keymap.set("n", "grf", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, { buffer = buf })

        vim.keymap.set("n", "grm", function()
            vim.lsp.semantic_tokens.enable(not vim.lsp.semantic_tokens.is_enabled())
        end, { buffer = buf })
    end,
})

local bad_token_types = {
    ["lua_ls"] = { "comment", "function", "method", "property" },
    ["rust_analyzer"] = { "comment", "const", "keyword", "selfKeyword", "property" },
}

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("token-filter", { clear = true }),
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client or not client.server_capabilities.semanticTokensProvider then
            return
        end

        local found_client_name = false
        for k, _ in pairs(bad_token_types) do
            if k == client.name then
                found_client_name = true
                break
            end
        end

        if not found_client_name then
            return
        end

        local legend = client.server_capabilities.semanticTokensProvider.legend
        local new_tokenTypes = {}

        for _, typ in ipairs(legend.tokenTypes) do
            if not vim.tbl_contains(bad_token_types[client.name], typ) then
                table.insert(new_tokenTypes, typ)
            else
                table.insert(new_tokenTypes, false)
            end
        end

        legend.tokenTypes = new_tokenTypes
        vim.lsp.semantic_tokens.force_refresh(ev.buf)
    end,
})

vim.api.nvim_create_autocmd("BufUnload", {
    group = lsp_group,
    callback = function(ev)
        local bufnr = ev.buf ---@type integer
        local clients = vim.lsp.get_clients({ bufnr = bufnr }) ---@type vim.lsp.Client[]
        if not clients or vim.tbl_isempty(clients) then
            return
        end

        for _, client in pairs(clients) do
            local attached_buffers = vim.tbl_filter(function(buf_nbr)
                return buf_nbr ~= bufnr
            end, vim.tbl_keys(client.attached_buffers)) ---@type unknown[]

            if vim.tbl_isempty(attached_buffers) then
                vim.lsp.stop_client(client.id)
            end
        end
    end,
})

vim.lsp.enable("bashls")
vim.lsp.enable("lua_ls")
vim.lsp.enable("taplo")

-- FUTURE: Figure out why code lens isn't working
vim.lsp.config("rust_analyzer", {
    settings = {
        ["rust-analyzer"] = {
            checkOnSave = true,
            check = {
                command = "clippy",
            },
            -- lens = {
            --     enable = true,
            --     run = { enable = true },
            --     debug = { enable = true },
            --     implementations = { enable = true },
            --     references = { enable = true },
            -- },
        },
    },
})

vim.lsp.enable("rust_analyzer")

vim.lsp.enable("gopls")
vim.lsp.enable("golangci_lint_ls")

vim.lsp.enable("html")
vim.lsp.enable("cssls")

vim.lsp.enable("ruff")
-- Ruff is not feature-complete enough to replace pylsp
vim.lsp.config("pylsp", {
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
                        "E225", -- Missing whitespace around operator
                        "E226", -- Missing whitespace around arithmetic operator
                        "E231", -- Missing whitespace after ,
                        "E261",
                        "E262",
                        "E265",
                        "E302",
                        "E303",
                        "E305",
                        "E501",
                        "E741", -- Ambiguous variable name
                        "W291", -- Trailing whitespace
                        "W292", -- No newline at end of file
                        "W293",
                        "W391",
                        "W503", -- Line break after binary operator
                    },
                },
            },
        },
    },
})

vim.lsp.enable("pylsp")

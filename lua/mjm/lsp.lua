-- Note: Not using the built-in LSP autocompletion because it doesn't bring in other sources

vim.lsp.set_log_level("ERROR")
local ut = require("mjm.utils")

-- By default, mapped in non-LSP buffers without checking for LSP method support
vim.keymap.del("n", "grn")
vim.keymap.del("n", "gra")
vim.keymap.del("n", "grr")
vim.keymap.del("n", "gri")
-- vim.keymap.del("n", "grt") -- Disabled because I'm running 0.11.2
vim.keymap.del("n", "gO")
vim.keymap.del("i", "<C-S>")

local lsp_group = vim.api.nvim_create_augroup("LSP_Augroup", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = function(ev)
        local buf = ev.buf ---@type integer
        local client = assert(vim.lsp.get_client_by_id(ev.data.client_id)) ---@type vim.lsp.Client
        local methods = vim.lsp.protocol.Methods ---@type table

        -- Overwrite vim defaults
        vim.keymap.set("n", "gr", "<nop>", { buffer = buf }) -- Prevent default gr functionality

        if client:supports_method(methods.textDocument_definition) then
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = buf })
        end

        if client:supports_method(methods.textDocument_declaration) then
            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = buf })
        end

        -- Recreate/replace Nvim defaults (:help lsp-defaults)
        if client:supports_method(methods.textDocument_rename) then
            vim.keymap.set("n", "grn", function()
                local input = ut.get_input("Rename: ")
                if string.find(input, "%s") then
                    vim.notify(string.format("The name '%s' contains spaces", input))
                elseif #input > 0 then
                    vim.lsp.buf.rename(input)
                end
            end, { buffer = buf })
        end

        if client:supports_method(methods.textDocument_implementation) then
            vim.keymap.set("n", "gri", vim.lsp.buf.implementation, { buffer = buf })
        end

        if client:supports_method(methods.textDocument_codeAction) then
            vim.keymap.set("n", "gra", vim.lsp.buf.code_action, { buffer = buf })
        end

        if client:supports_method(methods.textDocument_references) then
            vim.keymap.set("n", "grr", function()
                vim.lsp.buf.references({ includeDeclaration = false })
            end, { buffer = buf })
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
            vim.keymap.set("n", "grt", vim.lsp.buf.type_definition, { buffer = buf })
        end

        if client:supports_method(methods.textDocument_documentSymbol) then
            vim.keymap.set("n", "gO", vim.lsp.buf.document_symbol, { buffer = buf })
        end

        -- Kickstart mapping
        if client:supports_method(methods.workspace_symbol) then
            vim.keymap.set("n", "gW", vim.lsp.buf.workspace_symbol, { buffer = buf })
        end

        -- Patternful with the rest of the defaults
        if client:supports_method(methods.textDocument_documentHighlight) then
            vim.keymap.set("n", "grh", vim.lsp.buf.document_highlight, { buffer = buf })
        end

        if client:supports_method(methods.textDocument_inlayHint) then
            vim.keymap.set("n", "grl", function()
                vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }))
            end)
        end

        vim.keymap.set("n", "grf", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, { buffer = buf })
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

local capabilities = vim.lsp.protocol.make_client_capabilities()
local cmp_capabilities = require("cmp_nvim_lsp").default_capabilities()
capabilities = vim.tbl_deep_extend("force", capabilities, cmp_capabilities)

vim.lsp.config("bashls", { capabilities = capabilities })
vim.lsp.enable("bashls")
vim.lsp.config("lua_ls", { capabilities = capabilities })
vim.lsp.enable("lua_ls")
vim.lsp.config("taplo", { capabilities = capabilities })
vim.lsp.enable("taplo")

-- FUTURE: Figure out why code lens isn't working
vim.lsp.config("rust_analyzer", {
    capabilities = capabilities,
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

vim.lsp.config("gopls", { capabilities = capabilities })
vim.lsp.enable("gopls")
vim.lsp.config("golangci_lint_ls", { capabilities = capabilities })
vim.lsp.enable("golangci_lint_ls")

vim.lsp.config("html", { capabilities = capabilities })
vim.lsp.enable("html")
vim.lsp.config("cssls", { capabilities = capabilities })
vim.lsp.enable("cssls")

vim.lsp.config("ruff", { capabilities = capabilities })
vim.lsp.enable("ruff")
-- Ruff is not feature-complete enough to replace pylsp
vim.lsp.config("pylsp", {
    { capabilities = capabilities },
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

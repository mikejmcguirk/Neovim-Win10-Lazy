-- LOW: Weird Issue where workspace update is triggered due to FzfLua require, and Semantic
-- Tokens do not consistently refresh afterwards

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
        local method = vim.lsp.protocol.Methods ---@type table
        local ok, fzf_lua = pcall(require, "fzf-lua") --- @type boolean, table

        -------------------------
        -- Overwrite vim defaults
        -------------------------

        Map("n", "gr", "<nop>", { buffer = buf })

        if client:supports_method(method.textDocument_definition) then
            local def = ok and fzf_lua.lsp_definitions or vim.lsp.buf.definition
            Map("n", "gd", def, { buffer = buf })
        end

        if client:supports_method(method.textDocument_declaration) then
            local dec = ok and fzf_lua.lsp_declarations or vim.lsp.buf.declaration
            Map("n", "gD", dec, { buffer = buf })
        end

        ------------------------------------------------------
        -- Recreate/replace Nvim defaults (:help lsp-defaults)
        ------------------------------------------------------

        if client:supports_method(method.textDocument_rename) then
            Map("n", "grn", function()
                --- @type boolean, string
                local ok_i, input = require("mjm.utils").get_input("Rename: ")
                if not ok_i then
                    local msg = input or "Unknown error getting input" --- @type string
                    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
                    return
                elseif #input < 1 then
                    return
                elseif string.find(input, "%s") then
                    local msg = string.format("'%s' contains spaces", input)
                    vim.api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
                    return
                end

                vim.lsp.buf.rename(input)
            end, { buffer = buf })
        end

        if client:supports_method(method.textDocument_implementation) then
            local impl = ok and fzf_lua.lsp_implementations or vim.lsp.buf.implementation
            Map("n", "gI", impl, { buffer = buf })
        end

        if client:supports_method(method.textDocument_codeAction) then
            Map("n", "gra", vim.lsp.buf.code_action, { buffer = buf })
        end

        if client:supports_method(method.textDocument_references) then
            local ref = (function()
                if ok then
                    return function() fzf_lua.lsp_references({ includeDeclaration = false }) end
                else
                    return function() vim.lsp.buf.references({ includeDeclaration = false }) end
                end
            end)()

            Map("n", "grr", ref, { buffer = buf })
        end

        if client:supports_method(method.textDocument_hover) then
            Map("n", "K", function() vim.lsp.buf.hover({ border = Border }) end, { buffer = buf })
        end

        if client:supports_method(method.textDocument_signatureHelp) then
            local signature_help = function() vim.lsp.buf.signature_help({ border = Border }) end
            Map({ "i", "s" }, "<C-S>", signature_help, { buffer = buf })
        end

        if client:supports_method(method.textDocument_typeDefinition) then
            if ok then
                Map("n", "grt", fzf_lua.lsp_typedefs, { buffer = buf })
            else
                Map("n", "grt", vim.lsp.buf.type_definition, { buffer = buf })
            end
        end

        if client:supports_method(method.textDocument_documentSymbol) then
            if ok then
                Map("n", "gO", fzf_lua.lsp_document_symbols, { buffer = buf })
            else
                Map("n", "gO", vim.lsp.buf.document_symbol, { buffer = buf })
            end
        end

        -----------
        -- Other --
        -----------

        -- Kickstart mapping
        if client:supports_method(method.workspace_symbol) then
            local ws = ok and fzf_lua.lsp_live_workspace_symbols or vim.lsp.buf.workspace_symbol
            Map("n", "gW", ws, { buffer = buf })
        end

        -- Patternful with the rest of the defaults
        if client:supports_method(method.textDocument_documentHighlight) then
            Map("n", "grh", vim.lsp.buf.document_highlight, { buffer = buf })
        end

        if client:supports_method(method.textDocument_inlayHint) then
            local inlay_toggle = function()
                vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ buffer = buf }))
            end
            Map("n", "grl", inlay_toggle)
        end

        if client:supports_method(method.textDocument_documentColor) then
            -- Maria Solano map (kinda)
            Map("n", "grc", function()
                -- vim.lsp.document_color.color_presentation()
                vim.lsp.document_color.enable(not vim.lsp.document_color.is_enabled())
            end, { buffer = buf })
        end

        local inspect_ws = function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end
        Map("n", "grf", inspect_ws, { buffer = buf })

        local toggle_tokens = function()
            vim.lsp.semantic_tokens.enable(not vim.lsp.semantic_tokens.is_enabled())
        end
        Map("n", "grm", toggle_tokens, { buffer = buf })
    end,
})

vim.api.nvim_create_autocmd("BufUnload", {
    group = lsp_group,
    callback = function(ev)
        local buf = ev.buf ---@type integer
        local clients = vim.lsp.get_clients({ bufnr = buf }) ---@type vim.lsp.Client[]
        if not clients or vim.tbl_isempty(clients) then return end

        for _, client in pairs(clients) do
            local attached_bufs = vim.tbl_filter(
                function(buf_nbr) return buf_nbr ~= buf end,
                vim.tbl_keys(client.attached_buffers)
            ) ---@type unknown[]

            if vim.tbl_isempty(attached_bufs) then vim.lsp.stop_client(client.id) end
        end
    end,
})

vim.lsp.enable({
    "bashls",
    "cssls",
    "golangci_lint_ls",
    "html",
    -- FUTURE: https://old.reddit.com/r/neovim/comments/1mdtr4g/emmylua_ls_is_supersnappy/
    -- This might be the way
    "lua_ls",
    -- Ruff is not feature-complete enough to replace pylsp
    "pylsp",
    "ruff",
    "rust_analyzer",
    "taplo",
})

local M = {}

function M.del_defaults()
    -- No need to map these in non-LSP buffers
    vim.keymap.del("n", "grn")
    vim.keymap.del("n", "gra")
    vim.keymap.del("n", "grr")
    vim.keymap.del("n", "gri")
    vim.keymap.del("n", "grt")
    vim.keymap.del("n", "gO")
    vim.keymap.del("i", "<C-S>")
end

--- @return table
function M.get_lsp_cmds()
    local cmds = {}
    local ok, fzflua = pcall(require, "fzf-lua") --- @type boolean, table
    local no_fzflua = function()
        vim.api.nvim_echo({ { "FzfLua not available", "" } }, true, {})
    end

    --- callHierarchy/incomingCalls ---
    cmds.in_call = ok and function()
        fzflua.lsp_incoming_calls({ jump1 = false })
    end or vim.lsp.buf.incoming_calls

    --- callHierarchy/outgoingCalls ---
    cmds.out_call = ok and function()
        fzflua.lsp_incoming_calls({ jump1 = false })
    end or vim.lsp.buf.outgoing_calls

    --- textDocument/codeAction ---
    cmds.code_action = ok and fzflua.lsp_code_actions or vim.lsp.buf.code_action

    --- textDocument/declaration ---
    cmds.declaration = ok and fzflua.lsp_declarations or vim.lsp.buf.declaration
    cmds.peek_declaration = ok
            and function()
                fzflua.lsp_declarations({ jump1 = false })
            end
        or no_fzflua

    --- textDocument/definition ---
    cmds.definition = ok and fzflua.lsp_definitions or vim.lsp.buf.definition
    cmds.peek_definition = ok
            and function()
                fzflua.lsp_definitions({ jump1 = false })
            end
        or no_fzflua

    --- textDocument/documentSymbol ---
    cmds.symbols = ok and fzflua.lsp_document_symbols or vim.lsp.buf.document_symbol

    --- textDocument/implementation ---
    cmds.implementation = ok and fzflua.lsp_implementations or vim.lsp.buf.implementation
    cmds.peek_implementation = ok
            and function()
                fzflua.lsp_implementations({ jump1 = false })
            end
        or no_fzflua

    --- textDocument/references ---
    cmds.references = ok
            and function()
                fzflua.lsp_references({ includeDeclaration = false })
            end
        or function()
            vim.lsp.buf.references({ includeDeclaration = false })
        end

    cmds.peek_references = ok
            and function()
                fzflua.lsp_references({ includeDeclaration = false, jump1 = false })
            end
        or no_fzflua

    --- textDocument/typeDefinition ---
    cmds.typedef = ok and fzflua.lsp_typedefs or vim.lsp.buf.type_definition
    cmds.peek_typedef = ok and function()
        fzflua.lsp_typedefs({ jump1 = false })
    end or no_fzflua

    --- workspace/symbol ---
    cmds.workspace = ok and fzflua.lsp_live_workspace_symbols or vim.lsp.buf.workspace_symbol

    return cmds
end

function M.set_lsp_maps(ev, cmds)
    local client = vim.lsp.get_client_by_id(ev.data.client_id) --- @type vim.lsp.Client?
    if not client then
        return
    end

    local buf = ev.buf ---@type integer

    --- callHierarchy/incomingCalls ---
    Map("n", "grc", cmds.in_call, { buffer = buf })

    --- callHierarchy/outgoingCalls ---
    Map("n", "grC", cmds.out_call, { buffer = buf })

    --- textDocument/codeAction ---
    Map("n", "gra", cmds.code_action, { buffer = buf })

    --- textDocument/codeLens ---
    if client:supports_method("textDocument/codeLens") then
        -- Lens updates are throttled so only one runs at a time. Updating on text change
        -- increases the likelihood of lenses rendering with stale data
        vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
            buffer = ev.buf,
            group = vim.api.nvim_create_augroup("refresh-lens", { clear = true }),
            -- Bespoke module so I can render the lenses as virtual lines
            callback = function()
                require("mjm.codelens").refresh({ buf = ev.buf })
            end,
        })
    end

    -- Use bespoke module because the lenses are cached there
    Map("n", "grs", require("mjm.codelens").run)

    --- textDocument/declaration ---
    Map("n", "grd", cmds.declaration, { buffer = buf })
    Map("n", "grD", cmds.peek_declaration)

    --- textDocument/definition ---
    if client:supports_method("textDocument/definition") then
        Map("n", "gd", cmds.definition, { buffer = buf })
        Map("n", "gD", cmds.peek_definition)
    end

    --- textDocument/documentColor ---
    Map("n", "gro", function()
        vim.lsp.document_color.enable(not vim.lsp.document_color.is_enabled())
    end, { buffer = buf })

    Map("n", "grO", vim.lsp.document_color.color_presentation, { buffer = buf })

    --- textDocument/documentHighlight ---
    Map("n", "grh", vim.lsp.buf.document_highlight, { buffer = buf })

    --- textDocument/documentSymbol ---
    Map("n", "gO", cmds.symbols, { buffer = buf })

    --- textDocument/hover ---
    Map("n", "K", function()
        vim.lsp.buf.hover({ border = Border })
    end, { buffer = buf })

    --- textDocument/implementation ---
    Map("n", "gri", cmds.implementation)
    Map("n", "grI", cmds.peek_implementation, { buffer = buf })

    --- textDocument/inlayHint ---
    Map("n", "grl", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ buffer = buf }))
    end)

    -- textDocument/linkedEditingRange

    --- textDocument/references ---
    Map("n", "grr", cmds.references, { buffer = buf })
    Map("n", "grR", cmds.peek_references, { buffer = buf })

    --- textDocument/rename ---
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

    ApiMap("n", "grN", "<nop>", { noremap = true, callback = vim.lsp.buf.rename })

    --- textDocument/signatureHelp ---
    Map({ "i", "s" }, "<C-S>", function()
        vim.lsp.buf.signature_help({ border = Border })
    end, { buffer = buf })

    --- textDocument/typeDefinition ---
    Map("n", "grt", cmds.typedef, { buffer = buf })
    if client:supports_method("textDocument/typeDefinition") then
        Map("n", "grT", cmds.peek_typedef, { buffer = buf })
    else
        local msg = "LSP Server does not have capability textDocument/typeDefinition"
        Map("n", "grT", function()
            vim.api.nvim_echo({ { msg, "" } }, true, {})
        end)
    end

    --- workspace/symbol ---
    -- Kickstart mapping
    Map("n", "gW", cmds.workspace, { buffer = buf })

    --- Other ---
    Map("n", "grm", function()
        vim.lsp.semantic_tokens.enable(not vim.lsp.semantic_tokens.is_enabled())
    end, { buffer = buf })

    Map("n", "grf", function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, { buffer = buf })
end

return M

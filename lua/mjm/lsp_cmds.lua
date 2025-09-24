-- TODO: Figure out how to open FzfLua outputs in a vsplit
-- TODO: Do the built-in commands have a way to always send to the qf/loclist?
-- In declaration at least, there's the on_list opt, which comes from a subfunction used across
-- a bunch of different commands. So it seems like that can be built

local M = {}

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

return M

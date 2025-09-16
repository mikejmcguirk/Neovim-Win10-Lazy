-- TODO: Consider getting a C lsp for reading code. I think clang is the one everyone uses

-- LOW: Weird Issue where workspace update is triggered due to FzfLua require, and Semantic
-- Tokens do not consistently refresh afterwards

vim.lsp.log.set_level(vim.log.levels.ERROR)

-- No need to map these in non-LSP buffers
-- TODO: mini.operators has a check to see if certain maps exist before deleting them
vim.keymap.del("n", "grn")
vim.keymap.del("n", "gra")
vim.keymap.del("n", "grr")
vim.keymap.del("n", "gri")
vim.keymap.del("n", "grt")
vim.keymap.del("n", "gO")
vim.keymap.del("i", "<C-S>")

-------------------------
-- Compute LSP Keymaps --
-------------------------

-- TODO: Figure out how to open FzfLua outputs in a vsplit

-- Trade a bit of RAM to only do this business once
local ok, fzf_lua = pcall(require, "fzf-lua") --- @type boolean, table

-- callHierarchy/incomingCalls
local in_call = (function()
    if ok then
        return function() fzf_lua.lsp_incoming_calls({ jump1 = false }) end
    else
        return vim.lsp.buf.incoming_calls
    end
end)()

-- callHierarchy/outgoingCalls
local out_call = (function()
    if ok then
        return function() fzf_lua.lsp_outgoing_calls({ jump1 = false }) end
    else
        return vim.lsp.buf.outgoing_calls
    end
end)()

-- textDocument/codeAction
local code_action = ok and fzf_lua.lsp_code_actions or vim.lsp.buf.code_action

-- textDocument/declaration
local declaration = ok and fzf_lua.lsp_declarations or vim.lsp.buf.declaration
local peek_declaration = (function()
    if ok then
        return function() fzf_lua.lsp_declarations({ jump1 = false }) end
    else
        return function() vim.api.nvim_echo({ { "FzfLua not available", "" } }, true, {}) end
    end
end)()

-- textDocument/definition
local definition = ok and fzf_lua.lsp_definitions or vim.lsp.buf.definition
local peek_definition = (function()
    if ok then
        return function() fzf_lua.lsp_definitions({ jump1 = false }) end
    else
        return function() vim.api.nvim_echo({ { "FzfLua not available", "" } }, true, {}) end
    end
end)()

-- textDocument/documentSymbol
local symbols = ok and fzf_lua.lsp_document_symbols or vim.lsp.buf.document_symbol

-- textDocument/implementation
local implementation = ok and fzf_lua.lsp_implementations or vim.lsp.buf.implementation
local peek_implementation = (function()
    if ok then
        return function() fzf_lua.lsp_implementations({ jump1 = false }) end
    else
        return function() vim.api.nvim_echo({ { "FzfLua not available", "" } }, true, {}) end
    end
end)()

-- textDocument/references
local references = (function()
    if ok then
        return function() fzf_lua.lsp_references({ includeDeclaration = false }) end
    else
        return function() vim.lsp.buf.references({ includeDeclaration = false }) end
    end
end)()

local peek_references = (function()
    if ok then
        return function() fzf_lua.lsp_references({ includeDeclaration = false, jump1 = false }) end
    else
        return function() vim.api.nvim_echo({ { "FzfLua not available", "" } }, true, {}) end
    end
end)()

-- textDocument/typeDefinition
local typedef = ok and fzf_lua.lsp_typedefs or vim.lsp.buf.type_definition
local peek_typedef = (function()
    if ok then
        return function() fzf_lua.lsp_typedefs({ jump1 = false }) end
    else
        local msg = "FzfLua not available"
        return function() vim.api.nvim_echo({ { msg, "" } }, true, {}) end
    end
end)()

-- workspace/symbol
local workspace = ok and fzf_lua.lsp_live_workspace_symbols or vim.lsp.buf.workspace_symbol

local lsp_group = vim.api.nvim_create_augroup("LSP_Augroup", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = function(ev)
        if not ev.data.client_id then return end
        local client = vim.lsp.get_client_by_id(ev.data.client_id) --- @type vim.lsp.Client?
        if not client then return end

        local buf = ev.buf ---@type integer

        Map("n", "gr", "<nop>", { buffer = buf })

        -- MAYBE: Depending on how these are used, you could put incoming and outgoing calls on
        -- separate mappings and use the capitals for jump1 = false

        -- callHierarchy/incomingCalls
        Map("n", "grc", in_call, { buffer = buf })

        -- callHierarchy/outgoingCalls
        Map("n", "grC", out_call, { buffer = buf })

        -- textDocument/codeAction
        Map("n", "gra", code_action, { buffer = buf })

        -- textDocument/codeLens
        if client:supports_method("textDocument/codeLens") then
            -- Lens updates are throttled so only one runs at a time. Updating on text change
            -- increases the likelihood of lenses rendering with stale data
            vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
                buffer = ev.buf,
                group = vim.api.nvim_create_augroup("refresh-lens", { clear = true }),
                -- Bespoke module so I can render the lenses as virtual lines
                callback = function() require("mjm.codelens").refresh({ buf = ev.buf }) end,
            })
        end

        -- Use bespoke module because the lenses are cached there
        Map("n", "grs", require("mjm.codelens").run)

        -- textDocument/declaration
        Map("n", "grd", declaration, { buffer = buf })
        if client:supports_method("textDocument/declaration") then
            Map("n", "grD", peek_declaration)
        else
            local msg = "LSP Server does not have capability textDocument/declaration"
            Map("n", "grD", function() vim.api.nvim_echo({ { msg, "" } }, true, {}) end)
        end

        -- textDocument/definition
        if client:supports_method("textDocument/definition") then
            Map("n", "gd", definition, { buffer = buf })
            Map("n", "gD", peek_definition)
        else
            local msg = "LSP Server does not have capability textDocument/definition"
            Map("n", "gD", function() vim.api.nvim_echo({ { msg, "" } }, true, {}) end)
        end

        -- textDocument/documentColor
        local color_toggle = function()
            vim.lsp.document_color.enable(not vim.lsp.document_color.is_enabled())
        end

        Map("n", "gro", color_toggle, { buffer = buf })
        Map("n", "grO", vim.lsp.document_color.color_presentation, { buffer = buf })

        -- textDocument/documentHighlight
        Map("n", "grh", vim.lsp.buf.document_highlight, { buffer = buf })

        -- textDocument/documentSymbol
        Map("n", "gO", symbols, { buffer = buf })

        -- textDocument/hover
        Map("n", "K", function() vim.lsp.buf.hover({ border = Border }) end, { buffer = buf })

        -- textDocument/implementation
        Map("n", "gri", implementation)
        if client:supports_method("textDocument/implementation") and ok then
            Map("n", "grI", peek_implementation, { buffer = buf })
        else
            local msg = "LSP Server does not have capability textDocument/implementation"
            Map("n", "grI", function() vim.api.nvim_echo({ { msg, "" } }, true, {}) end)
        end

        -- textDocument/inlayHint
        local inlay_toggle = function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ buffer = buf }))
        end
        Map("n", "grl", inlay_toggle)

        -- textDocument/linkedEditingRange
        -- FUTURE: The docs recommend trying this with html
        -- if client:supports_method("textDocument/linkedEditingRange") then
        --     vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
        -- end

        -- textDocument/references
        Map("n", "grr", references, { buffer = buf })
        local has_references = client:supports_method("textDocument/references")
        if has_references and ok then
            Map("n", "grR", peek_references, { buffer = buf })
        else
            local msg = "LSP Server does not have capability textDocument/references"
            Map("n", "grR", function() vim.api.nvim_echo({ { msg, "" } }, true, {}) end)
        end

        -- textDocument/rename
        Map("n", "grn", function()
            -- TODO: use a TS query to pull the current variable name. default to blank
            -- I think you can update the input func to feedkeys in  an optional prompt
            -- I'm not sure if default pretypes or is just what happens if you hit enter with
            -- nothing

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

        -- textDocument/signatureHelp
        local signature_help = function() vim.lsp.buf.signature_help({ border = Border }) end
        Map({ "i", "s" }, "<C-S>", signature_help, { buffer = buf })

        -- textDocument/typeDefinition
        Map("n", "grt", typedef, { buffer = buf })
        if client:supports_method("textDocument/typeDefinition") and ok then
            Map("n", "grT", peek_typedef, { buffer = buf })
        else
            local msg = "LSP Server does not have capability textDocument/typeDefinition"
            Map("n", "grT", function() vim.api.nvim_echo({ { msg, "" } }, true, {}) end)
        end

        -- workspace/symbol
        -- Kickstart mapping
        -- TODO: Think about this one. If we did grw, that gives us grw and grW. kickstart is the
        -- only place I've seen this. Not that widespread?
        Map("n", "gW", workspace, { buffer = buf })

        local toggle_tokens = function()
            vim.lsp.semantic_tokens.enable(not vim.lsp.semantic_tokens.is_enabled())
        end

        Map("n", "grm", toggle_tokens, { buffer = buf })

        local inspect_ws = function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end
        Map("n", "grf", inspect_ws, { buffer = buf })
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

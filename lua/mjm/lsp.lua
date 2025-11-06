local api = vim.api
local fn = vim.fn
local lsp = vim.lsp
local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

local ok, fzflua = pcall(require, "fzf-lua") ---@type boolean, table
local function peek_on_list(on_list_ctx)
    fn.setqflist({}, " ", { title = on_list_ctx.title, items = on_list_ctx.items })
    local ok_w, window = pcall(require, "qf-rancher.window") ---@type boolean, QfrWins?
    if ok_w and window then
        window.open_qflist({})
    else
        api.nvim_cmd({ cmd = "copen" }, {})
    end
end ---@type function

-- callHierarchy/incomingCalls --
local in_call = ok and function()
    fzflua.lsp_incoming_calls({ jump1 = false })
end or lsp.buf.incoming_calls ---@type function

-- callHierarchy/outgoingCalls --
local out_call = ok and function()
    fzflua.lsp_outgoing_calls({ jump1 = false })
end or lsp.buf.outgoing_calls ---@type function

-- textDocument/codeAction --
local code_action = ok and fzflua.lsp_code_actions or lsp.buf.code_action ---@type function

-- textDocument/declaration --
local declaration = ok and fzflua.lsp_declarations or lsp.buf.declaration ---@type function
local peek_declaration = ok and function()
    fzflua.lsp_declarations({ jump1 = false })
end or function()
    lsp.buf.declaration({ on_list = peek_on_list })
end ---@type function

-- textDocument/definition --
local definition = ok and fzflua.lsp_definitions or lsp.buf.definition ---@type function
local peek_definition = ok and function()
    fzflua.lsp_definitions({ jump1 = false })
end or function()
    lsp.buf.definition({ on_list = peek_on_list })
end ---@type function

-- textDocument/documentSymbol --
local symbols = ok and fzflua.lsp_document_symbols or lsp.buf.document_symbol ---@type function

-- textDocument/implementation --
---@type function
local implementation = ok and fzflua.lsp_implementations or lsp.buf.implementation
local peek_implementation = ok and function()
    fzflua.lsp_implementations({ jump1 = false })
end or function()
    lsp.buf.implementation({ on_list = peek_on_list })
end ---@type function

-- textDocument/references --
local references = ok and function()
    fzflua.lsp_references({ includeDeclaration = false })
end or function()
    lsp.buf.references({ includeDeclaration = false })
end ---@type function

local peek_references = ok
        and function()
            fzflua.lsp_references({ includeDeclaration = false, jump1 = false })
        end
    or function()
        lsp.buf.references({
            includeDeclaration = false,
            on_list = function(list)
                fn.setqflist({}, " ", list)
                local rancher_window = require("qf-rancher.window") ---@type QfrWins?
                if rancher_window then
                    rancher_window.open_qflist({})
                else
                    api.nvim_cmd({ cmd = "copen" }, {})
                end
            end,
        })
    end ---@type function

-- textDocument/typeDefinition --
local typedef = ok and fzflua.lsp_typedefs or lsp.buf.type_definition ---@type function
local peek_typedef = ok and function()
    fzflua.lsp_typedefs({ jump1 = false })
end or function()
    lsp.buf.type_definition({
        on_list = peek_on_list,
    })
end ---@type function

-- workspace/symbol --
---@type function
local workspace = ok and fzflua.lsp_live_workspace_symbols or lsp.buf.workspace_symbol

---@param lhs string
---@param client vim.lsp.Client
---@param method string
---@param buf integer
---@return nil
local function map_no_support(lhs, client, method, buf)
    vim.keymap.set("n", lhs, function()
        ---@type [string, string|integer?]
        local chunk = { "Client " .. client.name .. " does not support method " .. method }
        api.nvim_echo({ chunk }, false, {})
    end, { buffer = buf })
end

require("mjm.codelens").config({ hl_mode = "replace", virtual_lines = true })

---@param ev vim.api.keyset.create_autocmd.callback_args
---@return nil
local function set_lsp_maps(ev)
    local client = lsp.get_client_by_id(ev.data.client_id) ---@type vim.lsp.Client?
    if not client then return end
    local buf = ev.buf ---@type integer

    -- callHierarchy/incomingCalls --
    vim.keymap.set("n", "grc", in_call, { buffer = buf })

    -- callHierarchy/outgoingCalls --
    vim.keymap.set("n", "grC", out_call, { buffer = buf })

    -- textDocument/codeAction --
    vim.keymap.set("n", "gra", code_action, { buffer = buf })

    -- textDocument/codeLens --
    -- TODO: Update my bespoke module with an enable/disable for codelens, then PR to the core
    if client:supports_method("textDocument/codeLens") then
        vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
            buffer = ev.buf,
            group = vim.api.nvim_create_augroup("mjm-refresh-lens", { clear = true }),
            -- Bespoke module so I can render the lenses as virtual lines
            callback = function()
                require("mjm.codelens").refresh({ buf = ev.buf })
            end,
        })
    end

    -- textDocument/declaration --
    vim.keymap.set("n", "grd", declaration, { buffer = buf })
    vim.keymap.set("n", "grD", peek_declaration)

    -- textDocument/definition --
    if client:supports_method("textDocument/definition") then
        vim.keymap.set("n", "gd", definition, { buffer = buf })
        vim.keymap.set("n", "gD", peek_definition)
    end

    -- textDocument/documentColor --
    vim.keymap.set("n", "gro", function()
        lsp.document_color.enable(not lsp.document_color.is_enabled())
    end, { buffer = buf })

    vim.keymap.set("n", "grO", lsp.document_color.color_presentation, { buffer = buf })

    -- textDocument/documentHighlight --
    vim.keymap.set("n", "grh", lsp.buf.document_highlight, { buffer = buf })

    -- textDocument/documentSymbol --
    if client:supports_method("textDocument/documentSymbol") then
        vim.keymap.set("n", "gO", symbols, { buffer = buf })
    end

    -- textDocument/hover --
    vim.keymap.set("n", "K", function()
        lsp.buf.hover({ border = Mjm_Border })
    end, { buffer = buf })

    -- textDocument/implementation --
    vim.keymap.set("n", "gri", implementation)
    vim.keymap.set("n", "grI", peek_implementation, { buffer = buf })

    -- textDocument/inlayHint --
    if client:supports_method("textDocument/inlayHint") then
        vim.keymap.set("n", "grl", function()
            lsp.inlay_hint.enable(not lsp.inlay_hint.is_enabled({ buffer = buf }))
        end)
    else
        map_no_support("grl", client, "textDocument/inlay_hint", buf)
    end

    -- textDocument/linkedEditingRange
    -- the docs recommend trying with html:
    -- if client:supports_method("textDocument/linkedEditingRange") then
    --     vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
    -- end

    -- textDocument/references --
    vim.keymap.set("n", "grr", references, { buffer = buf })
    vim.keymap.set("n", "grR", peek_references, { buffer = buf })

    -- textDocument/rename --
    vim.keymap.set("n", "grn", function()
        ---@type boolean, string
        local ok_i, input = require("mjm.utils").get_input("Rename: ")
        if not ok_i then
            local msg = input or "Unknown error getting input" ---@type string
            api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        elseif #input < 1 then
            return
        elseif string.find(input, "%s") then
            local msg = string.format("'%s' contains spaces", input)
            api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
            return
        end

        lsp.buf.rename(input)
    end, { buffer = buf })

    vim.keymap.set("n", "grN", lsp.buf.rename, { buffer = buf })

    -- textDocument/semanticTokens
    if client:supports_method("textDocument/semanticTokens/full") then
        vim.keymap.set("n", "grm", function()
            lsp.semantic_tokens.enable(not lsp.semantic_tokens.is_enabled())
        end, { buffer = buf })
    else
        map_no_support("grm", client, "textDocument/semanticTokens/full", buf)
    end

    -- textDocument/signatureHelp --
    vim.keymap.set({ "i", "s" }, "<C-S>", function()
        lsp.buf.signature_help({ border = Mjm_Border })
    end, { buffer = buf })

    -- textDocument/typeDefinition --
    vim.keymap.set("n", "grt", typedef, { buffer = buf })
    vim.keymap.set("n", "grT", peek_typedef, { buffer = buf })

    -- typeHierarchy/subtypes --
    if client:supports_method("typeHierarchy/subtypes") then
        vim.keymap.set("n", "grY", function()
            vim.lsp.buf.typehierarchy("subtypes")
        end, { buffer = buf })
    else
        map_no_support("grY", client, "typeHierarchy/subtypes", buf)
    end

    -- typeHierarchy/supertypes --
    if client:supports_method("typeHierarchy/supertypes") then
        vim.keymap.set("n", "gry", function()
            vim.lsp.buf.typehierarchy("supertypes")
        end, { buffer = buf })
    else
        map_no_support("gry", client, "typeHierarchy/supertypes", buf)
    end

    -- workspace/symbol --
    vim.keymap.set("n", "grw", workspace, { buffer = buf })
end

local lsp_group = vim.api.nvim_create_augroup("lsp-autocmds", { clear = true }) ---@type integer
vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = set_lsp_maps,
})

vim.api.nvim_create_autocmd("LspDetach", {
    group = lsp_group,
    callback = function(ev)
        local buf = ev.buf ---@type integer
        local clients = lsp.get_clients({ bufnr = buf }) ---@type vim.lsp.Client[]
        if not clients or vim.tbl_isempty(clients) then return end

        ut.do_when_idle(function()
            for _, client in pairs(clients) do
                local attached_bufs = vim.tbl_keys(client.attached_buffers) ---@type integer[]
                if vim.tbl_isempty(attached_bufs) then lsp.stop_client(client.id) end
            end
        end)
    end,
})

lsp.log.set_level(vim.log.levels.ERROR)

lsp.enable({
    -- Bash --
    "bashls",
    -- Go --
    "golangci_lint_ls",
    "gopls",
    -- HTML/CSS --
    "cssls",
    "html",
    -- Lua --
    "lua_ls",
    -- Markdown --
    "markdown_oxide",
    -- Python --
    "pylsp",
    "ruff",
    -- Rust --
    "rust_analyzer",
    -- Toml --
    "taplo",
})

-- TODO: Get a C LSP for reading code

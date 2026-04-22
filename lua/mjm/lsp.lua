local api = vim.api
local fn = vim.fn
local lsp = vim.lsp
local set = vim.keymap.set

set("n", "gr", "<nop>")
-- LOW: This could, in theory, overwrite a gO mapping I create
if #fn.maparg("gO", "n") > 0 then
    vim.keymap.del("n", "gO")
end
-- MID: Don't love this because:
-- - Say you type grx without manually remapping it, the "gr" will <nop> and nv_abbrev runs
-- - This doesnn't deal with the problem of all LSP maps being unconditional

local ok, fzflua = pcall(require, "fzf-lua") ---@type boolean, table
---@type function
local qf_open = (function()
    local ok_w, window = pcall(require, "qf-rancher.window") ---@type boolean, qf-rancher.Window?
    return (ok_w and window) and function()
        window.open_qf_win({})
    end or function()
        api.nvim_cmd({ cmd = "copen" }, {})
    end
end)()

---@type function
local function peek_on_list(on_list_ctx)
    -- MID: Rancher should have an interface where you can do the list set, and it should be able
    -- to detect the title and replace if it exists
    fn.setqflist({}, " ", { title = on_list_ctx.title, items = on_list_ctx.items })
    -- MID: Rancher should allow you to open to a specific list number, basically setting the
    -- stack nr underneath before opening
    qf_open()
end

-- callHierarchy/incomingCalls --
---@type function
local in_call = ok and function()
    fzflua.lsp_incoming_calls({ jump1 = false })
end or lsp.buf.incoming_calls

-- callHierarchy/outgoingCalls --
---@type function
local out_call = ok and function()
    fzflua.lsp_outgoing_calls({ jump1 = false })
end or lsp.buf.outgoing_calls

-- textDocument/codeAction --
local code_action = ok and fzflua.lsp_code_actions or lsp.buf.code_action ---@type function

-- textDocument/declaration --
local declaration = ok and fzflua.lsp_declarations or lsp.buf.declaration ---@type function
---@type function
local peek_declaration = ok and function()
    fzflua.lsp_declarations({ jump1 = false })
end or function()
    lsp.buf.declaration({ on_list = peek_on_list })
end

-- textDocument/definition --
local definition = ok and fzflua.lsp_definitions or lsp.buf.definition ---@type function
---@type function
local peek_definition = ok and function()
    fzflua.lsp_definitions({ jump1 = false })
end or function()
    lsp.buf.definition({ on_list = peek_on_list })
end

-- textDocument/documentSymbol --
local symbols = ok and fzflua.lsp_document_symbols or lsp.buf.document_symbol ---@type function

-- textDocument/implementation --
---@type function
local implementation = ok and fzflua.lsp_implementations or lsp.buf.implementation
---@type function
local peek_implementation = ok and function()
    fzflua.lsp_implementations({ jump1 = false })
end or function()
    lsp.buf.implementation({ on_list = peek_on_list })
end

-- textDocument/references --
---@type function
local references = ok and function()
    fzflua.lsp_references({ includeDeclaration = false })
end or function()
    lsp.buf.references({ includeDeclaration = false })
end

-- PR: Unlike the other functions, this does not pass the full list ctx. Unsure how you change
-- this over though without breaking configs
---@type function
local peek_references = ok
        and function()
            fzflua.lsp_references({ includeDeclaration = false, jump1 = false })
        end
    or function()
        lsp.buf.references({
            includeDeclaration = false,
            on_list = function(list)
                fn.setqflist({}, " ", list)
                qf_open()
            end,
        })
    end

-- textDocument/typeDefinition --
local typedef = ok and fzflua.lsp_typedefs or lsp.buf.type_definition ---@type function
---@type function
local peek_typedef = ok and function()
    fzflua.lsp_typedefs({ jump1 = false })
end or function()
    lsp.buf.type_definition({
        on_list = peek_on_list,
    })
end

-- workspace/symbol --
---@type function
local workspace = ok and fzflua.lsp_live_workspace_symbols or lsp.buf.workspace_symbol

---@param lhs string
---@param client vim.lsp.Client
---@param method string
---@param buf integer
---@return nil
local function map_no_support(lhs, client, method, buf)
    set("n", lhs, function()
        ---@type [string, string|integer?]
        local chunk = { "Client " .. client.name .. " does not support method " .. method }
        api.nvim_echo({ chunk }, false, {})
    end, { buf = buf })
end

---@param ev vim.api.keyset.create_autocmd.callback_args
---@return nil
local function set_lsp_maps(ev)
    local buf = ev.buf ---@type integer
    local client = lsp.get_client_by_id(ev.data.client_id) ---@type vim.lsp.Client?
    if not client then
        return
    end

    -- callHierarchy/incomingCalls --
    set("n", "grC", in_call, { buf = buf })

    -- callHierarchy/outgoingCalls --
    set("n", "grc", out_call, { buf = buf })

    -- textDocument/codeAction --
    set("n", "gra", code_action, { buf = buf })

    -- textDocument/codeLens --
    if client:supports_method("textDocument/codeLens") then
        vim.lsp.codelens.enable()
        set("n", "grx", vim.lsp.codelens.run, { buf = buf })
    end

    -- textDocument/declaration --
    set("n", "grd", declaration, { buf = buf })
    set("n", "grD", peek_declaration, { buf = buf })

    -- textDocument/definition --
    if client:supports_method("textDocument/definition") then
        set("n", "gd", definition, { buf = buf })
        set("n", "gD", peek_definition, { buf = buf })
    end

    -- textDocument/documentColor --
    set("n", "gro", function()
        local enabled = lsp.document_color.is_enabled() ---@type boolean
        lsp.document_color.enable(not enabled)
    end, { buf = buf })

    set("n", "grO", lsp.document_color.color_presentation, { buf = buf })

    -- textDocument/documentHighlight --
    set("n", "grh", lsp.buf.document_highlight, { buf = buf })

    -- textDocument/documentSymbol --
    if client:supports_method("textDocument/documentSymbol") then
        set("n", "gO", symbols, { buf = buf })
    end

    -- textDocument/hover --
    -- Default border now set with winborder

    -- textDocument/implementation --
    set("n", "gri", implementation, { buf = buf })
    set("n", "grI", peek_implementation, { buf = buf })

    -- textDocument/inlayHint --
    if client:supports_method("textDocument/inlayHint") then
        set("n", "grl", function()
            lsp.inlay_hint.enable(not lsp.inlay_hint.is_enabled({ buf = buf }))
        end, { buf = buf })
    else
        map_no_support("grl", client, "textDocument/inlay_hint", buf)
    end

    -- textDocument/linkedEditingRange
    -- the docs recommend trying with html:
    -- if client:supports_method("textDocument/linkedEditingRange") then
    --     vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
    -- end

    -- textDocument/references --
    set("n", "grr", references, { buf = buf })
    set("n", "grR", peek_references, { buf = buf })

    -- textDocument/rename --
    set("n", "grn", function()
        local ok_i, input = require("nvim-tools.ui").get_input("Rename: ")
        if not ok_i then
            local msg = input or "Unknown error getting input" ---@type string
            api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        elseif #input < 1 then
            return
        elseif string.find(input, "%s") then
            local msg = string.format("'%s' contains spaces", input) ---@type string
            api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
            return
        end

        lsp.buf.rename(input)
    end, { buf = buf })

    set("n", "grN", lsp.buf.rename, { buf = buf })

    -- textDocument/semanticTokens
    if client:supports_method("textDocument/semanticTokens/full") then
        set("n", "grm", function()
            local enabled = lsp.semantic_tokens.is_enabled() ---@type boolean
            lsp.semantic_tokens.enable(not enabled)
        end, { buf = buf })
    else
        map_no_support("grm", client, "textDocument/semanticTokens/full", buf)
    end

    -- textDocument/signatureHelp --
    -- Border supplied with winborder

    -- textDocument/typeDefinition --
    set("n", "grt", typedef, { buf = buf })
    set("n", "grT", peek_typedef, { buf = buf })

    -- typeHierarchy/subtypes --
    if client:supports_method("typeHierarchy/subtypes") then
        set("n", "grY", function()
            vim.lsp.buf.typehierarchy("subtypes")
        end, { buf = buf })
    else
        map_no_support("grY", client, "typeHierarchy/subtypes", buf)
    end

    -- typeHierarchy/supertypes --
    if client:supports_method("typeHierarchy/supertypes") then
        set("n", "gry", function()
            vim.lsp.buf.typehierarchy("supertypes")
        end, { buf = buf })
    else
        map_no_support("gry", client, "typeHierarchy/supertypes", buf)
    end

    -- workspace/symbol --
    set("n", "grw", workspace, { buf = buf })
end

local lsp_group = api.nvim_create_augroup("mjm-lsp", {}) ---@type integer
vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = set_lsp_maps,
})

vim.api.nvim_create_autocmd("LspDetach", {
    group = lsp_group,
    callback = vim.schedule_wrap(function(ev)
        local client_id = ev.data.client_id
        if not client_id then
            return
        end

        local client = lsp.get_client_by_id(client_id)
        if not client then
            return
        end

        if not next(lsp.get_client_by_id(client_id).attached_buffers) then
            client:stop()
        end
    end),
})

lsp.log.set_level(vim.log.levels.ERROR)

-- MID: If you have an LSP, it should be possible to type something like grv and replace a variable
-- with its corresponding literal. I think rust-analyzer has this as a code action. Is there a more
-- generalizable way to do it
-- MID: It should be possible to send all occurrences of a symbol within a scope to the qflist or
-- something. documentHighlight detects this properly, so...

-- LOW: LspInfo is an alias for checkhealth vim.lsp, and there is a project to upstream cmds from
-- nvim-lspconfig to core. Unsure of where that will eventually land
-- LOW: For the split use case, FzfLua handles this well enough for it to not be worth worrying
-- about. Do want to look into how to use winnr as an input to open the result to a specific win

-- PR: In the lens drawing, could be mis-understanding, but does it like tear down and re-create
-- the namespace for each client? This kind of makes sense because you wouldn't want "X references"
-- being shown multiple times, but still odd

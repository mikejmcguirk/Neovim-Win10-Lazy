local api = vim.api
local lsp = vim.lsp
local set = vim.keymap.set

lsp.log.set_level(vim.log.levels.ERROR)

set("n", "gr", "<nop>")
for _, map in ipairs({ "gra", "gri", "grn", "grr", "grt", "gO" }) do
    if #vim.call("maparg", map, "n") > 0 then
        vim.keymap.del("n", map)
    end
end

if #vim.call("maparg", "<C-s>", "i") > 0 then
    vim.keymap.del("i", "<C-s>")
end

---@param ev vim.api.keyset.create_autocmd.callback_args
local function set_lsp_maps(ev)
    local buf = ev.buf
    local client = lsp.get_client_by_id(ev.data.client_id)
    if not client then
        return
    end

    -- callHierarchy/incomingCalls --
    set("n", "grC", function()
        require("fzf-lua").lsp_incoming_calls({ jump1 = false })
    end, { buf = buf })

    -- callHierarchy/outgoingCalls --
    set("n", "grc", function()
        require("fzf-lua").lsp_outgoing_calls({ jump1 = false })
    end, { buf = buf })

    -- textDocument/codeAction --
    set("n", "gra", function()
        require("fzf-lua").lsp_code_actions()
    end, { buf = buf })

    -- textDocument/codeLens --
    if client:supports_method("textDocument/codeLens") then
        -- blink + moxide + codelens on line 1 + core workaround of changing view = the cursor
        -- moves up and down during LSP driven autocompletion
        if api.nvim_get_option_value("ft", { buf = buf }) ~= "markdown" then
            lsp.codelens.enable()
        end
    end

    -- textDocument/declaration --
    set("n", "grd", function()
        require("fzf-lua").lsp_declarations()
    end, { buf = buf })

    set("n", "grD", function()
        require("fzf-lua").lsp_declarations({ jump1 = false })
    end, { buf = buf })

    set("n", "gr<C-d>", function()
        local fzf_lua = require("fzf-lua")
        fzf_lua.lsp_declarations({
            jump1_action = fzf_lua.actions.file_vsplit,
        })
    end, { buf = buf })

    -- textDocument/definition --
    -- Check method support because these mask a Vim default.
    if client:supports_method("textDocument/definition") then
        set("n", "gd", function()
            require("fzf-lua").lsp_definitions()
        end, { buf = buf })

        set("n", "gD", function()
            require("fzf-lua").lsp_definitions({ jump1 = false })
        end, { buf = buf })

        set("n", "g<C-d>", function()
            local fzf_lua = require("fzf-lua")
            fzf_lua.lsp_definitions({
                jump1_action = fzf_lua.actions.file_vsplit,
            })
        end, { buf = buf })
    end

    -- textDocument/documentColor --
    set("n", "gro", function()
        lsp.document_color.enable(not lsp.document_color.is_enabled())
    end, { buf = buf })

    set("n", "grO", lsp.document_color.color_presentation, { buf = buf })

    -- textDocument/documentHighlight --

    -- textDocument/documentSymbol --
    -- Check method support because this masks a Vim default.
    if client:supports_method("textDocument/documentSymbol") then
        set("n", "gO", function()
            require("fzf-lua").lsp_document_symbols()
        end, { buf = buf })
    end

    -- textDocument/hover --

    -- textDocument/implementation --
    set("n", "gri", function()
        require("fzf-lua").lsp_implementations()
    end, { buf = buf })

    set("n", "grI", function()
        require("fzf-lua").lsp_implementations({ jump1 = false })
    end, { buf = buf })

    set("n", "gr<C-i>", function()
        local fzf_lua = require("fzf-lua")
        fzf_lua.lsp_implementations({
            jump1_action = fzf_lua.actions.file_vsplit,
        })
    end)

    -- textDocument/inlayHint --
    if client:supports_method("textDocument/inlayHint") then
        set("n", "grh", function()
            lsp.inlay_hint.enable(not lsp.inlay_hint.is_enabled({ buf = buf }))
        end, { buf = buf })
    end

    -- textDocument/linkedEditingRange
    -- the docs recommend trying with html:
    -- if client:supports_method("textDocument/linkedEditingRange") then
    --     vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
    -- end

    -- textDocument/references --
    set("n", "grr", function()
        require("fzf-lua").lsp_references({ includeDeclaration = false })
    end, { buf = buf })

    set("n", "grR", function()
        require("fzf-lua").lsp_references({ includeDeclaration = false, jump1 = false })
    end, { buf = buf })

    set("n", "gr<C-r>", function()
        local fzf_lua = require("fzf-lua")
        fzf_lua.lsp_references({
            includeDeclaration = false,
            jump1_action = fzf_lua.actions.file_vsplit,
        })
    end)

    -- textDocument/rename --
    -- Handled through catharsis

    -- textDocument/semanticTokens
    if client:supports_method("textDocument/semanticTokens/full") then
        set("n", "grm", function()
            lsp.semantic_tokens.enable(not lsp.semantic_tokens.is_enabled())
        end, { buf = buf })
    end

    -- textDocument/signatureHelp --
    set("i", "<C-s>", function()
        lsp.buf.signature_help()
    end)

    -- textDocument/typeDefinition --
    set("n", "grt", function()
        require("fzf-lua").lsp_typedefs()
    end, { buf = buf })

    set("n", "grT", function()
        require("fzf-lua").lsp_typedefs({ jump1 = false })
    end, { buf = buf })

    set("n", "gr<C-t>", function()
        local fzf_lua = require("fzf-lua")
        fzf_lua.lsp_typedefs({
            jump1_action = fzf_lua.actions.file_vsplit,
        })
    end)

    -- typeHierarchy/subtypes --
    if client:supports_method("typeHierarchy/subtypes") then
        set("n", "grY", function()
            require("fzf-lua").lsp_type_sub({ jump1 = false })
        end, { buf = buf })
    end

    -- typeHierarchy/supertypes --
    if client:supports_method("typeHierarchy/supertypes") then
        set("n", "gry", function()
            require("fzf-lua").lsp_type_super({ jump1 = false })
        end, { buf = buf })
    end

    -- workspace/symbol --
    set("n", "grw", function()
        require("fzf-lua").lsp_live_workspace_symbols()
    end, { buf = buf })
end

local lsp_group = api.nvim_create_augroup("mjm-lsp", {}) ---@type integer
api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = set_lsp_maps,
})

api.nvim_create_autocmd("LspDetach", {
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

        if not next(client.attached_buffers) then
            client:stop()
        end
    end),
})

local M = {}

---@param config vim.lsp.Config
---@param opts vim.lsp.start.Opts?
---@return nil
function M.start(config, opts)
    vim.validate("config", config, "table")
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local start_opts = vim.deepcopy(opts, true) ---@type vim.lsp.start.Opts
    start_opts.bufnr = vim._resolve_bufnr(start_opts.bufnr) ---@type integer
    if api.nvim_get_option_value("buftype", { buf = start_opts.bufnr }) ~= "" then
        return
    end

    start_opts.reuse_client = config.reuse_client
    ---@diagnostic disable-next-line: invisible, access-invisible
    start_opts._root_markers = config.root_markers
    if type(config.root_dir) == "function" then
        config.root_dir(start_opts.bufnr, function(root_dir)
            config = vim.deepcopy(config, true)
            ---@diagnostic disable-next-line: need-check-nil
            config.root_dir = root_dir
            vim.schedule(function()
                lsp.start(config, start_opts)
            end)
        end)
    else
        lsp.start(config, start_opts)
    end
end

return M

-- LOW: If no attached LSPs support a method, the keymap should print a message saying so.
-- LOW: It would be neat if keymaps were auto attached/detached based on the attached LSPs,
-- rather than bluntly on attach.
-- LOW: Make textDocument/documentLink work.
-- - Tough because the default `gx` mapping handles so many things.

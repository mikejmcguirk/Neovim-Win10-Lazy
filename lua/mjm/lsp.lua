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

-- require("mjm.codelens").set_display({ hl_mode = "replace", virt_lines = true, virt_text = false })
-- For testing
vim.lsp.codelens.config({
    virt_text = false,
    virt_lines = function(buf, ns, line, chunks)
        local indent = vim.api.nvim_buf_call(buf, function()
            return vim.fn.indent(line + 1)
        end)

        if indent > 0 then table.insert(chunks, 1, { string.rep(" ", indent), "" }) end
        vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
            virt_lines = { chunks },
            virt_lines_above = true,
            hl_mode = "replace", -- Default: 'combine'
        })
    end,
})

---@param ev vim.api.keyset.create_autocmd.callback_args
---@return nil
local function set_lsp_maps(ev)
    local client = lsp.get_client_by_id(ev.data.client_id) ---@type vim.lsp.Client?
    if not client then return end
    local buf = ev.buf ---@type integer

    -- callHierarchy/incomingCalls --
    vim.keymap.set("n", "grC", in_call, { buffer = buf })

    -- callHierarchy/outgoingCalls --
    vim.keymap.set("n", "grc", out_call, { buffer = buf })

    -- textDocument/codeAction --
    vim.keymap.set("n", "gra", code_action, { buffer = buf })

    -- textDocument/codeLens --
    if client:supports_method("textDocument/codeLens") then
        vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
            buffer = ev.buf,
            callback = function()
                vim.lsp.codelens.refresh({ buf = ev.buf })
                -- require("mjm.codelens").refresh({ buf = ev.buf })
            end,
        })
    end

    -- textDocument/declaration --
    vim.keymap.set("n", "grd", declaration, { buffer = buf })
    vim.keymap.set("n", "grD", peek_declaration, { buffer = buf })

    -- textDocument/definition --
    if client:supports_method("textDocument/definition") then
        vim.keymap.set("n", "gd", definition, { buffer = buf })
        vim.keymap.set("n", "gD", peek_definition, { buffer = buf })
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
    -- Default border now set with winborder

    -- textDocument/implementation --
    vim.keymap.set("n", "gri", implementation, { buffer = buf })
    vim.keymap.set("n", "grI", peek_implementation, { buffer = buf })

    -- textDocument/inlayHint --
    if client:supports_method("textDocument/inlayHint") then
        vim.keymap.set("n", "grl", function()
            lsp.inlay_hint.enable(not lsp.inlay_hint.is_enabled({ buffer = buf }))
        end, { buffer = buf })
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
    -- Border supplied with winborder

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
        for _, client in ipairs(lsp.get_clients({ bufnr = ev.buf }) or {}) do
            if vim.tbl_isempty(vim.tbl_keys(client.attached_buffers)) then
                ut.do_when_idle(function()
                    client:stop()
                end)
            end
        end
    end,
})

vim.keymap.set("n", "gr", "<nop>")
lsp.log.set_level(vim.log.levels.ERROR)

-- TODO: PR: vim.lsp.start should be able to take a vim.lsp.Config table directly
-- Problem: State of how project scope is defined in Neovim is evolving. The changes you would
-- make right now might be irrelevant to future project architecture (including deprecations of
-- current interfaces)
--
-- TRACKING ISSUES
-- https://github.com/neovim/neovim/issues/33214 - Project local data
-- https://github.com/neovim/neovim/issues/34622 - Decoupling root markers from LSP

-- NOTES:
-- https://github.com/neovim/neovim/pull/35182 - Rejected vim.project PR. Contains some thoughts
-- https://github.com/neovim/neovim/issues/8610 - General project concept thoughts
-- https://github.com/mfussenegger/nvim-dap/discussions/1530: Project root in the DAP context
-- exrc discussion: https://github.com/neovim/neovim/issues/33214#issuecomment-3159688873
-- https://github.com/neovim/neovim/pull/33771: Wildcards in fs.find
-- https://github.com/neovim/neovim/issues/33318: bcd
-- https://github.com/neovim/neovim/pull/33320: buf local cwd
-- https://github.com/neovim/neovim/pull/18506 (comment in here on project idea)
-- https://github.com/neovim/neovim/pull/31031 - lsp.config/lsp.enable

mjm.lsp = {}

---@param config vim.lsp.Config
---@param opts vim.lsp.start.Opts?
---@return integer? client_id
function mjm.lsp.start(config, opts)
    vim.validate("config", config, "table")
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    -- In an actual lsp.start rewrite, local values would be created. But since this
    -- proof-of-concept is just a wrapper for lsp.start, we need to pass along the modified opts.
    -- Create a separate table to avoid modifying the original
    local start_opts = vim.deepcopy(opts, true) ---@type vim.lsp.start.Opts
    start_opts.bufnr = vim._resolve_bufnr(start_opts.bufnr) ---@type integer
    -- From the lsp.enable logic
    -- NOTE: The comment below should actually be in lsp.start since it's a weird edge case
    -- Do not display an error if this fails, even if not opts.silent. The comment operator runs
    -- the ftplugin in the background on a nofile buffer. To avoid this, the user would need to
    -- set opts.silent = true in all cases
    if api.nvim_get_option_value("buftype", { buf = start_opts.bufnr }) ~= "" then return end

    -- I think it would be the most clean to deprecate start.Opts.reuse_client and only use the
    -- value in lsp.Config. Emulate that behavior below
    start_opts.reuse_client = config.reuse_client
    -- The future state of what process owns root_markers and how they are accessed is still
    -- being discussed. For now, simply use the current underscore interface
    ---@diagnostic disable-next-line: invisible
    start_opts._root_markers = config.root_markers
    -- Leaving this as is. A change, IMO, would need to be based on how root_markers are handled
    if type(config.root_dir) == "function" then
        config.root_dir(start_opts.bufnr, function(root_dir)
            -- NOTE: Similarly to the opts table, a re-write of lsp.start would just create locals
            config = vim.deepcopy(config, true)
            config.root_dir = root_dir
            vim.schedule(function()
                return vim.lsp.start(config, start_opts)
            end)
        end)
    else
        return vim.lsp.start(config, start_opts)
    end
end

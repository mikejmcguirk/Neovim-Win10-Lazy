local api = vim.api
local fn = vim.fn
local lsp = vim.lsp
local set = vim.keymap.set

set("n", "gr", "<nop>")
-- LOW: This could, in theory, overwrite a gO mapping I create
if #fn.maparg("gO", "n") > 0 then
    vim.keymap.del("n", "gO")
end

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
    end, { buffer = buf })
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
    set("n", "grC", in_call, { buffer = buf })

    -- callHierarchy/outgoingCalls --
    set("n", "grc", out_call, { buffer = buf })

    -- textDocument/codeAction --
    set("n", "gra", code_action, { buffer = buf })

    -- TODO: The code actions returned are based on the line scope provided. So asking for actions
    -- for the whole doc could produce different actions than the specific line
    -- grA could be a useful mapping for returning actions scoped to the whole doc. What else
    -- could be addressed?

    -- textDocument/codeLens --
    if client:supports_method("textDocument/codeLens") then
        ---@param lens_buf integer
        ---@param ns integer
        ---@param lnum integer
        ---@param chunks [string, string|integer?][]
        local function on_display(lens_buf, ns, lnum, chunks)
            api.nvim_buf_clear_namespace(lens_buf, ns, lnum, lnum + 1)
            if #chunks == 0 then
                return
            end

            ---@type integer
            local indent = api.nvim_buf_call(lens_buf, function()
                return fn.indent(lnum + 1)
            end)

            if indent > 0 then
                local indent_str = string.rep(" ", indent) ---@type string
                table.insert(chunks, 1, { indent_str, "" })
            end

            vim.api.nvim_buf_set_extmark(lens_buf, ns, lnum, 0, {
                virt_lines = { chunks },
                virt_lines_above = true,
                hl_mode = "replace", -- Default: 'combine'
            })
        end

        local buf_str = tostring(ev.buf) ---@type string
        local lens_group_name = "mjm-codelens-" .. buf_str ---@type string
        local lens_group = api.nvim_create_augroup(lens_group_name, {}) ---@type integer
        api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
            group = lens_group,
            buffer = ev.buf,
            callback = function()
                vim.lsp.codelens.refresh({
                    buf = buf,
                    display = { on_display = on_display },
                })
            end,
        })

        -- TODO: Under the new module, what happens when codelens.run() is executed with
        -- codelens disabled? My theory is mapping grl unconditionally could report the disabled
        -- status to the user and refer to the proper documentation
        -- vim.lsp.codelens.enable()
    end

    -- textDocument/declaration --
    set("n", "grd", declaration, { buffer = buf })
    set("n", "grD", peek_declaration, { buffer = buf })

    -- textDocument/definition --
    if client:supports_method("textDocument/definition") then
        set("n", "gd", definition, { buffer = buf })
        set("n", "gD", peek_definition, { buffer = buf })
    end

    -- textDocument/documentColor --
    set("n", "gro", function()
        local enabled = lsp.document_color.is_enabled() ---@type boolean
        lsp.document_color.enable(not enabled)
    end, { buffer = buf })

    set("n", "grO", lsp.document_color.color_presentation, { buffer = buf })

    -- textDocument/documentHighlight --
    set("n", "grh", lsp.buf.document_highlight, { buffer = buf })

    -- textDocument/documentSymbol --
    if client:supports_method("textDocument/documentSymbol") then
        set("n", "gO", symbols, { buffer = buf })
    end

    -- textDocument/hover --
    -- Default border now set with winborder

    -- textDocument/implementation --
    set("n", "gri", implementation, { buffer = buf })
    set("n", "grI", peek_implementation, { buffer = buf })

    -- textDocument/inlayHint --
    -- TODO: If grl becomes codelens, make this grx for inlay teXt
    if client:supports_method("textDocument/inlayHint") then
        set("n", "grl", function()
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
    set("n", "grr", references, { buffer = buf })
    set("n", "grR", peek_references, { buffer = buf })

    -- textDocument/rename --
    set("n", "grn", function()
        ---@type boolean, string
        local ok_i, input = require("mjm.utils").get_input("Rename: ")
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
    end, { buffer = buf })

    set("n", "grN", lsp.buf.rename, { buffer = buf })

    -- textDocument/semanticTokens
    if client:supports_method("textDocument/semanticTokens/full") then
        set("n", "grm", function()
            local enabled = lsp.semantic_tokens.is_enabled() ---@type boolean
            lsp.semantic_tokens.enable(not enabled)
        end, { buffer = buf })
    else
        map_no_support("grm", client, "textDocument/semanticTokens/full", buf)
    end

    -- textDocument/signatureHelp --
    -- Border supplied with winborder

    -- textDocument/typeDefinition --
    set("n", "grt", typedef, { buffer = buf })
    set("n", "grT", peek_typedef, { buffer = buf })

    -- typeHierarchy/subtypes --
    if client:supports_method("typeHierarchy/subtypes") then
        set("n", "grY", function()
            vim.lsp.buf.typehierarchy("subtypes")
        end, { buffer = buf })
    else
        map_no_support("grY", client, "typeHierarchy/subtypes", buf)
    end

    -- typeHierarchy/supertypes --
    if client:supports_method("typeHierarchy/supertypes") then
        set("n", "gry", function()
            vim.lsp.buf.typehierarchy("supertypes")
        end, { buffer = buf })
    else
        map_no_support("gry", client, "typeHierarchy/supertypes", buf)
    end

    -- workspace/symbol --
    set("n", "grw", workspace, { buffer = buf })
end

local lsp_group = vim.api.nvim_create_augroup("mjm-lsp", {}) ---@type integer
vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = set_lsp_maps,
})

vim.api.nvim_create_autocmd("LspDetach", {
    group = lsp_group,
    callback = function(ev)
        for _, client in ipairs(lsp.get_clients({ bufnr = ev.buf }) or {}) do
            if vim.tbl_isempty(vim.tbl_keys(client.attached_buffers)) then
                require("mjm.utils").do_when_idle(function()
                    client:stop()
                end)
            end
        end
    end,
})

lsp.log.set_level(vim.log.levels.ERROR)

-- FUTURE: PR: vim.lsp.start should be able to take a vim.lsp.Config table directly
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

    local start_opts = vim.deepcopy(opts, true) ---@type vim.lsp.start.Opts
    start_opts.bufnr = vim._resolve_bufnr(start_opts.bufnr) ---@type integer
    if api.nvim_get_option_value("buftype", { buf = start_opts.bufnr }) ~= "" then
        return
    end

    start_opts.reuse_client = config.reuse_client
    ---@diagnostic disable-next-line: invisible
    start_opts._root_markers = config.root_markers
    if type(config.root_dir) == "function" then
        config.root_dir(start_opts.bufnr, function(root_dir)
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

-- TODO: PR: Add an opt to rename to avoid filling in the default

-- MID: If you have an LSP, it should be possible to type something like grv and replace a variable
-- with its corresponding literal. I think rust-analyzer has this as a code action. Is there a more
-- generalizable way to do it
-- MID: It should be possible to send all occurrences of a symbol within a scope to the qflist or
-- something. documentHighlight detects this properly, so...

-- LOW: LspInfo is an alias for checkhealth vim.lsp, and there is a project to upstream cmds from
-- nvim-lspconfig to core. Unsure of where that will eventually land
-- LOW: For the split use case, FzfLua handles this well enough for it to not be worth worrying
-- about. Do want to look into how to use winnr as an input to open the result to a specific win

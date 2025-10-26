local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

local api = vim.api
local fn = vim.fn
local lsp = vim.lsp

local ok, fzflua = pcall(require, "fzf-lua") ---@type boolean, table
-- TODO: Check for rancher and use its copen if available
local function on_list(on_list_ctx)
    fn.setqflist({}, " ", { title = on_list_ctx.title, items = on_list_ctx.items })
    vim.cmd("botright copen")
end

-- callHierarchy/incomingCalls --
local in_call = ok and function()
    fzflua.lsp_incoming_calls({ jump1 = false })
end or lsp.buf.incoming_calls ---@type function

-- callHierarchy/outgoingCalls --
local out_call = ok and function()
    fzflua.lsp_incoming_calls({ jump1 = false })
end or lsp.buf.outgoing_calls ---@type function

-- textDocument/codeAction --
local code_action = ok and fzflua.lsp_code_actions or lsp.buf.code_action ---@type function

-- textDocument/declaration --
local declaration = ok and fzflua.lsp_declarations or lsp.buf.declaration ---@type function
local peek_declaration = ok and function()
    fzflua.lsp_declarations({ jump1 = false })
end or function()
    lsp.buf.declaration({ on_list = on_list })
end ---@type function

-- textDocument/definition --
local definition = ok and fzflua.lsp_definitions or lsp.buf.definition
local peek_definition = ok and function()
    fzflua.lsp_definitions({ jump1 = false })
end or function()
    lsp.buf.definition({ on_list = on_list })
end ---@type function

-- textDocument/documentSymbol --
local symbols = ok and fzflua.lsp_document_symbols or lsp.buf.document_symbol ---@type function

-- textDocument/implementation --
local implementation = ok and fzflua.lsp_implementations or lsp.buf.implementation
local peek_implementation = ok and function()
    fzflua.lsp_implementations({ jump1 = false })
end or function()
    lsp.buf.implementation({ on_list = on_list })
end ---@type function

-- textDocument/references --
local references = ok and function()
    fzflua.lsp_references({ includeDeclaration = false })
end or function()
    lsp.buf.references({ includeDeclaration = false })
end ---@type function

-- TODO: Check for rancher and use its copen if available
-- PR: on_list should be consistent with the other functions
local peek_references = ok
        and function()
            fzflua.lsp_references({ includeDeclaration = false, jump1 = false })
        end
    or function()
        lsp.buf.references({
            includeDeclaration = false,
            on_list = function(list)
                fn.setqflist({}, " ", list)
                vim.cmd("botright copen")
            end,
        })
    end ---@type function

-- textDocument/typeDefinition --
local typedef = ok and fzflua.lsp_typedefs or lsp.buf.type_definition
local peek_typedef = ok and function()
    fzflua.lsp_typedefs({ jump1 = false })
end or function()
    lsp.buf.type_definition({
        on_list = on_list,
    })
end ---@type function

-- workspace/symbol --
local workspace = ok and fzflua.lsp_live_workspace_symbols or lsp.buf.workspace_symbol

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
    local function start_codelens(bufnr)
        -- Lens updates are throttled so only one runs at a time. Updating on text change
        -- increases the likelihood of lenses rendering with stale data
        vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
            buffer = bufnr,
            group = vim.api.nvim_create_augroup("mjm-refresh-lens", { clear = true }),
            -- Bespoke module so I can render the lenses as virtual lines
            callback = function()
                require("mjm.codelens").refresh({ buf = ev.buf })
            end,
        })
    end

    local function stop_codelens()
        api.nvim_del_augroup_by_name("mjm-refresh-lens")
        -- Use bespoke module because that's where the caches are
        require("mjm.codelens").clear()
    end

    local function restart_codelens()
        local clients = lsp.get_clients() ---@type vim.lsp.Client[]
        for _, c in ipairs(clients) do
            if c:supports_method("textDocument/codeLens") then
                local attached_bufs = c.attached_buffers ---@type table<integer, true>
                for k, v in pairs(attached_bufs) do
                    if v then start_codelens(k) end
                end
            end
        end
    end

    -- TODO: This doesn't work because new bufs create new autocmds. Needs to be global state
    -- on this. Just hack it or actually modify the module?
    local function toggle_codelens()
        ---@type boolean, vim.api.keyset.get_autocmds.ret[]
        local a_ok, autocmds = pcall(api.nvim_get_autocmds, { group = "mjm-refresh-lens" })
        if a_ok and #autocmds > 0 then
            stop_codelens()
        else
            restart_codelens()
        end
    end

    -- TODO: Turn this back on when needed
    -- if client:supports_method("textDocument/codeLens") then start_codelens(ev.buf) end

    -- Use bespoke module because the lenses are cached there
    vim.keymap.set("n", "grs", toggle_codelens)
    vim.keymap.set("n", "grS", require("mjm.codelens").run)

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
    vim.keymap.set("n", "gO", symbols, { buffer = buf })

    -- textDocument/hover --
    -- LOW: This is set in runtime/lua/lsp.lua _set_defaults
    -- This would need to be undone either by overwriting the function or by putting in a PR for
    -- options to customize
    -- Low value since I can just overwrite default K and conform can set its formatexpr
    vim.keymap.set("n", "K", function()
        lsp.buf.hover({ border = Border })
    end, { buffer = buf })

    -- textDocument/implementation --
    vim.keymap.set("n", "gri", implementation)
    vim.keymap.set("n", "grI", peek_implementation, { buffer = buf })

    -- textDocument/inlayHint --
    vim.keymap.set("n", "grl", function()
        lsp.inlay_hint.enable(not lsp.inlay_hint.is_enabled({ buffer = buf }))
    end)

    -- textDocument/linkedEditingRange

    -- the docs recommend trying with html:
    -- if client:supports_method("textDocument/linkedEditingRange") then
    --     vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
    -- end

    -- textDocument/references --
    vim.keymap.set("n", "grr", references, { buffer = buf })
    vim.keymap.set("n", "grR", peek_references, { buffer = buf })

    -- textDocument/rename --

    -- LOW: Would like a way of having an incremental rename preview for LSP renames.
    -- The plugin, from what I can tell, does a full re-implementation of rename,
    -- which I don't want

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

    -- textDocument/signatureHelp --
    vim.keymap.set({ "i", "s" }, "<C-S>", function()
        lsp.buf.signature_help({ border = Border })
    end, { buffer = buf })

    -- textDocument/typeDefinition --
    vim.keymap.set("n", "grt", typedef, { buffer = buf })
    if client:supports_method("textDocument/typeDefinition") then
        vim.keymap.set("n", "grT", peek_typedef, { buffer = buf })
    else
        local msg = "LSP Server does not have capability textDocument/typeDefinition"
        vim.keymap.set("n", "grT", function()
            api.nvim_echo({ { msg, "" } }, true, {})
        end)
    end

    -- workspace/symbol --
    -- Kickstart mapping
    vim.keymap.set("n", "grw", workspace, { buffer = buf })

    -- Other --
    -- LOW: Which lsp method is Semantic token behind, because there are like three of them
    vim.keymap.set("n", "grm", function()
        lsp.semantic_tokens.enable(not lsp.semantic_tokens.is_enabled())
    end, { buffer = buf })

    vim.keymap.set("n", "grf", function()
        print(vim.inspect(lsp.buf.list_workspace_folders()))
    end, { buffer = buf })
end

local lsp_group = vim.api.nvim_create_augroup("lsp-autocmds", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = function(ev)
        set_lsp_maps(ev)
    end,
})

-- PR: Should be "attached_bufs"
-- There's a Neovim issue/discussion on removing "buffer" names from the code, but unsure where
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

-- Configs are in after/lsp
lsp.enable({
    --- Bash --
    "bashls",
    --- Go ---
    "golangci_lint_ls",
    "gopls",
    --- HTML/CSS ---
    "cssls",
    "html",
    --- Lua ---
    -- LOW: Look into emmylua
    "lua_ls",
    --- Python ---
    -- Ruff is not feature-complete enough to replace pylsp
    "pylsp",
    "ruff",
    --- Rust ---
    "rust_analyzer",
    --- Toml ---
    "taplo",
})

-- TODO: Friction point coming up where sometimes I want to send the results of the get_locations
-- cmd to a list, and sometimes to FzfLua. Some of this I think is based on, because I have
-- Rancher made, I'm more interested in using it, regardless of what is objectively better. I
-- think that making both options available could work, but sucks up the namespace. I also think
-- the maps should push toward what's the more efficient solution
-- Partly command dependent. goto definition works well with FzfLua because, if there are
-- multiple definitions, we want to preview them to see which one is best. references might work
-- better with the qflist, because we need to go through each of them. But I think that defining
-- different behavior per cmd is over-complicated
-- More indirect solution - Issue might be that <C-q> for quickfix in FzfLua is cumbersome. But
-- <C-u> us remove line and <C-c> is close. Not really a better place for it
-- Too early to make decision

-- MID: Get a C LSP for reading code

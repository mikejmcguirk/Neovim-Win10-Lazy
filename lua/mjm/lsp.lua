local api = vim.api
local lsp = vim.lsp
local set = vim.keymap.set

lsp.log.set_level(vim.log.levels.ERROR)

set("n", "gr", "<nop>")
-- Don't undo <C-s> signature help default. I have nothing to add to it.
local lsp_map_defaults = { "gra", "gri", "grn", "grr", "grt", "grx", "gO" }
for _, map in ipairs(lsp_map_defaults) do
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
        vim.lsp.codelens.enable()
        set("n", "grx", vim.lsp.codelens.run, { buf = buf })
    end
    -- MID: Unsure how either `unable` or `run` handle LSPs that don't support codeLens.

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
    -- MID:DEP: Use grh to toggle this if it becomes annoying.

    -- textDocument/documentSymbol --
    -- Check method support because this masks a Vim default.
    if client:supports_method("textDocument/documentSymbol") then
        set("n", "gO", function()
            require("fzf-lua").lsp_document_symbols()
        end, { buf = buf })
    end

    -- textDocument/hover --
    -- Default border now set with winborder

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
        set("n", "grl", function()
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
            jump1_action = fzf_lua.actions.file_vsplit,
        })
    end)

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
            vim.lsp.buf.typehierarchy("subtypes")
        end, { buf = buf })
    end

    -- typeHierarchy/supertypes --
    if client:supports_method("typeHierarchy/supertypes") then
        set("n", "gry", function()
            vim.lsp.buf.typehierarchy("supertypes")
        end, { buf = buf })
    end

    -- workspace/symbol --
    set("n", "grw", function()
        require("fzf-lua").lsp_live_workspace_symbols()
    end, { buf = buf })
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

        if not next(client.attached_buffers) then
            client:stop()
        end
    end),
})

-- MID: Make textDocument/documentLink work.
-- - Tough because the default `gx` mapping handles so many things.
-- MID: If you have an LSP, it should be possible to type something like grv and replace a variable
-- with its corresponding literal. I think rust-analyzer has this as a code action. Is there a more
-- generalizable way to do it
-- MID: "Find under cursor" function. If no LSP, then it gets the current cword and finds all
-- instances of it in the current buffer. If an LSP is attached, it uses documentHighlight to
-- get the locations then pipes those to fzf-lua or the location list.
-- - Neovim includes a "symbols_to_items" function that might be useful
-- - This idea can also be expanded to [w]w navigation based on the current word/symbol. But
-- this then prompts a re-evaluation of having spell mapped to `w`. Which then prompts a
-- re-evaluation of the `s` TS text object. This might be a case where, like conditionals and
-- diagnostic jumping, conditional-specific bracket nav is not useful enough to justify the
-- move mapping. TS incremental selection does a lot to alleviate pressure on TS Text Objects for
-- those kinds of selections. And bracket naving locals is something I've never done.
-- MID:DEP: You could do the keymaps as a table that are read and mapped when an LSP attaches, then
-- read and de-mapped if the last LSP is detached. Have not run into a use case where this is
-- necessary though.
-- MID: Bring back the "map_no_support" concept. Was removed because, if you have multiple LSPs,
-- it could map for the non-supporting LSP even though another one supports it. Should not be hard
-- to check other attached clients, but not immediate priority due to lack of use case.

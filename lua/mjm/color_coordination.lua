local hl_nop_all = {
    -- Can't eliminate at the token level because builtins and globals depend on it
    ["@lsp.type.variable"] = {}, --- Default link to normal
}

for k, v in pairs(hl_nop_all) do
    vim.api.nvim_set_hl(0, k, v)
end

local ts_nop_all = function(hl_query)
    -- Doesn't capture injections, so just sits on top of comment
    hl_query.query:disable_capture("comment.documentation")

    -- Allow to default to normal
    hl_query.query:disable_capture("punctuation.delimiter")
    hl_query.query:disable_capture("variable")
    hl_query.query:disable_capture("variable.member")
    -- Without the LSP to analyze scope, this hl_group does not add value
    hl_query.query:disable_capture("variable.parameter")
end

---------
-- Lua --
---------

local hl_nop_lua = {
    -- Can't disable at the token level because it's the root of function globals
    ["@lsp.type.function.lua"] = {}, -- Default link to function
}

for k, v in pairs(hl_nop_lua) do
    vim.api.nvim_set_hl(0, k, v)
end

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("lua-disable-captures", { clear = true }),
    pattern = "lua",
    once = true,
    callback = function()
        local hl_query = vim.treesitter.query.get("lua", "highlights")
        if not hl_query then
            return
        end

        ts_nop_all(hl_query)

        hl_query.query:disable_capture("function") -- Confusing when functions are used as vars
        -- Don't need to distinguish function builtins
        hl_query.query:disable_capture("function.builtin")
        hl_query.query:disable_capture("module.builtin")
        hl_query.query:disable_capture("property")
        hl_query.query:disable_capture("punctuation.bracket")
    end,
})

local token_nop_lua = {
    "comment", -- Treesitter handles
    "method", -- Treesitter handles
    "property", -- Can just be fg
}

------------
-- Python --
------------

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("python-disable-captures", { clear = true }),
    pattern = "python",
    once = true,
    callback = function()
        local hl_query = vim.treesitter.query.get("python", "highlights")
        if not hl_query then
            return
        end

        hl_query.query:disable_capture("punctuation.bracket")
        hl_query.query:disable_capture("string.documentation") -- Just masks string
    end,
})

----------
-- Rust --
----------

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("rust-disable-captures", { clear = true }),
    pattern = "rust",
    once = true,
    callback = function()
        local hl_query = vim.treesitter.query.get("rust", "highlights")
        if not hl_query then
            return
        end

        -- Have to keep punctuation.bracket to mask operator highlights
        hl_query.query:disable_capture("type.builtin") -- Don't need to distinguish this
    end,
})

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("rust-disable-captures-lsp", { clear = true }),
    callback = function(ev)
        local ft = vim.api.nvim_get_option_value("filetype", { buf = ev.buf })

        if ft == "rust" then
            local hl_query = vim.treesitter.query.get("rust", "highlights")
            if not hl_query then
                return
            end

            -- rust_analyzer contains built-in highlights for multiple types that should be
            -- left active due to injected highlights in comments. If an LSP attaches, disable
            -- the TS queries
            hl_query.query:disable_capture("constant.builtin")
            hl_query.query:disable_capture("function")
            hl_query.query:disable_capture("function.call")
            hl_query.query:disable_capture("function.macro")
            hl_query.query:disable_capture("_identifier")
            hl_query.query:disable_capture("keyword.debug")
            hl_query.query:disable_capture("keyword.exception")
            hl_query.query:disable_capture("string")
            hl_query.query:disable_capture("type")

            vim.api.nvim_del_augroup_by_name("rust-disable-captures-lsp")
        end
    end,
})

local token_nop_rust = {
    "comment",
    "const",
    "namespace", --- Handle with custom TS queries
    "selfKeyword",
    "property", --- Default to Normal
}

------------
-- vimdoc --
------------

-- Run eagerly to avoid inconsistent preview window appearance
local vimdoc_query = vim.treesitter.query.get("vimdoc", "highlights")
if vimdoc_query then
    ts_nop_all(vimdoc_query)
end

----------------------------------
-- Setup Semantic Token Removal --
----------------------------------

local token_filder = {
    ["lua_ls"] = token_nop_lua,
    ["rust_analyzer"] = token_nop_rust,
} --- @type {string: string[]}

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("token-filter", { clear = true }),
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if (not client) or not client.server_capabilities.semanticTokensProvider then
            return
        end

        local found_client_name = false
        for k, _ in pairs(token_filder) do
            if k == client.name then
                found_client_name = true
                break
            end
        end

        if not found_client_name then
            return
        end

        local legend = client.server_capabilities.semanticTokensProvider.legend
        local new_tokenTypes = {}

        for _, typ in ipairs(legend.tokenTypes) do
            if not vim.tbl_contains(token_filder[client.name], typ) then
                table.insert(new_tokenTypes, typ)
            else
                -- The builtin semantic token handler checks the token names for truthiness
                -- Set to false to return a falsy value and skip position calculation, without
                -- mis-aligning the legend indexing
                table.insert(new_tokenTypes, false)
            end
        end

        legend.tokenTypes = new_tokenTypes
        vim.lsp.semantic_tokens.force_refresh(ev.buf)
    end,
})

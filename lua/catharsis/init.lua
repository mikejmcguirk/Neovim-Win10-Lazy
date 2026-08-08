local api = vim.api
-- TODO: When cutting this plugin off, inline any functions that are only used here. We want to
-- require as few exterior modules as possible for plugin init. Exterior util functions should be
-- consolidated into as few modules as is reasonable.
local ntt = require("nvim-tools.table")

---------------------------
-- MARK: Defaults/Schema --
---------------------------

local M = {}

---@class catharsis.config.Schema
local schema = {
    default_keymaps_set = "boolean",
    document_highlight = {
        enabled = "boolean",
        do_zzze = "boolean",
    },
    lampshade = {
        action_filter = "callable",
        display = "callable",
        debounce = "number",
    },
    rename = {
        filter = "callable",
        new_name = "string",
        prompt_default = "boolean",
    },
}

---@class catharsis.Config
local default_config = {
    default_keymaps_set = true, ---@type boolean
    ---@class catharsis.documentHighlight.Cfg
    document_highlight = {
        enabled = true, ---@type boolean
        -- TODO: Rename to do_zzze
        do_zzze = true, ---@type boolean -- For jumps.
    },
    ---@class catharsis.lampshade.Cfg
    lampshade = {
        ---Predicate function to determine valid actions. Return true to count as valid.
        ---@param client vim.lsp.Client
        ---@param action (lsp.Command|lsp.CodeAction)
        ---@return boolean
        ---@diagnostic disable-next-line: unused-local
        action_filter = function(_, _)
            return true
        end,
        debounce = 150, ---@type uinteger
        ---@param buf uinteger
        ---@param row uinteger 0-indexed
        ---@param ns uinteger
        ---@param hl_id uinteger Id for the "CatharsisLampshade" hl group.
        display = function(buf, row, ns, hl_id)
            api.nvim_buf_set_extmark(buf, ns, row, 0, {
                virt_text = { { "󰌶", hl_id } },
                priority = 1000,
                strict = false,
            })
        end,
    },
    ---@class catharsis.rename.Cfg
    rename = {
        ---(Default: `nil`) Predicate to filter clients. Clients matching the predicate are
        ---included.
        filter = nil, ---@type (fun(client:vim.lsp.Client): boolean)?
        ---(Default: `nil`) If provided, immediately send the rename request.
        new_name = nil, ---@type string?
        ---(Default: `true`) Provide a default name in the prompt? If true, the LSP suggestion
        ---will be used if provided, falling back to the |<cword>| under the cursor.
        prompt_default = true, ---@type boolean
    },
}

-- LOW: It would be better to calculate lamp debounce from the client fields.

---@return boolean, string
function M.__default_schema_check()
    return ntt.matches_schema(default_config, schema)
end

---@class catharsis.documentHighlight.Opts
---@field enabled? boolean
---@field do_zzze? boolean

---@class catharsis.lampshade.Opts
---@field action_filter? fun(client:vim.lsp.Client, action:(lsp.Command|lsp.CodeAction)): boolean
---@field debounce? uinteger
---@field display? fun(buf:uinteger, row:uinteger, ns:uinteger, hl_id:uinteger)

---@class catharsis.rename.Opts
---@field filter? (fun(client:vim.lsp.Client): boolean)?
---@field new_name? string?
---@field prompt_default? boolean

---@class catharsis.config.Partial
---@field default_keymaps_set? boolean
---@field lampshade? catharsis.lampshade.Opts
---@field rename? catharsis.rename.Opts
---@field document_highlight? catharsis.documentHighlight.Opts

------------------
-- MARK: Config --
------------------

local config = ntt.deepcopy(default_config)
---@cast config catharsis.Config

---@param new_config? catharsis.config.Partial
---@return catharsis.Config
function M.config(new_config)
    if new_config == nil then
        return ntt.deepcopy(config)
    end

    local ok, err = ntt.matches_schema(new_config, schema)
    if not ok then
        if vim.v.vim_did_enter == 1 then
            error(err)
        end

        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return ntt.deepcopy(config)
    end

    ntt.merge_deep_right(config, new_config)
    return ntt.deepcopy(config)
end

function M.config_reset()
    config = ntt.deepcopy(default_config)
end

---@param keys table
---@return catharsis.Config
function M.unset_keys(keys)
    vim.validate("keys", keys, "table")

    ntt.unset_keys(config, keys)
    local defaults_zipped = ntt.zip_deep_with_to(keys, default_config, function(_, dv)
        return dv
    end)

    ntt.defaults_deep(config, defaults_zipped)
    return ntt.deepcopy(config)
end

function M._config_get()
    return config
end

----------------------
-- MARK: Buf Config --
----------------------

local buf_configs = {} ---@type table<uinteger, catharsis.config.Partial>

local function get_buf_augroup_name(buf)
    return "catharsis.buf_config." .. tostring(buf)
end

---@param buf uinteger
---@return catharsis.config.Partial
local function buf_config_add(buf)
    api.nvim_create_autocmd("BufWipeout", {
        group = api.nvim_create_augroup(get_buf_augroup_name(buf), {}),
        -- TODO-DEP: Change this to "buf" when v0.14 comes out.
        buffer = buf,
        callback = function()
            buf_configs[buf] = nil
        end,
    })

    local buf_config = {}
    buf_configs[buf] = buf_config
    return buf_config
end

---@param buf uinteger
---@return catharsis.config.Partial
local function buf_config_get_or_create(buf)
    return buf_configs[buf] or buf_config_add(buf)
end

---@param new_config catharsis.config.Partial?
---@param buf? uinteger
---@return catharsis.config.Partial
function M.buf_config(new_config, buf)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint)
    vim.validate("new_config", new_config, "table", true)

    buf = buf ~= 0 and buf or api.nvim_get_current_buf()
    if not api.nvim_buf_is_valid(buf) then
        buf_configs[buf] = nil
        error(buf .. " is not valid")
    end

    local buf_config = buf_config_get_or_create(buf)
    if new_config == nil then
        return ntt.deepcopy(buf_config)
    end

    local ok, err = ntt.matches_schema(new_config, schema)
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
    else
        ntt.merge_deep_right(buf_config, new_config)
    end

    return ntt.deepcopy(buf_config)
end

---@param bufs uinteger[]|nil
function M.buf_config_clear(bufs)
    vim.validate("bufs", bufs, function()
        local nty = require("nvim-tools.types")
        return nty.valid_list(bufs, { item_type = "number" })
    end, true)

    if bufs == nil then
        for _, cfg in pairs(buf_configs) do
            ntt.clear(cfg)
        end

        return
    end

    for _, buf in ipairs(bufs) do
        local buf_config = buf_configs[buf]
        if buf_config ~= nil then
            ntt.clear(buf_config)
        end
    end
end

---@param buf uinteger
---@param keys table
---@return catharsis.config.Partial
function M.buf_config_unset_keys(buf, keys)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint)
    vim.validate("keys", keys, "table")

    buf = buf ~= 0 and buf or api.nvim_get_current_buf()
    if not api.nvim_buf_is_valid(buf) then
        buf_configs[buf] = nil
        error(buf .. " is not valid")
    end

    return ntt.deepcopy(ntt.unset_keys(buf_config_get_or_create(buf), keys))
end

---@return uinteger[]
function M.buf_config_list_bufs()
    local keys = ntt.keys(buf_configs)
    table.sort(keys)
    return keys
end

---@return uinteger[]
function M._buf_config_list_bufs_empty()
    return ntt.i_keep(M.buf_config_list_bufs(), function(buf)
        return next(buf_configs[buf]) == nil
    end)
end

-----------------------
-- MARK: API Helpers --
-----------------------

---@param buf uinteger
---@param usr_config table?
---@param ... any
---@return table
function M._config_merged_get(buf, usr_config, ...)
    local cfg = ntt.deepcopy(ntt.get(config, ...))
    if cfg == nil then
        error("Invalid config path")
    end

    buf = buf ~= 0 and buf or api.nvim_get_current_buf()
    local buf_config = buf_configs[buf]
    if buf_config ~= nil then
        local buf_cfg = ntt.get(buf_config, ...)
        if buf_cfg ~= nil then
            ntt.merge_deep_right(cfg, buf_cfg)
        end
    end

    if usr_config == nil then
        return cfg
    end

    local sub_schema = ntt.get(schema, ...)
    local ok, err = ntt.matches_schema(usr_config, sub_schema)
    if not ok then
        error(err)
    end

    ntt.merge_deep_right(cfg, usr_config)
    return cfg
end

---@param win uinteger
---@param ... any
---@return uinteger, uinteger, table
function M._config_merged_from_win(win, ...)
    win = win ~= 0 and win or api.nvim_get_current_win()
    local buf = api.nvim_win_get_buf(win)
    return win, buf, M._config_merged_get(buf, nil, ...)
end

---@param opts table?
---@param key string
---@return uinteger, uinteger, table
local function cfg_get_from_opts(opts, key)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local win = api.nvim_get_current_win()
    local buf = api.nvim_win_get_buf(win)
    return win, buf, M._config_merged_get(buf, opts, key)
end

---------------
-- MARK: API --
---------------

---Rename all references to the symbol under the cursor. Highlight changed symbols.
---@param opts? catharsis.rename.Opts
function M.rename(opts)
    local cur_win, cur_buf, cfg = cfg_get_from_opts(opts, "rename")
    require("catharsis._rename")._dispatcher(cur_win, cur_buf, cfg)
end

---@nodoc
M.document_highlight = {}

---@param opts? catharsis.documentHighlight.Opts
function M.document_highlight.jump_fwd(opts)
    local win, buf, cfg = cfg_get_from_opts(opts, "document_highlight")
    require("catharsis._document_highlight").jump(win, buf, vim.v.count, false, false, cfg)
end

---@param opts? catharsis.documentHighlight.Opts
function M.document_highlight.jump_rev(opts)
    local win, buf, cfg = cfg_get_from_opts(opts, "document_highlight")
    require("catharsis._document_highlight").jump(win, buf, vim.v.count, false, true, cfg)
end

---@param opts? catharsis.documentHighlight.Opts
function M.document_highlight.jump_last(opts)
    local win, buf, cfg = cfg_get_from_opts(opts, "document_highlight")
    require("catharsis._document_highlight").jump(win, buf, vim.v.count, true, false, cfg)
end

---@param opts? catharsis.documentHighlight.Opts
function M.document_highlight.jump_first(opts)
    local win, buf, cfg = cfg_get_from_opts(opts, "document_highlight")
    require("catharsis._document_highlight").jump(win, buf, vim.v.count, true, true, cfg)
end

return M

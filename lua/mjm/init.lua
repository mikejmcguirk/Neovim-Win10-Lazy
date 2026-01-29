local api = vim.api
local set = vim.keymap.set

_G.mjm = {}

local gen_lcs = "extends:»,precedes:«,nbsp:␣,trail:⣿"
_G.Mjm_Lcs = "tab:<->," .. gen_lcs
_G.Mjm_Lcs_Tab = "tab:   ," .. gen_lcs
_G.Mjm_Sw = 4

_G.Has_Nerd_Font = true
-- LOW: Create a more general defer require. Look at all of tj's funcs + vim._defer_require
-- Needs to work with LSP autocomplete. Maybe vim._defer_require addresses this
-- https://github.com/tjdevries/lazy-require.nvim/blob/master/lua/lazy-require.lua
---@param path string
---@return table
function _G.Mjm_Defer_Require(path)
    return setmetatable({}, {
        __index = function(_, key)
            return require(path)[key]
        end,
        __newindex = function(_, key, value)
            require(path)[key] = value
        end,
    })
end

mjm.opt = {}

---@param opt string
---@param new string
---@param scope vim.api.keyset.option
function mjm.opt.str_append(opt, new, scope)
    local old = api.nvim_get_option_value(opt, scope) ---@type string
    if string.find(old, new, 1, true) ~= nil then
        return
    end

    local new_val = old .. new ---@type string
    api.nvim_set_option_value(opt, new_val, scope)
end

---@param opt string
---@param out string
---@param scope vim.api.keyset.option
function mjm.opt.str_rm(opt, out, scope)
    local old = api.nvim_get_option_value(opt, scope) ---@type string
    local new_val = string.gsub(old, out, "") ---@type string
    api.nvim_set_option_value(opt, new_val, scope)
end

set({ "n", "x" }, "<Space>", "<Nop>")
set({ "n", "x" }, "\\", "<Nop>")
api.nvim_set_var("mapleader", " ")
api.nvim_set_var("maplocalleader", "\\")

-- See :h <tab> and https://github.com/neovim/neovim/pull/17932
set("n", "<C-i>", "<C-i>")
set("n", "<tab>", "<tab>")
set("n", "<C-m>", "<C-m>")
set("n", "<cr>", "<cr>")
set("n", "<C-[>", "<C-[>")
set("n", "<esc>", "<esc>")

api.nvim_set_var("no_plugin_maps", 1)

-- Get these before lazy.nvim runs
-- :h standard-plugin-list
api.nvim_set_var("loaded_2html_plugin", 1)
api.nvim_set_var("did_install_default_menus", 1)
api.nvim_set_var("loaded_gzip", 1)
api.nvim_set_var("loaded_man", 1)
api.nvim_set_var("loaded_matchit", 1)
api.nvim_set_var("loaded_matchparen", 1)
api.nvim_set_var("loaded_netrw", 1)
api.nvim_set_var("loaded_netrwPlugin", 1)
api.nvim_set_var("loaded_netrwSettings", 1)
api.nvim_set_var("loaded_remote_plugins", 1)
api.nvim_set_var("loaded_spellfile_plugin", 1)
api.nvim_set_var("loaded_tar", 1)
api.nvim_set_var("loaded_tarPlugin", 1)
api.nvim_set_var("loaded_tutor_mode_plugin", 1)
api.nvim_set_var("loaded_zip", 1)
api.nvim_set_var("loaded_zipPlugin", 1)

local termfeatures = vim.g.termfeatures or {}
termfeatures.osc52 = false -- I use xsel
api.nvim_set_var("termfeatures", termfeatures)

require("mjm.colorscheme")

require("mjm.lazy")
require("mjm.internal")
require("mjm.undotree")
require("mjm.difftool")

require("mjm.set")
require("mjm.autocmd")
require("mjm.map")
require("mjm.custom-cmds")
require("mjm.stl")
require("mjm.diagnostics")
require("mjm.ts-tools")
require("mjm.tal")

require("mjm.lsp")

if not api.nvim_buf_is_valid(1) then
    return
end
local ut = require("mjm.utils")
if not ut.is_empty_noname_buf(1) then
    return
end
api.nvim_create_autocmd("BufHidden", {
    buffer = 1,
    callback = function()
        if ut.is_empty_noname_buf(1) then
            vim.schedule(function()
                api.nvim_buf_delete(1, { force = true })
            end)
        end
    end,
})

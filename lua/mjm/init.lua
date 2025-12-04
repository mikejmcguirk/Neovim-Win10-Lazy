local api = vim.api
local set = vim.keymap.set

_G.mjm = {}
_G.Has_Nerd_Font = true
_G.Mjm_Scrolloff = 6 ---@type integer
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

require("mjm.colorscheme")

require("mjm.lazy")
require("mjm.undotree")
require("mjm.difftool")
require("mjm.plugins.spec-ops")
require("mjm.plugins.specialist")

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
        if not ut.is_empty_noname_buf(1) then
            return
        end
        vim.schedule(function()
            api.nvim_buf_delete(1, { force = true })
        end)
    end,
})

local api = vim.api
local set = vim.keymap.set

_G.Mjm_Border = "single" ---@type string
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

set({ "n", "x" }, "<Space>", "<Nop>")
api.nvim_set_var("mapleader", " ")
-- LOW: Ideas:
-- - "\" - Used for settings
-- - "`" - Might be better used for case operations
-- - <bs> - Has a lot of semantic connotation
-- Use case: Alleviates leader namespace cramping. Conform, for example, could be local leader
api.nvim_set_var("maplocalleader", " ")

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

local api = vim.api
local set = vim.keymap.set

local M = {}

---@type vim.diagnostic.Opts
local diag_main_cfg = { float = { source = true }, severity_sort = true }

---@type vim.diagnostic.Opts
local virt_text_cfg = { virtual_lines = false, virtual_text = { current_line = true } }

---@type vim.diagnostic.Opts
local virt_lines_cfg = { virtual_lines = { current_line = true }, virtual_text = false }

local diag_text_cfg = vim.tbl_deep_extend("force", diag_main_cfg, virt_text_cfg)
local diag_lines_cfg = vim.tbl_deep_extend("force", diag_main_cfg, virt_lines_cfg)
vim.diagnostic.config(diag_text_cfg)

M.toggle_virt_lines = function()
    local cur_cfg = vim.diagnostic.config() or {}
    vim.diagnostic.config(cur_cfg.virtual_lines and diag_text_cfg or diag_lines_cfg)
end

set("n", "[<C-d>", function()
    local severity = require("mjm.utils").get_top_severity({ buf = 0 })
    vim.diagnostic.jump({ count = -vim.v.count1, severity = severity })
end)

set("n", "]<C-d>", function()
    local severity = require("mjm.utils").get_top_severity({ buf = 0 })
    vim.diagnostic.jump({ count = vim.v.count1, severity = severity })
end)

set("n", "[<M-d>", function()
    local severity = require("mjm.utils").get_top_severity({ buf = 0 })
    vim.diagnostic.jump({ count = -vim._maxint, severity = severity, wrap = false })
end)

set("n", "]<M-d>", function()
    local severity = require("mjm.utils").get_top_severity({ buf = 0 })
    vim.diagnostic.jump({ count = vim._maxint, severity = severity, wrap = false })
end)

-- Because I create custom caching in stl.lua
-- Do here, after diagnostic setup, to ensure no issues when bisecting config
api.nvim_del_augroup_by_name("nvim.diagnostic.status")

return M

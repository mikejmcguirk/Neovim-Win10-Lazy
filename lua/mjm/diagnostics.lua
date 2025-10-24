local ut = Mjm_Defer_Require("mjm.utils")

local api = vim.api

---@class MjmDiags
local M = {}

---@type vim.diagnostic.Opts
local diag_main_cfg = { float = { source = true, border = Border }, severity_sort = true }

---@type vim.diagnostic.Opts
local virt_text_cfg = { virtual_lines = false, virtual_text = { current_line = true } }

---@type vim.diagnostic.Opts
local virt_lines_cfg = { virtual_lines = { current_line = true }, virtual_text = false }

local diag_text_cfg = vim.tbl_extend("force", diag_main_cfg, virt_text_cfg)
local diag_lines_cfg = vim.tbl_extend("force", diag_main_cfg, virt_lines_cfg)
vim.diagnostic.config(diag_text_cfg)

M.toggle_diags = function()
    vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end

M.toggle_virt_lines = function()
    local cur_cfg = vim.diagnostic.config() or {}
    vim.diagnostic.config((not cur_cfg.virtual_lines) and diag_lines_cfg or diag_text_cfg)
end

-- MID: Redo diagnostic top severity to be the way I have it in Rancher. Fixes fixes double pull

-- Default [D/]D cause my computer to lockup
local function get_first_or_last_diag(opts)
    opts = opts or {}
    local diagnostics = opts.severity and vim.diagnostic.get(0, { severity = opts.severity })
        or vim.diagnostic.get(0)

    if #diagnostics == 0 then
        api.nvim_echo({ { "No diagnostics in current buffer", "" } }, false, {})
        return
    end

    table.sort(diagnostics, function(a, b)
        if a.lnum ~= b.lnum then
            return a.lnum < b.lnum
        elseif a.severity ~= b.severity then
            return a.severity < b.severity
        elseif a.end_lnum ~= b.end_lnum then
            return a.end_lnum < b.end_lnum
        elseif a.col ~= b.col then
            return a.col < b.col
        else
            return a.end_col < b.end_col
        end
    end)

    return opts.last and diagnostics[#diagnostics] or diagnostics[1]
end

Map("n", "[D", function()
    local diagnostic = get_first_or_last_diag()
    if diagnostic then vim.diagnostic.jump({ diagnostic = diagnostic }) end
end)

Map("n", "]D", function()
    local diagnostic = get_first_or_last_diag({ last = true })
    if diagnostic then vim.diagnostic.jump({ diagnostic = diagnostic }) end
end)

Map("n", "[<C-d>", function()
    vim.diagnostic.jump({ count = -vim.v.count1, severity = ut.get_top_severity({ buf = 0 }) })
end)

Map("n", "]<C-d>", function()
    vim.diagnostic.jump({ count = vim.v.count1, severity = ut.get_top_severity({ buf = 0 }) })
end)

Map("n", "[<M-d>", function()
    local diagnostic = get_first_or_last_diag({ severity = ut.get_top_severity({ buf = 0 }) })
    if diagnostic then vim.diagnostic.jump({ diagnostic = diagnostic }) end
end)

Map("n", "]<M-d>", function()
    local severity = ut.get_top_severity({ buf = 0 })
    local diagnostic = get_first_or_last_diag({ severity = severity, last = true })
    if diagnostic then vim.diagnostic.jump({ diagnostic = diagnostic }) end
end)

-- Because I create custom caching in stl.lua
-- Do here, after diagnostic setup, to ensure no issues when bisecting config
vim.api.nvim_del_augroup_by_name("nvim.diagnostic.status")

return M

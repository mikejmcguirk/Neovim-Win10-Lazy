-- FUTURE: Worth exploring mrcjkb/rustaceanvim and rust-lang/rust.vim
-- The former unlocks more features of rust-analyzer, the latter does some basic formatting

Map("i", ";", ";<C-g>u", { silent = true })
local ut = require("mjm.utils")

---@param pragma string
---@return nil
local add_pragma = function(pragma)
    local line = vim.api.nvim_get_current_line() ---@type string
    if not line:match("^%s*$") then return vim.notify("Line is not blank") end

    local row_1 = vim.api.nvim_win_get_cursor(0)[1] ---@type integer
    local row_0 = row_1 - 1
    local indent = ut.get_indent(row_1) or 0 ---@type integer
    local padding = string.rep(" ", indent) ---@type string
    vim.api.nvim_buf_set_text(0, row_0, 0, row_0, #line, { padding .. pragma })

    line = vim.api.nvim_get_current_line() ---@type string
    local line_len_0 = #line - 1
    vim.api.nvim_win_set_cursor(0, { row_1, line_len_0 - 1 })
    vim.cmd("startinsert")
end

Map({ "n", "i" }, "<C-->d", function() add_pragma("#[derive()]") end)
Map({ "n", "i" }, "<C-->c", function() add_pragma("#[cfg()]") end)
Map({ "n", "i" }, "<C-->a", function() add_pragma("#[allow()]") end)
Map({ "n", "i" }, "<C-->e", function() add_pragma("#[expect()]") end)

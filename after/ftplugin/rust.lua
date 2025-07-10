-- Formatted with Conform (2025-07-07)

-- TODO: Worth exploring mrcjkb/rustaceanvim and rust-lang/rust.vim
-- The former unlocks more features of rust-analyzer, the latter does some basic formatting

vim.keymap.set("i", ";", ";<C-g>u", { silent = true })
local ut = require("mjm.utils")

---@param pragma string
---@return nil
local add_pragma = function(pragma)
    local line = vim.api.nvim_get_current_line() ---@type string
    if not line:match("^%s*$") then
        vim.notify("Line is not blank")
        return
    end

    local row_one = vim.api.nvim_win_get_cursor(0)[1] ---@type integer
    local row_zero = row_one - 1
    local indent = ut.get_indent(row_one) ---@type integer
    local padding = string.rep(" ", indent) ---@type string
    vim.api.nvim_buf_set_text(0, row_zero, 0, row_zero, 0, { padding .. pragma })

    line = vim.api.nvim_get_current_line() ---@type string
    local line_len_zero = #line - 1
    vim.api.nvim_win_set_cursor(0, { row_one, line_len_zero - 1 })
    vim.cmd("startinsert")
end

vim.keymap.set("n", "--d", function()
    add_pragma("#[derive()]")
end)
vim.keymap.set("n", "--c", function()
    add_pragma("#[cfg()]")
end)
vim.keymap.set("n", "--a", function()
    add_pragma("#[allow()]")
end)
vim.keymap.set("n", "--e", function()
    add_pragma("#[expect()]")
end)

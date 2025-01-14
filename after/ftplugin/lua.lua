local ut = require("mjm.utils")

---@param annotation string
---@return nil
local function add_annotation(annotation)
    local row = vim.api.nvim_win_get_cursor(0)[1] ---@type integer
    local line = vim.api.nvim_get_current_line()
    local line_len = #line ---@type integer

    if line:match("^%s*$") then
        local indent = ut.get_indent(row) ---@type integer
        local padding = string.rep(" ", indent) ---@type string
        vim.api.nvim_buf_set_text(0, row - 1, 0, row - 1, 0, { padding .. annotation .. " " })
    elseif line:match("%s$") then
        vim.api.nvim_buf_set_text(0, row - 1, line_len, row - 1, line_len, { annotation .. " " })
    else
        vim.api.nvim_buf_set_text(
            0,
            row - 1,
            line_len,
            row - 1,
            line_len,
            { " " .. annotation .. " " }
        )
    end
    vim.cmd("startinsert!")
end

vim.keymap.set("n", "--t", function()
    add_annotation("---@type")
end, { buffer = true })
vim.keymap.set("n", "--p", function()
    add_annotation("---@param")
end, { buffer = true })
vim.keymap.set("n", "--r", function()
    add_annotation("---@return")
end, { buffer = true })
vim.keymap.set("n", "--d", function()
    add_annotation("---@diagnostic")
end, { buffer = true })
vim.keymap.set("n", "--f", function()
    add_annotation("---@field")
end, { buffer = true })
vim.keymap.set("n", "--a", function()
    add_annotation("---[[@as")
end, { buffer = true })

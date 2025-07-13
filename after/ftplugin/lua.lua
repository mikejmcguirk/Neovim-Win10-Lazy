local ut = require("mjm.utils")

---@param annotation string
---@return nil
local function add_annotation(annotation)
    local row_1 = vim.api.nvim_win_get_cursor(0)[1] ---@type integer
    local row_0 = row_1 - 1
    local line = vim.api.nvim_get_current_line()
    local line_len = #line ---@type integer

    if line:match("^%s*$") then -- All whitespace
        local indent = ut.get_indent(row_1) ---@type integer
        local padding = string.rep(" ", indent) ---@type string
        vim.api.nvim_buf_set_text(0, row_0, 0, row_0, 0, { padding .. annotation .. " " })
    elseif line:match("%s$") then -- Non-whitespace with trailing whitespace
        vim.api.nvim_buf_set_text(0, row_0, line_len, row_0, line_len, { annotation .. " " })
    else -- Non-whitespace, needs trailing whitespace added
        local new_text = " " .. annotation .. " " ---@type string
        vim.api.nvim_buf_set_text(0, row_0, line_len, row_0, line_len, { new_text })
    end

    vim.cmd("startinsert!")
end

vim.keymap.set("n", "---", function()
    add_annotation("--")
end, { buffer = true })

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

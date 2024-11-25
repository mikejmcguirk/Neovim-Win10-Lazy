---@param annotation string
---@return nil
local function add_annotation(annotation)
    local buf = vim.api.nvim_get_current_buf() ---@type integer
    local row = vim.api.nvim_win_get_cursor(0)[1] ---@type integer
    local line = vim.api.nvim_get_current_line()
    local line_len = #line ---@type integer

    if line:match("^%s*$") then
        vim.api.nvim_buf_set_text(buf, row - 1, 0, row - 1, 0, { annotation .. " " })
    elseif line:match("%s$") then
        vim.api.nvim_buf_set_text(buf, row - 1, line_len, row - 1, line_len, { annotation .. " " })
    else
        vim.api.nvim_buf_set_text(
            buf,
            row - 1,
            line_len,
            row - 1,
            line_len,
            { " " .. annotation .. " " }
        )
    end
    vim.cmd("startinsert!")
end

vim.keymap.set("n", "--T", function()
    add_annotation("---@type")
end, { buffer = true })
vim.keymap.set("n", "--P", function()
    add_annotation("---@param")
end, { buffer = true })
vim.keymap.set("n", "--R", function()
    add_annotation("---@return")
end, { buffer = true })
vim.keymap.set("n", "--D", function()
    add_annotation("---@diagnostic")
end, { buffer = true })
vim.keymap.set("n", "--F", function()
    add_annotation("---@field")
end, { buffer = true })
vim.keymap.set("n", "--A", function()
    add_annotation("---[[@as")
end, { buffer = true })

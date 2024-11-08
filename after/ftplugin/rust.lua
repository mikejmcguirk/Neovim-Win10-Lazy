---@param row number
---@param col number
---@return boolean
local validate_node = function(row, col)
    local parser = vim.treesitter.get_parser(0, "rust")
    if not parser then
        vim.notify("Treesitter parser not available for Rust", vim.log.levels.WARN)
        return false
    end

    local tree = parser:parse()[1]
    local node = tree:root():descendant_for_range(row - 1, col, row - 1, col)
    local node_type = node and node:type() or ""
    local parent_node = node and node:parent()
    local parent_type = parent_node and parent_node:type() or ""

    local bad_node = node_type == "string_literal" or node_type == "comment"
    local bad_parent = parent_type == "string_literal" or parent_type == "comment"

    if bad_node or bad_parent then
        return false
    end
    return true
end

---@return nil
local function insert_matching_lt()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    if not validate_node(row, col) then
        vim.api.nvim_put({ "<" }, "c", false, true)
        return
    end

    vim.api.nvim_put({ "<>" }, "c", false, true)
    vim.api.nvim_win_set_cursor(0, { row, col + 1 })
end

vim.keymap.set("i", "<", insert_matching_lt, { buffer = true })

---@return nil
local function check_matching_lt()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    if not validate_node(row, col) then
        vim.api.nvim_put({ ">" }, "c", true, true)
        return
    end

    local line = vim.api.nvim_get_current_line()
    local next_char = line:sub(col + 1, col + 1)
    if not next_char or next_char ~= ">" then
        vim.api.nvim_put({ ">" }, "c", false, true)
        return
    end
    local prev_char = line:sub(col - 1, col - 1)
    if prev_char == "<" then
        vim.api.nvim_win_set_cursor(0, { row, col + 1 })
        return
    end

    local open_count = 0
    local close_count = 0
    for i = 1, col + 1 do
        local char = line:sub(i, i)
        if char == "<" then
            open_count = open_count + 1
        elseif char == ">" then
            close_count = close_count + 1
        end
    end

    if open_count == close_count then
        vim.api.nvim_win_set_cursor(0, { row, col + 1 })
        return
    end

    vim.api.nvim_put({ ">" }, "c", false, true)
end

vim.keymap.set("i", ">", check_matching_lt, { buffer = true })

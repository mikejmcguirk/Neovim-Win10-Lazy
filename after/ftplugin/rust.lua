---@param row number
---@param col number
---@param root_lang_tree vim.treesitter.LanguageTree
---@return TSNode|nil, TSTree|nil, vim.treesitter.LanguageTree
local get_root_for_position = function(row, col, root_lang_tree)
    ---@type vim.treesitter.LanguageTree
    local lang_tree = root_lang_tree:language_for_range({ row, col, row, col })

    for _, tree in pairs(lang_tree:trees()) do
        local root = tree:root() ---@type TSNode
        if root and vim.treesitter.is_in_node_range(root, row, col) then
            return root, tree, lang_tree
        end
    end

    return nil, nil, lang_tree
end

---@param row number
---@param col number
---@return TSNode | nil
local get_node_at_cursor = function(row, col)
    local buf = vim.api.nvim_win_get_buf(0) ---@type integer
    ---@type boolean, vim.treesitter.LanguageTree
    local ok, root_lang_tree = pcall(vim.treesitter.get_parser, buf)
    if not ok then
        return
    end

    local root = get_root_for_position(row, col, root_lang_tree) ---@type TSNode|nil
    if not root then
        return nil
    end

    return root:named_descendant_for_range(row, col, row, col) ---@type TSNode
end

vim.keymap.set("i", "<", function()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0)) ---@type number, number
    row = row - 1
    col = col - 1
    if not (get_node_at_cursor(row, col):type() == "type_identifier") then
        local key = vim.api.nvim_replace_termcodes("<", true, false, true) ---@type string
        vim.api.nvim_feedkeys(key, "n", false)
        return
    end

    local key = vim.api.nvim_replace_termcodes("<><left>", true, false, true) ---@type string
    vim.api.nvim_feedkeys(key, "n", false)
end, { buffer = true })

---@return nil
local feed_gt = function()
    local key = vim.api.nvim_replace_termcodes(">", true, false, true) ---@type string
    vim.api.nvim_feedkeys(key, "n", false)
end

vim.keymap.set("i", ">", function()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0)) ---@type number, number
    row = row - 1
    col = col
    local line = vim.api.nvim_get_current_line() ---@type string

    local char_at_cursor = line:sub(col + 1, col + 1) ---@type string
    if char_at_cursor ~= ">" then
        feed_gt()
        return
    end

    local node = get_node_at_cursor(row, col) ---@type TSNode|nil
    if not node then
        feed_gt()
        return
    end

    local node_type = node:type() ---@type string
    local type_arg = node_type == "type_arguments" ---@type boolean
    local type_id = node_type == "type_identifier" ---@type boolean
    local type_params = node_type == "type_parameters" ---@type boolean
    if not (type_arg or type_id or type_params) then
        feed_gt()
        return
    end

    local node_text = vim.treesitter.get_node_text(node, 0) or nil ---@type string|nil
    if not node_text then
        feed_gt()
        return
    end

    local open_count = 0 ---@type integer
    local close_count = 0 ---@type integer
    for i = 1, #node_text do
        local char = node_text:sub(i, i) ---@type string
        if char == "<" then
            open_count = open_count + 1
        elseif char == ">" then
            close_count = close_count + 1
        end
    end

    if open_count ~= close_count then
        feed_gt()
        return
    end

    local key = vim.api.nvim_replace_termcodes("<Right>", true, false, true) ---@type string
    vim.api.nvim_feedkeys(key, "n", false)
end, { buffer = true })
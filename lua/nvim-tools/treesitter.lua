local api = vim.api

local M = {} -- test

---@param buf integer
---@param row integer 0-indexed
---@param col integer 0-indexed, inclusive
---@param types string[]
---@param contains boolean
---@return boolean?
function M.is_pos_node(buf, row, col, types, contains)
    if #types < 1 then
        return nil
    end

    ---@type fun(node_type:string, type:string): boolean
    local predicate = contains
            and function(node_type, type)
                return string.find(node_type, type, 1, true) ~= nil
            end
        or function(node_type, type)
            return node_type == type
        end

    ---@param lang_tree vim.treesitter.LanguageTree
    ---@return boolean
    local function find_node_in_tree(lang_tree)
        local children = lang_tree:children()
        for _, child in pairs(children) do
            if find_node_in_tree(child) == true then
                return true
            end
        end

        local node = lang_tree:named_node_for_range({ row, col, row, col })
        while node do
            local node_type = node:type()
            for _, type in ipairs(types) do
                if predicate(node_type, type) then
                    return true
                end
            end

            node = node:parent()
        end

        return false
    end

    local root_lang_tree = vim.treesitter.get_parser(buf)
    if not root_lang_tree then
        return nil
    end

    return find_node_in_tree(root_lang_tree)
end

---@param types string[]
---@param contains boolean
---@return boolean?
function M.is_in_node(types, contains)
    local cur_pos = api.nvim_win_get_cursor(0)
    local row = cur_pos[1]
    local col = cur_pos[2]
    return M.is_pos_node(0, row, col, types, contains)
end

return M

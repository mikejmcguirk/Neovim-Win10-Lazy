local api = vim.api

local M = {}

---Credit echasnovski
---@param wins integer[]
function M.order_wins(wins)
    local positions = {} ---@type { [1]:integer, [2]:integer, [3]:integer }[]
    for _, win in ipairs(wins) do
        local config = api.nvim_win_get_config(win)
        local pos = api.nvim_win_get_position(win)
        positions[win] = { pos[1], pos[2], config.zindex or 0 }
    end

    table.sort(wins, function(a, b)
        local pos_a = positions[a]
        local pos_b = positions[b]

        if pos_a[3] < pos_b[3] then
            return true
        elseif pos_a[3] > pos_b[3] then
            return false
        elseif pos_a[2] < pos_b[2] then
            return true
        elseif pos_a[2] > pos_b[2] then
            return false
        else
            return pos_a[1] < pos_b[1]
        end
    end)
end

---Win and force params are the same as vim.api.nvim_win_close
---The first return value is true if the window was closed, false if not
---The second return is the window's buf-ID. This will be nil if the function exited with an
---error
---The third and fourth returns are the error message and error highlight
---In effect:
---- false, nil - Error
---- false, buf - Window not closed, intended behavior (last window)
---- true, buf - Window closed
---- true, nil - Should be impossible
---@param win integer
---@param force boolean
---@return boolean, integer|nil, string|nil, string|nil
function M.protected_close(win, force)
    if not api.nvim_win_is_valid(win) then
        return false, nil, "Invalid window", ""
    end

    local buf = api.nvim_win_get_buf(win)
    local tabpages = api.nvim_list_tabpages()
    if #tabpages == 1 then
        local tabpage_wins = api.nvim_tabpage_list_wins(tabpages[1])
        require("nvim-tools.list").filter(tabpage_wins, function(w)
            local relative = api.nvim_win_get_config(w).relative
            return relative == "" or not relative
        end)

        if #tabpage_wins == 1 then
            return false, buf, "E444: Cannot close last window", ""
        end
    end

    local ok, err = pcall(api.nvim_win_close, win, force)
    if ok then
        return ok, buf, nil, nil
    else
        return ok, nil, err, "ErrorMsg"
    end
end

---@param win integer
---@param cur_pos { [1]:integer, [2]: integer }
function M.protected_set_cursor(win, cur_pos)
    local buf = api.nvim_win_get_buf(win)

    local row = cur_pos[1]
    row = math.min(math.max(row, 1), api.nvim_buf_line_count(buf))

    local col = cur_pos[2]
    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    col = math.min(col, math.max(#line - 1, 0))

    api.nvim_win_set_cursor(win, { row, col })
end

return M

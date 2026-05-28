local api = vim.api

local M = {}

---@param split "left"|"right"|"above"|"below"|"split"|"vsplit"
---@return "left"|"right"|"above"|"below"
local function resolve_split(split)
    if split == "split" then
        ---@type boolean
        local splitbelow = api.nvim_get_option_value("sb", { scope = "global" })
        return splitbelow and "below" or "above"
    elseif split == "vsplit" then
        ---@type boolean
        local splitright = api.nvim_get_option_value("spr", { scope = "global" })
        return splitright and "right" or "left"
    else
        return split --[[@as "left"|"right"|"above"|"below"]]
    end
end

---@param win integer? Anchor window for the split. If -1, produces botright/topleft behavior
---If nil, current window is used
---@param buf integer? If nil, a temporary buffer is used
---@param enter boolean Enter split? See |nvim_open_win|
---@param split "left"|"right"|"above"|"below"|"split"|"vsplit"
---If split, splitbelow is used
---If vsplit, splitright is used
---@return integer
function M.create_split(win, buf, enter, split)
    local ntt = require("nvim-tools.types")
    -- is_int because -1 is valid here
    vim.validate("win", win, ntt.is_int, true)
    vim.validate("buf", buf, ntt.is_uint, true)
    vim.validate("enter", enter, "boolean")
    vim.validate("split", split, "string")

    win = win == nil and 0 or win
    buf = buf and buf
        or require("nvim-tools.buf").create_temp_buf("wipe", false, "nofile", "", true)

    split = resolve_split(split)
    return api.nvim_open_win(buf, enter, { win = win, split = split })
end

---@param win integer window-ID
---@param cur_pos { [1]:integer, [2]:integer } Cursor indexed
---@return boolean
function M.cursor_at(win, cur_pos)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("win", win, is_uint)
    vim.validate("cur_pos", cur_pos, "table")

    local win_cur_pos = api.nvim_win_get_cursor(win)
    return win_cur_pos[1] == cur_pos[1] and win_cur_pos[2] == cur_pos[2]
end

---@param win_config vim.api.keyset.win_config_ret
---@return boolean
function M.is_floating(win_config)
    vim.validate("win_config", win_config, "table")

    local relative = win_config.relative
    return relative ~= nil and relative ~= ""
end
-- Can also check with win_gettype == "popup"

---@param win_config vim.api.keyset.win_config_ret
---@return boolean
function M.is_focusable(win_config)
    vim.validate("win_config", win_config, "table")

    return win_config.focusable == true and win_config.hide == false
end

---Credit echasnovski
---@param wins integer[]
function M.order_wins(wins)
    vim.validate("wins", wins, "table")

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
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("win", win, is_uint)
    vim.validate("force", force, "boolean", true)

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
---@param is_term boolean
---@ return { [1]:integer, [2]: integer }
function M.protected_set_cursor(win, cur_pos, is_term)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("win", win, is_uint)
    vim.validate("cur_pos", cur_pos, "table")

    local buf = api.nvim_win_get_buf(win)
    if is_term == nil then
        ---@type string
        local bt = api.nvim_get_option_value("bt", { buf = buf })
        is_term = bt == "terminal"
    end

    if is_term then
        return api.nvim_win_get_cursor(win)
    end

    local row, col = cur_pos[1], cur_pos[2]
    row, col = require("nvim-tools.pos").adj_mark_pos(row, col, buf)

    local new_cur_pos = { row, col }
    api.nvim_win_set_cursor(win, new_cur_pos)
    return new_cur_pos
end

---@param win integer
---@return boolean, integer, string|nil, string|nil
function M.resolve_win_id(win)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("win", win, is_uint)

    if win == 0 then
        return true, api.nvim_get_current_win(), nil, nil
    end

    if api.nvim_win_is_valid(win) then
        return true, win, nil, nil
    else
        return false, -1, "Win ID " .. win .. " is invalid", "ErrorMsg"
    end
end

---Use nvim_win_call if cur_win ~= win. Otherwise, call the function as normal.
---Worth using due to non-trivial overhead of nvim_win_call
---@param cur_win integer
---@param win integer
---@param f function
---@return any, any
function M.call_in(cur_win, win, f)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("cur_win", cur_win, is_uint)
    vim.validate("win", win, is_uint)
    vim.validate("f", f, "function")

    win = win == 0 and cur_win or win
    if cur_win == win then
        return f()
    else
        return api.nvim_win_call(win, f)
    end
end

return M

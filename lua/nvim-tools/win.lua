local api = vim.api
local fn = vim.fn

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

---Return the cursor position of `win` for use with |api-indexing|.
---@param win? uinteger
---@return [uinteger, uinteger]
function M.cursor_ext_get(win)
    return require("nvim-tools.pos").mark_to_ext_pos(api.nvim_win_get_cursor(win or 0))
end

---Credit echasnovski
---@audited 2026-07-03
---@param wins integer[]
function M.order_wins(wins)
    local positions = {} ---@type { [1]:integer, [2]:integer, [3]:integer }[]
    for _, win in ipairs(wins) do
        local pos = api.nvim_win_get_position(win)
        local config = api.nvim_win_get_config(win)
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
---@return boolean, integer|nil, string, string|nil
function M.protected_close(win, force)
    if not api.nvim_win_is_valid(win) then
        return false, nil, "Invalid window", ""
    end

    local buf = api.nvim_win_get_buf(win)
    local tabpages = api.nvim_list_tabpages()
    if #tabpages == 1 then
        local tabpage_wins = api.nvim_tabpage_list_wins(tabpages[1])
        local ntt = require("nvim-tools.table")
        local other_wins = ntt.i_any(tabpage_wins, function(w)
            if w == win then
                return false
            end

            local wintype = fn.win_gettype(w)
            if wintype ~= "" then
                return false
            end

            local config = api.nvim_win_get_config(w)
            if config.relative ~= nil and config.relative ~= "" then
                return false
            end

            return not config.hide
        end)

        if not other_wins then
            return false, buf, "E444: Cannot close last window", ""
        end
    end

    local ok, err = pcall(api.nvim_win_close, win, force)
    if ok then
        return ok, buf, "", nil
    else
        return ok, nil, err, "ErrorMsg"
    end
end

---@param wins uinteger[]
---@param force boolean
---@return boolean
function M.protected_close_multiple(wins, force)
    for i = 1, #wins do
        local ok, buf, _, _ = M.protected_close(wins[i], force)
        if ok == false and buf == nil then
            return false
        end
    end

    return true
end

---@param win integer
---@param cur_pos { [1]:integer, [2]: integer }
---@param is_term? boolean
---@ return { [1]:integer, [2]: integer }
function M.protected_set_cursor(win, cur_pos, is_term)
    local win_buf = api.nvim_win_get_buf(win)
    if is_term == nil then
        ---@type string
        local bt = api.nvim_get_option_value("bt", { buf = win_buf })
        is_term = bt == "terminal"
    end

    if is_term then
        return api.nvim_win_get_cursor(win)
    end

    local row, col = cur_pos[1], cur_pos[2]
    row, col = require("nvim-tools.pos").adj_mark_pos(row, col, win_buf)
    -- TODO: This should be done in place.

    local new_cur_pos = { row, col }
    api.nvim_win_set_cursor(win, new_cur_pos)
    return new_cur_pos
end

---If version < 0.13, and both width and height are > -1, then width is set first.
---@param win uinteger
---@param width integer
---@param height integer
---@param opts vim.api.keyset.win_resize
function M.resize(win, width, height, opts)
    if fn.has("nvim-0.13") == 1 then
        api.nvim_win_resize(win, width, height, opts)
    else
        if width > -1 then
            ---@diagnostic disable-next-line: deprecated
            api.nvim_win_set_width(win, width)
        end

        if height > -1 then
            ---@diagnostic disable-next-line: deprecated
            api.nvim_win_set_height(win, height)
        end
    end
end
-- TODO-DEP: Remove when 0.14 comes out.
-- LOW: For the pre-0.13 case, could look at the code to see if width or height should be set
-- first.

return M

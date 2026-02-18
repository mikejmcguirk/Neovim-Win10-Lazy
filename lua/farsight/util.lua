local api = vim.api
local fn = vim.fn

---@class farsight.Util
local M = {}

---@type fun(narray: integer, nhash: integer): table
M._table_new = (function()
    local t_new = require("table.new")
    if t_new then
        ---@diagnostic disable-next-line: undefined-field
        return table.new
    else
        return function()
            return {}
        end
    end
end)()

---@generic T
---@param t table<T, T>
---@param f fun(k: T, v: T): boolean|nil
function M._dict_filter(t, f)
    for k, v in pairs(t) do
        if not f(k, v) then
            t[k] = nil
        end
    end
end

---@generic T
---@param t T[]
function M._list_copy(t)
    local len_t = #t
    local ret = M._table_new(len_t, 0)
    for i = 1, len_t do
        ret[i] = t[i]
    end

    return ret
end

---Bespoke function because:
---- Skip running vim.validate in hot loops
---- Don't need the list return
---@generic T
---@param t T[]
function M._list_dedup(t)
    local seen = {} --- @type table<any, boolean>
    local len = #t
    local j = 1

    for i = 1, len do
        local v = t[i]
        if not seen[v] then
            t[j] = v
            if v ~= nil then
                seen[v] = true
            end

            j = j + 1
        end
    end

    for i = j, len do
        t[i] = nil
    end
end

---Bespoke function to avoid vim.validate and list returns in hot loops
---@generic T
---@param t T[]
---@param f fun(x: T): boolean
function M._list_filter(t, f)
    local len = #t
    local j = 1

    for i = 1, len do
        local v = t[i]
        if f(v) then
            t[j] = v
            j = j + 1
        end
    end

    for i = j, len do
        t[i] = nil
    end
end

-- PR: Add to Nvim shared.

---@generic T
---@param t T[]
---@param f fun(x: T, idx: integer): any
function M._list_map(t, f)
    local len = #t
    local j = 1

    for i = 1, len do
        t[j] = f(t[i], i)
        if t[j] ~= nil then
            j = j + 1
        end
    end

    for i = j, len do
        t[i] = nil
    end
end

-- PR: Spot checking, this moves about the same speed as or more quickly than table.remove for
-- lists

---@param t any[]
---@param idx integer
function M._list_remove_item(t, idx)
    local len = #t
    for i = idx + 1, len do
        t[i - 1] = t[i]
    end

    t[len] = nil
end

-- Per mini.jump2d, while nvim_tabpage_list_wins does currently ensure proper window layout, this
-- is not documented behavior and thus can change. The below function ensures layout
---@param wins integer[]
---@return integer[]
function M._order_focusable_wins(wins)
    local focusable_wins = {} ---@type integer[]
    local positions = {} ---@type { [1]:integer, [2]:integer, [3]:integer }[]

    for _, win in ipairs(wins) do
        local config = api.nvim_win_get_config(win)
        if config.focusable and not config.hide then
            focusable_wins[#focusable_wins + 1] = win
            local pos = api.nvim_win_get_position(win)
            positions[win] = { pos[1], pos[2], config.zindex or 0 }
        end
    end

    table.sort(focusable_wins, function(a, b)
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

    return focusable_wins
end

local cword_str = [[\k\+]]

---Col is zero indexed inclusive
---Returns the result of matchstrpos(). The cols are zero indexed, and the end col is exclusive
---@param line string
---@param col integer
---@return { [1]: string, [2]: integer, [3]: integer }|nil
function M._find_cword_at_col(line, col)
    local init = 0

    while init <= col do
        ---@type { [1]: string, [2]: integer, [3]: integer }
        local res = fn.matchstrpos(line, cword_str, init)
        local start = res[2]
        local fin_ = res[3]

        if start < 0 then
            return nil
        end

        if start <= col and col < fin_ then
            return res
        end

        init = fin_
    end

    return nil
end

---@param opt boolean|nil
---@param default boolean
---@return boolean
function M._resolve_bool_opt(opt, default)
    if type(opt) == "nil" then
        return default
    else
        vim.validate("opt", opt, "boolean")
        return opt
    end
end

---While the return type contains all |map-modes| for completeness, this function only returns
---n, v, o, l, or t
---Visual/select mode aren't distinguished because selection=exclusive has the same effect on both
---I'm unsure how any of the l modes would be used for a jump in practice, so they are all
---grouped together
---@param mode string
---@return "n"|"v"|"o"|"l"|"t"|"x"|"s"|"i"|"c"
function M._resolve_map_mode(mode)
    local sub = string.sub
    if sub(mode, 1, 2) == "no" then
        return "o"
    end

    local short_mode = sub(mode, 1, 1)
    if short_mode == "n" then
        return "n"
    end

    if
        short_mode == "v"
        or short_mode == "V"
        or short_mode == "\22"
        or short_mode == "s"
        or short_mode == "S"
        or short_mode == "\19"
    then
        return "v"
    end

    if short_mode == "t" then
        return "t"
    end

    return "l"
end

---If a found var is a table, return with vim.deepcopy
---@param opt any
---@param var string
---@param buf integer
---@return any
function M._use_gb_if_nil(opt, var, buf)
    if opt ~= nil then
        return opt
    end

    if vim.b[buf][var] ~= nil then
        if type(vim.b[buf][var]) == "table" then
            return vim.deepcopy(vim.b[buf][var])
        else
            return vim.b[buf][var]
        end
    end

    if vim.g[var] ~= nil then
        if type(vim.g[var]) == "table" then
            return vim.deepcopy(vim.g[var])
        else
            return vim.g[var]
        end
    end

    return nil
end

---@class farsight.util.ValidateListOpts
---@field func? fun(any):boolean, string?
---@field item_type? string[]
---@field len? integer
---@field max_len? integer
---@field min_len? integer
---@field optional? boolean

---@param list table
---@param opts farsight.util.ValidateListOpts
---@return nil
function M._validate_list(list, opts)
    vim.validate("list", list, function()
        if not vim.islist(list) then
            return false, "Not a valid list"
        end

        local list_len = #list
        local len = opts.len
        if len and list_len ~= len then
            return false, "List length must be " .. len
        end

        local min_len = opts.min_len
        if min_len and list_len < min_len then
            return false, "List length must be at least" .. min_len
        end

        local max_len = opts.max_len
        if max_len and list_len > max_len then
            return false, "List length must be at most" .. max_len
        end

        local item_type = opts.item_type
        if item_type then
            for _, item in ipairs(list) do
                local this_item_type = type(item)
                if not vim.list_contains(item_type, this_item_type) then
                    return false, "List items must be type " .. vim.inspect(item_type)
                end
            end
        end

        local func = opts.func
        if func then
            for _, item in ipairs(list) do
                local ok, msg = func(item)
                if not ok then
                    return false, msg
                end
            end
        end

        return true
    end, opts.optional)
end

-- MID: Also return messages from these validations for vim.validate to use

---@param n integer
---@return boolean
function M._is_int(n)
    if type(n) ~= "number" then
        return false
    end

    return n % 1 == 0
end

---@param n integer
---@return boolean
function M._is_uint(n)
    if M._is_int(n) == false then
        return false
    end

    return n >= 0
end

return M

-- TODO: Given what I found when doing list.filter in PUC Lua, I have to imagine that would
-- influence the behavior in this plugin
-- TODO: Rename this to _util
-- TODO: Why is _common a separate file? I guess we're separating jump logic from helper logic, but
-- feels thin

-- ---@generic T
-- ---@param t T[]
-- ---@param f fun(x: T): boolean
-- function M._list_filter_beg_only(t, f)
--     local len = #t
--     local j = 1
--     local k = 1
--
--     for i = 1, len do
--         k = i + 1
--
--         local v = t[i]
--         if f(v) then
--             if i == 1 then
--                 return
--             end
--
--             t[j] = v
--             j = j + 1
--             break
--         end
--     end
--
--     for i = k, len do
--         t[j] = t[i]
--         j = j + 1
--     end
--
--     for i = j, len do
--         t[i] = nil
--     end
-- end

-- ---@generic T
-- ---@param t T[]
-- ---@param s integer
-- ---@param f fun(x: T): boolean
-- function M._list_filter_end_only(t, s, f)
--     local len_t = #t
--     for i = len_t, 1, -1 do
--         local v = t[i]
--         if not f(v) then
--             t[i] = nil
--             if i == s then
--                 return
--             end
--         else
--             return
--         end
--     end
-- end

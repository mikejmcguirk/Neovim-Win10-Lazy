local api = vim.api
local fn = vim.fn
local vimv = vim.v

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
---@param t table<T, T>
---@param k T
---@param v T
function M.dict_get_key_or_default(t, k, v)
    local ret = t[k]
    if ret then
        return ret
    end

    t[k] = v
    return v
end
-- MID: There might be a better way to handle this with a metatable or something.
-- PR: Might be a cool vim.dict addition.

---@generic T
---@param t table<T, T>
function M.table_clear(t)
    for k, _ in pairs(t) do
        t[k] = nil
    end
end

---Assumes list is ordered and v is orderable
---@generic T
---@param t T[]
---@param v T
---@return integer, boolean
function M.list_bisect_left(t, v)
    local lo = 1
    local hi = #t
    while lo <= hi do
        local mid = math.floor((lo + hi) * 0.5)
        if t[mid] < v then
            lo = mid + 1
        else
            hi = mid - 1
        end
    end

    local found = (lo <= #t and t[lo] == v)
    return lo, found
end

---@generic T
---@param t T[]
function M.list_clear(t)
    local len_t = #t
    for i = 1, len_t do
        t[i] = nil
    end
end

---@generic T
---@param t1 T[]
---@param t2 T[]
---@param len integer
function M.list_clear_two(t1, t2, len)
    for i = 1, len do
        t1[i] = nil
        t2[i] = nil
    end
end
-- TODO: Remove this

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

---@generic T
---@param t T[]
---@param idx integer
function M.list_del_at(t, idx)
    local len = #t
    local j = idx
    for i = idx + 1, len do
        t[j] = t[i]
        j = j + 1
    end

    t[len] = nil
end

---@generic T
---@param t1 T[]
---@param t2 T[]
---@param idx integer
---@param len integer
function M.list_del_at_two(t1, t2, idx, len)
    local j = idx
    for i = idx + 1, len do
        t1[j] = t1[i]
        t2[j] = t2[i]
        j = j + 1
    end

    t1[len] = nil
    t2[len] = nil
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

---@generic T
---@param t T[]
---@param v T
---@param idx integer
function M.list_insert_at(t, v, idx)
    local len = #t
    t[len + 1] = t[len]
    for i = len, idx + 1, -1 do
        t[i] = t[i - 1]
    end

    t[idx] = v
end

---@generic T
---@param t1 T[]
---@param v1 T
---@param t2 T[]
---@param v2 T
---@param idx integer
---@param len integer
function M.list_insert_at_two(t1, v1, t2, v2, idx, len)
    local len_plus_one = len + 1
    t1[len_plus_one] = t2[len]
    t2[len_plus_one] = t2[len]

    local j = len - 1
    for i = len, idx + 1, -1 do
        t1[i] = t1[j]
        t2[i] = t2[j]
        j = j - 1
    end

    t1[idx] = v1
    t2[idx] = v2
end
-- TODO: I'm not sure if this is actually good, dump it.

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

---@param tokens string[]
---@return integer[]
function M.get_token_codepoints(tokens)
    local get_utf_codepoint = require("farsight._util_char")._get_utf_codepoint
    local codepoint_tokens = M._list_copy(tokens)
    M._list_map(codepoint_tokens, function(t)
        local char_nr, _ = get_utf_codepoint(t, string.byte(t, 1), 1)
        return char_nr
    end)

    return codepoint_tokens
end

---@param silent boolean
---@param msg any
---@param hl any
---@return nil
function M._echo(silent, msg, hl)
    if silent then
        return
    end

    if type(msg) ~= "string" then
        msg = ""
    end

    if type(hl) ~= "string" then
        hl = ""
    end

    local history = hl == "ErrorMsg" or hl == "WarningMsg" ---@type boolean
    api.nvim_echo({ { msg, hl } }, history, {})
end

---Return how many columns separate position a and position b.
---If position a is on a previous row, vim.v.maxcol will be returned.
---If position a is after position b, a negative value will be returned.
---@param row_a integer
---@param col_a integer
---@param row_b integer
---@param col_b integer
---@return integer
function M.col_distance(row_a, col_a, row_b, col_b)
    if row_a == row_b then
        return col_b - col_a
    end

    return row_a < row_b and vimv.maxcol or -vimv.maxcol
end

---Inclusive indexed
---@param row_a integer
---@param col_a integer
---@param fin_row_a integer
---@param fin_col_a integer
---@param row_b integer
---@param col_b integer
---@return boolean
function M.pos_contained(row_a, col_a, fin_row_a, fin_col_a, row_b, col_b)
    if row_b < row_a or fin_row_a < row_b then
        return false
    end

    local gt_start = (row_a < row_b or col_a <= col_b)
    return gt_start and (row_b < fin_row_a or col_b <= fin_col_a)
end

---Inclusive indexed
---@param row_a integer
---@param col_a integer
---@param row_b integer
---@param col_b integer
---@return boolean
function M.pos_lt(row_a, col_a, row_b, col_b)
    return row_a < row_b or (row_a == row_b and col_a < col_b)
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

-- TODO: Make util_list its own module
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

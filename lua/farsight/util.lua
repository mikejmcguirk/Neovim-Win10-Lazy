local api = vim.api
local fn = vim.fn

---@class farsight.Util
local M = {}

---Bespoke function because:
---- vim.list.unique runs vim.validate at the beginning. Inconvenient here since deduping is done
---in hot loops (spot checking, the average execution time is not meaningfully higher, but the
---variance is higher)
---- vim.list.unique returns the list, which is unnecesary
---- vim.list.unique is v12 only. Doing this saves the cost of versioning maintenance
---@param t any[]
function M._list_dedup(t)
    local seen = {} --- @type table<any,boolean>
    local finish = #t
    local j = 1

    for i = 1, finish do
        local v = t[i]
        if not seen[v] then
            t[j] = v

            if v ~= nil then
                seen[v] = true
            end

            j = j + 1
        end
    end

    for i = j, finish do
        t[i] = nil
    end
end

-- PR: This should be in vim.list. You can run vim.validate on t and t then the code should
-- otherwise be the same. The vim function should also return the table reference
-- Question - How do you validate that it's a proper list? Like, how do you handle something with
-- nil gaps in it? Question needs more fully explored
-- Should the vim list filter allow f to be optional? If it's not present, then I guess just
-- nil the list in place?
-- Note - A vim implementation would need to work with vim.iter

---@param t any[]
---@param f fun(v: any): boolean
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

--- Col is zero indexed inclusive
--- Returns the result of matchstrpos(). The cols are zero indexed, and the end col is exclusive
---@param line string
---@param col integer
---@return { [1]: string, [2]: integer, [3]: integer }|nil
function M._find_cword_at_col(line, col)
    local start = 0

    while start <= col do
        local res = fn.matchstrpos(line, cword_str, start)
        if res[2] < 0 then
            return nil
        end

        if res[2] <= col and col < res[3] then
            return res
        end

        start = res[3]
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

---@param opt any
---@param var string
---@param buf integer
---@return any
function M._use_gb_if_nil(opt, var, buf)
    if opt ~= nil then
        return opt
    end

    if vim.b[buf][var] ~= nil then
        return vim.b[buf][var]
    end

    if vim.g[var] ~= nil then
        return vim.g[var]
    end

    return opt
end

---@class farsight.util.ValidateListOpts
---@field len? integer
---@field max_len? integer
---@field min_len? integer
---@field optional? boolean
---@field item_type? string

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
                if type(item) ~= item_type then
                    return false, "List items must be type " .. item_type
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

-- TODO: Rename this to _util
-- TODO: Why is _common a separate file? I guess we're separating jump logic from helper logic, but
-- feels thin

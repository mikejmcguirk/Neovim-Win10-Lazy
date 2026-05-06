---@type fun(narray: integer, nhash: integer): table

--- @class nvim.util.MDNode
--- @field [integer] nvim.util.MDNode
--- @field type string
--- @field text? string

local M = {}

--------------------------
-- MARK: Table Functions --
--------------------------

---@param lines string[]
---@param f fun(all_lines: string): string, any
---@return string[]
function M.do_over_lines(lines, f)
    return vim.split(f(table.concat(lines)), "\n")
end

---@generic T
---@param t T[]
---@param f fun(x: T): boolean
function M.list_filter(t, f)
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
---@return integer|nil
function M.list_find(t, v)
    for i = 1, #t do
        if t[i] == v then
            return i
        end
    end

    return nil
end

---@generic T
---@param t T[]
---@param f fun(x: T, idx: integer): any
function M.list_map(t, f)
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

-- Port of Neovim core logic since their table module is private
local has_new, table_new = pcall(require, "table.new")
if not has_new then
    ---@diagnostic disable-next-line: unused-local
    table_new = function(narray, nhash)
        return {}
    end
end

M.table_new = table_new

--------------------------
-- MARK: Text Functions --
--------------------------

--- @param txt string
--- @param srow integer
--- @param scol integer
--- @param erow? integer
--- @param ecol? integer
--- @return string
function M.slice_text(txt, srow, scol, erow, ecol)
    local lines = vim.split(txt, "\n")

    if srow == erow then
        return lines[srow + 1]:sub(scol + 1, ecol)
    end

    if erow then
        for _ = erow + 2, #lines do
            table.remove(lines, #lines)
        end
    end

    for _ = 1, srow do
        table.remove(lines, 1)
    end

    lines[1] = lines[1]:sub(scol + 1)
    lines[#lines] = lines[#lines]:sub(1, ecol)

    return table.concat(lines, "\n")
end

--- @param x string
--- @param start_indent integer
--- @param indent integer
--- @param text_width integer
--- @return string
function M.wrap(x, start_indent, indent, text_width)
    local words = vim.split(vim.trim(x), "%s+")
    local parts = { string.rep(" ", start_indent) } --- @type string[]
    local len_cur_line = indent

    for i, w in ipairs(words) do
        if len_cur_line > indent and len_cur_line + #w > text_width - 1 then
            parts[#parts + 1] = "\n"
            parts[#parts + 1] = string.rep(" ", indent)
            len_cur_line = indent
        elseif i ~= 1 then
            parts[#parts + 1] = " "
            len_cur_line = len_cur_line + 1
        end
        len_cur_line = len_cur_line + #w
        parts[#parts + 1] = w
    end

    -- TODO: Need to look at it more, but this seems silly because you're basically doing the
    -- start indent string rep then getting rid of it always.
    return (table.concat(parts):gsub("%s+\n", "\n"):gsub("\n+$", ""))
end

return M

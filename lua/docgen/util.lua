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

---@param text string
---@return string
function M.adj_newlines(text)
    -- text = string.gsub(text, "%s+\n", "\n")
    text = string.gsub(text, "\n%s+", "\n")
    text = string.gsub(text, "\n+", function(match)
        if #match == 1 then
            return " "
        else
            return "\n\n"
        end
    end)

    return text
end

--- @param lines string[]
--- @param srow integer 0-indexed
--- @param scol integer 0-indexed, inclusive
--- @param erow? integer 0-indexed
--- @param ecol? integer 0-indexed, exclusive
--- @return string sliced
function M.slice_lines(lines, srow, scol, erow, ecol)
    local srow_1 = srow + 1
    local scol_1 = scol + 1
    local erow_1 = erow and erow + 1 or #lines
    local len_last_line = #lines[erow_1]
    local ecol_1 = ecol or len_last_line
    if len_last_line > 0 then
        ecol_1 = ecol_1 + vim.str_utf_start(lines[erow_1], ecol_1)
    end

    if srow_1 == erow_1 then
        return string.sub(lines[srow_1], scol_1, ecol_1)
    end

    -- Don't edit lines in place
    local ret = table_new(erow_1 - srow_1 + 1, 0)
    ret[1] = string.sub(lines[srow_1], scol_1)
    for i = srow_1 + 1, erow_1 - 1 do
        ret[#ret + 1] = lines[i]
    end

    ret[#ret + 1] = string.sub(lines[erow_1], 1, ecol_1)
    return table.concat(ret, "\n")
end

--- @param txt string
--- @param srow integer
--- @param scol integer
--- @param erow? integer
--- @param ecol? integer
--- @return string
function M.slice_text(txt, srow, scol, erow, ecol)
    local lines = vim.split(txt, "\n")
    return M.slice_lines(lines, srow, scol, erow, ecol)
end

---NOTE: Does not add a final newline
---@param line string
---@param first_indent integer
---@param indent integer
---@param text_width integer
local function wrap_line(line, first_indent, indent, text_width)
    local init = 1
    local start, fin = string.find(line, "[^%s]+", init)
    if not (start and fin) then
        return ""
    end

    local indent_str = string.rep(" ", indent)
    local len_line = #line
    local parts = { string.rep(" ", first_indent) }
    local cur_sub_len = first_indent
    local sub_start = 1
    local sub_fin = fin

    while true do
        if start and fin then
            local growth = fin - init + 1
            cur_sub_len = cur_sub_len + growth

            if cur_sub_len > text_width then
                parts[#parts + 1] = string.sub(line, sub_start, sub_fin)
                parts[#parts + 1] = "\n"
                parts[#parts + 1] = indent_str

                sub_start = start
                cur_sub_len = indent + growth
            end

            sub_fin = fin
            init = sub_fin + 1

            if init > len_line then
                parts[#parts + 1] = string.sub(line, sub_start, sub_fin)
                break
            end
        else
            parts[#parts + 1] = string.sub(line, sub_start, sub_fin)
            break
        end

        start, fin = string.find(line, "[^%s]+", init)
    end

    return table.concat(parts)
end

--- Assumes that lines are already cleanly separated by single "\n" characters
--- @param text string
--- @param first_indent integer Only applied to the first unwrapped line
--- @param indent integer
--- @param text_width integer
--- @return string wrapped Does not contain a trailing \n
function M.wrap(text, first_indent, indent, text_width)
    if not text or text == "" or text_width < 1 then
        return text or ""
    end

    text = text:gsub("\t", string.rep(" ", 8))

    local lines = vim.split(text, "\n", { plain = true })
    local res = {}

    local first_line = lines[1]
    local this_fin_indent = string.find(first_line, "^•", 1) and first_indent + 2 or indent
    res[1] = wrap_line(lines[1], first_indent, this_fin_indent, text_width)

    for i = 2, #lines do
        res[#res + 1] = "\n"
        local line = lines[i]
        local this_indent = string.find(line, "^•", 1) and indent + 2 or indent
        res[#res + 1] = wrap_line(line, indent, this_indent, text_width)
    end

    return table.concat(res)
end
-- MID: Tab replacement should be done in some broader location to make sure they're handled
-- throughout the whole doc. It would be nice it were in some location that was guaranteed to hit
-- them all before they got here, but it might be better to just do the check in duplicate.
-- NON: Keep the text width var. Keeps the function flexible.

return M

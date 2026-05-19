---@type fun(narray: integer, nhash: integer): table

--- @class nvim.util.MDNode
--- @field [integer] nvim.util.MDNode
--- @field type string
--- @field text? string

local M = {}

---@param timer uv.uv_timer_t|nil
function M.stop_timer(timer)
    if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
        timer = nil
    end

    return nil
end

--------------------------
-- MARK: Table Functions --
--------------------------

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
---@param v T | fun(x: T): boolean
---@return integer|nil
function M.list_find(t, v)
    local predicate = type(v) == "function" and v or function(x)
        return x == v
    end

    for i = 1, #t do
        if predicate(t[i]) then
            return i
        end
    end

    return nil
end

M.table_new = require("table.new")
M.table_clear = require("table.clear")

--------------------------
-- MARK: Text Functions --
--------------------------

---If no width formatting is needed, call with width = 0.
---@param str string
---@param width integer
---@return string name
function M.add_cbraces(str, width)
    -- TODO: This should not be here. The parser_obj needs to handle this data correction.
    local name, opt = str:match("^([^?]*)(%??)$")
    local raw_width = #name + #opt
    local remain = math.max(width - raw_width - 2, 0)

    return "{" .. name .. "}" .. opt .. string.rep(" ", remain)
end

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
-- TODO: Needs to be documented that, except for when the markdown parsing detects a bulleted
-- list, single newlines are always wrapped. Double+ newlines are always treated as a double
-- newline.

---@param left string?
---@param sep string
---@param right string
---@return string
function M.checked_append(left, sep, right)
    if left then
        return left .. sep .. right
    else
        return right
    end
end
-- TODO:DEP: Add this to nvim-tools with checked_prepend. Wait until the docgen is done.

---@param str string
---@return string, integer
function M.lua_pattern_escape(str)
    return string.gsub(str, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
end
-- TODO: Add to nvim tools

---@param str string
---@return string
function M.rtrim(str)
    local matched = string.match(str, "^.*%S")
    if matched then
        return matched
    end

    return ""
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
    local ret = M.table_new(erow_1 - srow_1 + 1, 0)
    ret[1] = string.sub(lines[srow_1], scol_1)
    for i = srow_1 + 1, erow_1 - 1 do
        ret[#ret + 1] = lines[i]
    end

    ret[#ret + 1] = string.sub(lines[erow_1], 1, ecol_1)
    return table.concat(ret, "\n")
end

---@param str string
---@param byte integer
---@return boolean
function M.startswith_byte(str, byte)
    return #str > 0 and string.byte(str, 1) == byte
end

---@param str string
---@param byte integer
---@return boolean
function M.endswith_byte(str, byte)
    local len_str = #str
    return len_str > 0 and string.byte(len_str, 1) == byte
end

---@param str string?
---@return boolean
function M.str_has_content(str)
    return str ~= nil and string.find(str, "[^%s]") ~= nil
end
-- TODO: Add this updated version to nvim-tools

---@param typ string
---@param default? string
function M.type_fmt_get_with_default(typ, default)
    if not default then
        return "(`" .. typ .. "`)"
    end

    return string.format("(`%s`, default: %s)", typ, default)
end

---NOTE: Does not add a final newline
---@param line string
---@param first_indent integer
---@param indent integer
---@param text_width integer
---@return string
local function wrap_line(line, first_indent, indent, text_width)
    if not M.str_has_content(line) then
        return ""
    end

    local len_line = #line
    if len_line + first_indent <= text_width then
        return string.rep(" ", first_indent) .. line
    end

    local init = 1
    local start, fin = string.find(line, "[^%s]+", init)
    if not (start and fin) then
        return ""
    end

    local indent_str = string.rep(" ", indent)
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
-- MID: This should not break up code spans.

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

    local lines = vim.split(text, "\n", { plain = true })
    local res = {}

    local first_line = lines[1]
    local this_fin_indent = string.find(first_line, "^•", 1) and first_indent + 2 or indent
    res[1] = wrap_line(lines[1], first_indent, this_fin_indent, text_width)

    for i = 2, #lines do
        local line = lines[i]
        local this_indent = string.find(line, "^•", 1) and indent + 2 or indent
        res[#res + 1] = wrap_line(line, indent, this_indent, text_width)
    end

    return table.concat(res, "\n")
end
-- NON: Don't remove the text width variable even though it exists as a constant. Keeps the
-- function flexible.

-- TODO: I would like to have a "pure function" rule for this module, with an exception for
-- editing a single function param. If a function param is edited, the actual return from the
-- function should only be a status marker.
-- - Bigger challenge I think would be anything related to logging.

return M

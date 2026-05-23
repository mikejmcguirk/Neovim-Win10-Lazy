local api = vim.api
local bit = require("bit")

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
function M.list_copy(t)
    local t_len = #t
    local ret = M.table_new(t_len, 0)
    for i = 1, t_len do
        ret[i] = t[i]
    end

    return ret
end

---@generic T
---@param t T[]
---@param f fun(x: T): boolean
function M.list_filter(t, f)
    local t_len = #t
    local j = 1

    for i = 1, t_len do
        local v = t[i]
        if f(v) then
            t[j] = v
            j = j + 1
        end
    end

    for i = j, t_len do
        t[i] = nil
    end
end

---@generic T
---@generic U
---@param t T[]
---@param init U
---@param f fun(x:T, acc:U): U
function M.list_fold(t, init, f)
    local t_len = #t
    local acc = init
    for i = 1, t_len do
        acc = f(t[i], acc)
    end

    return acc
end
-- TODO: nvim-tools

---@generic T
---@param t T[]
---@param f fun(x: T, idx: integer): any
function M.list_map(t, f)
    local t_len = #t
    for i = 1, t_len do
        t[i] = f(t[i], i)
    end

    return t
end
-- TODO: nvim-tools - Implement the core's reference return pattern in the list module (like
-- above). Doing something like list_map(list_copy(foo), mapper) is too useful.

---@param t table
---@param key string
---@return table
function M.table_get_or_create_subtable(t, key)
    local t_ret = rawget(t, key)
    if t_ret then
        return t_ret
    end

    local ret = {}
    rawset(t, key, ret)
    return ret
end
-- TODO: nvim-tools

M.table_new = require("table.new")
M.table_clear = require("table.clear")

--------------------------
-- MARK: Text Functions --
--------------------------

---@param str string
---@param left string
---@param right? string Same as left if nil
---@return string
function M.str_surround(str, left, right)
    right = right or left
    return left .. str .. right
end

---@param str string
---@param char string
---@param width integer
local function str_pad_get_chars_count(str, char, width)
    -- Use nvim_strwidth instead of strdisplaywidth because the latter's tab expansions are
    -- dependent on window context.
    local width_rem = width - api.nvim_strwidth(str)
    if width_rem > 0 then
        -- NOTE: Pre-compute char-width in hot paths.
        local char_width = api.nvim_strwidth(char)
        if char_width == 1 then
            return width_rem
        end

        if char_width == 2 then
            return bit.rshift(width_rem, 1)
        end

        -- I have never seen a width three character before.
        if char_width == 0 then
            return 0
        end

        return math.floor(width_rem / char_width)
    end

    return 0
end

---@param str string
---@param char string
---@param width integer
function M.str_lpad(str, char, width)
    local chars_count = str_pad_get_chars_count(str, char, width)
    if chars_count > 0 then
        return string.rep(char, chars_count) .. str
    end

    return str
end
-- TODO: nvim-tools

---@param str string
---@param char string
---@param width integer
function M.str_rpad(str, char, width)
    local chars_count = str_pad_get_chars_count(str, char, width)
    if chars_count > 0 then
        return str .. string.rep(char, chars_count)
    end

    return str
end
-- TODO: nvim-tools

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
function M.str_ltrim(str)
    local gsubbed, _ = string.gsub(str, "^%s+", "")
    return gsubbed
end

---@param str string
---@return string
function M.str_rtrim(str)
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
    erow_1 = math.min(erow_1, #lines)
    local len_last_line = #lines[erow_1]
    local ecol_1 = ecol or len_last_line
    -- In case you have a row, col 0 end node
    if ecol_1 == 0 then
        erow_1 = erow_1 - 1
        ecol_1 = #lines[erow_1]
    elseif len_last_line > 0 then
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

---@param str string
---@param sep string
---@param f fun(part:string): string
function M.str_op_by_sep(str, sep, f)
    local str_parts = vim.split(str, sep)
    M.list_map(str_parts, function(part)
        return f(part)
    end)

    return table.concat(str_parts, sep)
end
-- TODO: nvim-tools

---NOTE: Does not add a final newline
---@param line string
---@param first_indent integer
---@param indent integer
---@param text_width integer
---@param reset_arg integer
---@return string
local function wrap_line(line, first_indent, indent, text_width, reset_arg)
    if line == nil or string.find(line, "[^%s]") == nil then
        return ""
    end

    if reset_arg > 0 then
        line = line:gsub("^%s{0," .. reset_arg .. "}", "")
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
-- No need to rtrim here because the loop only grabs non-whitespace portions.

--- Assumes that lines are already cleanly separated by single "\n" characters
--- @param text string
--- @param first_indent integer Only applied to the first unwrapped line
--- @param indent integer
--- @param text_width integer
--- @param reset_indent boolean Remove all leading whitespace before adding new indentation.
--- @return string wrapped Does not contain a trailing \n
function M.wrap(text, first_indent, indent, text_width, reset_indent)
    if not text or text == "" or text_width < 1 then
        return text or ""
    end

    local lines = vim.split(text, "\n", { plain = true })

    local reset_arg = 0
    if reset_indent then
        local min_ws = math.huge
        for _, line in ipairs(lines) do
            if line and line:find("%S") then -- only non-blank lines affect the common indent
                local _, ws_end = string.find(line, "^%s*")
                local ws_len = ws_end or 0
                if ws_len < min_ws then
                    min_ws = ws_len
                end
            end
        end
        reset_arg = (min_ws == math.huge) and 0 or min_ws
    end

    local res = {}

    local first_line = lines[1]
    local this_fin_indent = string.find(first_line, "^•", 1) and first_indent + 2 or indent
    res[1] = wrap_line(lines[1], first_indent, this_fin_indent, text_width, reset_arg)

    for i = 2, #lines do
        local line = lines[i]
        local this_indent = string.find(line, "^•", 1) and indent + 2 or indent
        res[#res + 1] = wrap_line(line, indent, this_indent, text_width, reset_arg)
    end

    return table.concat(res, "\n")
end
-- NON: Don't remove the text width variable even though it exists as a constant. Keeps the
-- function flexible.

return M

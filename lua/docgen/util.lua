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
---@param t1 T[] Modified in place!
---@param ... any[]
---@return any[] The original reference with the additional lists appended.
function M.list_chain(t1, ...)
    local nargs = select("#", ...)
    for i = 1, nargs do
        local tn = select(i, ...)
        local tn_len = #tn
        for j = 1, tn_len do
            t1[#t1 + 1] = tn[j]
        end
    end

    return t1
end

---@generic T
---@param tt T[][]
---@return integer?
function M.list_common_prefix(tt)
    local tt_len = #tt
    if tt_len == 0 then
        return
    elseif tt_len == 1 then
        local tt_len_one = #tt[1]
        return tt_len_one > 0 and tt_len_one or nil
    end

    local tt_len_min = math.huge
    for i = 1, tt_len do
        local tt_len_i = #tt[i]
        if tt_len_i == 0 then
            return nil
        end

        tt_len_min = math.min(tt_len_min, tt_len_i)
    end

    for col = 1, tt_len_min do
        local v = tt[1][col]
        for row = 2, tt_len do
            if tt[row][col] ~= v then
                local common_prefix_end = col - 1
                return common_prefix_end > 0 and common_prefix_end or nil
            end
        end
    end

    return tt_len_min
end

---@generic T
---@param tt T[][]
---@return integer?
function M.table_common_prefix(tt)
    local tt_count = 0
    local tt_len_min = math.huge

    for _, v in pairs(tt) do
        tt_count = tt_count + 1
        local len = #v
        if len == 0 then
            return nil
        end

        if len < tt_len_min then
            tt_len_min = len
        end
    end

    if tt_count == 0 then
        return nil
    end
    if tt_count == 1 then
        return tt_len_min
    end

    for col = 1, tt_len_min do
        local v
        for _, row in pairs(tt) do
            local this_v = row[col]
            if v == nil then
                v = this_v
            elseif this_v ~= v then
                local common_prefix_end = col - 1
                return common_prefix_end > 0 and common_prefix_end or nil
            end
        end
    end

    return tt_len_min
end

---@param val integer?
---@param len integer
---@param default integer
---@return integer
local function resolve_iter_index(val, len, default)
    val = val and math.min(val, len) or default
    return val > 0 and val or math.max(len + val, 1)
end

---@generic T
---@param t T[] Modified in place!
---@param v T
---@param idx? integer See |iter-indexing|
---     If no index, append to the end like |table.insert()|
function M.list_insert_at(t, v, idx)
    local t_len = #t
    if not idx then
        t[t_len + 1] = v
        return
    end

    local res_idx = resolve_iter_index(idx, t_len, t_len)
    local stop = res_idx + 1
    for i = t_len + 1, stop, -1 do
        t[i] = t[i - 1]
    end

    t[res_idx] = v
end

---@generic T
---@param t T[]
---@return T[]
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
---@param v T
---@return boolean
function M.list_contains(t, v)
    local t_len = #t
    for i = 1, t_len do
        if t[i] == v then
            return true
        end
    end

    return false
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
---@param f fun(x: T): U[]
---@return U[]
function M.list_flat_map_to(t, f)
    local t_len = #t
    local res = {}
    for i = 1, t_len do
        local v = t[i]
        local vm = f(v)
        local vm_len = #vm
        for j = 1, vm_len do
            res[#res + 1] = vm[j]
        end
    end

    return res
end
-- TODO: nvim-tools

---@param rev boolean?
---@param start integer
---@param stop integer
---@return integer start, integer stop, integer step
local function resolve_rev(rev, start, stop)
    if rev then
        return stop, start, -1
    else
        return start, stop, 1
    end
end

---@generic T
---@generic U
---@param t T[]
---@param init U
---@param f fun(acc:U, x:T, idx:integer): acc:U|nil
---@param rev boolean|nil (Default: `false`)
---@return U
function M.list_fold(t, init, f, rev, start, stop)
    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if t_len == 0 or start > stop then
        return init
    end

    local step
    start, stop, step = resolve_rev(rev, start, stop)
    local acc_ret = init
    for i = start, stop, step do
        local acc = f(acc_ret, t[i], i)
        if acc ~= nil then
            acc_ret = acc
        else
            return acc_ret
        end
    end

    return acc_ret
end

---@generic T
---@param t T[]
---@param f fun(x: T, idx: integer): any
---@param start? integer
---@param stop? integer
function M.list_filter_map(t, f, start, stop)
    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if t_len == 0 or start > stop then
        return t
    end

    local j = start
    for i = start, stop do
        local vm = f(t[i], i)
        if vm ~= nil then
            t[j] = vm
            j = j + 1
        end
    end

    for i = stop + 1, t_len do
        t[j] = t[i]
        j = j + 1
    end

    for i = j, t_len do
        t[i] = nil
    end

    return t
end
-- TODO: Find locations where this is used with copy and replace with filter_map_to

---@generic T
---@generic U
---@param t T[]
---@param f fun(x:T, idx:integer): U|nil
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`.
---@return U[]
function M.list_filter_map_to(t, f, start, stop)
    vim.validate("t", t, "table")
    vim.validate("f", f, "callable")
    local is_int = require("nvim-tools.types").is_int
    vim.validate("start", start, is_int, true)
    vim.validate("stop", stop, is_int, true)

    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    local ret = {}
    if t_len == 0 or start > stop then
        return ret
    end

    local before_start = start - 1
    for i = 1, before_start do
        ret[i] = t[i]
    end

    local j = start
    for i = start, stop do
        local vm = f(t[i], i)
        if vm ~= nil then
            ret[j] = vm
            j = j + 1
        end
    end

    for i = stop + 1, t_len do
        ret[j] = t[i]
        j = j + 1
    end

    return ret
end
---@generic T
---@generic U
---@generic V
---@param t T[] Modified in place!
---@param init V
---@param f fun(acc:V, value:T, idx:integer): V, U|nil
---@return T[]
function M.list_filter_map_accum(t, init, f)
    local t_len = #t
    local acc = init
    local j = 1
    for i = 1, t_len do
        local a, vm = f(acc, t[i], i)
        acc = a
        if vm ~= nil then
            t[j] = vm
            j = j + 1
        end
    end

    for i = j, t_len do
        t[i] = nil
    end

    return t
end
-- TODO: Remove if this remains unusd.

---@generic T
---@generic U
---@generic V
---@param t1 T[]
---@param t2 U[]
---@param f fun(a:T, b:U, idx:integer): val:V|nil If val is `nil`, it will be filtered.
---@return V[] Reference to `t1`.
function M.list_filter_map_two(t1, t2, f)
    local t1_len = #t1
    local len = math.min(t1_len, #t2)
    local j = 1
    for i = 1, len do
        local vm = f(t1[i], t2[i], i)
        if vm ~= nil then
            t1[j] = vm
            j = j + 1
        end
    end

    for i = j, t1_len do
        t1[i] = nil
    end

    return t1
end

---@generic T
---@param t T[] Modified in place!
---@param sep T
---@param unit_size integer? (Default: `1`)
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@return T[] Original list reference
function M.list_intersperse(t, sep, unit_size, start, stop)
    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if t_len == 0 or start >= stop then
        return t
    end

    unit_size = math.max(unit_size or 1, 1)
    local iter_len = stop - start + 1
    local sep_count = math.floor((iter_len - 1) / unit_size)
    if sep_count < 1 then
        return t
    end

    local tail = (t_len - stop) + (iter_len - (sep_count * unit_size))
    local i = t_len + sep_count
    local j = t_len
    for _ = 1, tail do
        t[i] = t[j]
        i = i - 1
        j = j - 1
    end

    for _ = 1, sep_count do
        t[i] = sep
        i = i - 1
        for _ = 1, unit_size do
            t[i] = t[j]
            i = i - 1
            j = j - 1
        end
    end

    return t
end

---@generic T
---@param t T[] Modified in place!
---@param start integer?
---@param stop? integer
---@return T[] Reference to `t`.
function M.list_splice(t, start, stop)
    local t_len = #t
    if t_len == 0 then
        return t
    end

    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if start > stop then
        return M.list_clear(t)
    elseif start == 1 and stop == t_len then
        return t
    end

    if start > 1 then
        local j = 1
        for i = start, stop do
            t[j] = t[i]
            j = j + 1
        end
    end

    local new_len = stop - start + 1
    for i = new_len + 1, t_len do
        t[i] = nil
    end

    return t
end

---@generic T
---@generic U
---@generic V
---@param t T[]
---@param init U
---@param f fun(acc:U, v:T, idx:integer): acc:U|nil, v:V|nil
---@param b? fun(acc:U): acc:U|nil, v:V|nil
---@param z? fun(acc:U): v:V|nil
---@param start integer? (Default: `1`)
---@param stop? integer Default: Length of `t`
---@param rev? boolean (Default: `false`)
---@return V[] New list.
function M.list_transduce(t, init, f, b, z, start, stop, rev)
    local ret = {}
    local t_len = #t
    start = resolve_iter_index(start, t_len, 1)
    stop = resolve_iter_index(stop, t_len, t_len)
    if t_len == 0 or start > stop then
        return ret
    end

    local acc_stored = init
    if b then
        local acc, v = b(acc_stored)
        if v then
            ret[#ret + 1] = v
        end

        if acc == nil then
            return ret
        else
            acc_stored = acc
        end
    end

    local step
    start, stop, step = resolve_rev(rev, start, stop)
    for i = start, stop, step do
        local acc, v = f(acc_stored, t[i], i)
        if v ~= nil then
            ret[#ret + 1] = v
        end

        if acc == nil then
            break
        else
            acc_stored = acc
        end
    end

    if z then
        local v = z(acc_stored)
        if v ~= nil then
            ret[#ret + 1] = v
        end
    end

    return ret
end

---@generic T
---@generic U
---@param t [T, U][]
---@return T[], U[]
function M.list_unzip(t)
    local first = {}
    local second = {}

    local t_len = #t
    for i = 1, t_len do
        first[i] = t[i][1]
        second[i] = t[i][2]
    end

    return first, second
end

---@generic T
---@generic U
---@generic V
---@param t T[]
---@param f fun(x:T): k:U, v:V
function M.list_map_to_table(t, f)
    local res = {}
    local t_len = #t
    for i = 1, t_len do
        local k, v = f(t[i])
        if k and v then
            res[k] = v
        end
    end

    return res
end

---@generic T, U, V
---@param t table<T, U>
---@param f fun(key:T, val:U): vm:V
---@return table<T, V>
function M.table_filter_map_to(t, f)
    local res = {}
    for k, v in pairs(t) do
        local vm = f(k, v)
        if vm then
            res[k] = vm
        end
    end

    return res
end

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

---@param txt string
---@param prefix string
---@return string
function M.tag_from_txt(txt, prefix)
    local prefixed = M.checked_prepend(prefix, "-", txt, function(left, right)
        return not vim.startswith(right, left)
    end)

    return M.checked_surround(prefixed, "*")
end

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

---@param left string?
---@param sep string
---@param right string
---@param f? fun(left:string, right:string): do_prepend:boolean
---@return string
function M.checked_append(left, sep, right, f)
    if not left then
        return right
    end

    local is_f = true
    if f then
        is_f = f(left, right)
    end

    if is_f then
        return left .. sep .. right
    else
        return left
    end
end
-- TODO: Must be outlineable behavior here
-- TODO:DEP: Add this to nvim-tools with checked_prepend. Wait until the docgen is done.

---@param left string
---@param sep string
---@param right string?
---@param f? fun(left:string, right:string): do_prepend:boolean
---@return string
function M.checked_prepend(left, sep, right, f)
    if not right then
        return left
    end

    local is_f = true
    if f then
        is_f = f(left, right)
    end

    if is_f then
        return left .. sep .. right
    else
        return right
    end
end
-- TODO: nvim-tools

---@param text string
---@param surround string
---@return string
function M.checked_surround(text, surround)
    local line = text
    if not vim.startswith(line, surround) then
        line = surround .. line
    end

    if not vim.endswith(text, surround) then
        line = line .. surround
    end

    return line
end
-- TODO: This cannot be the most efficient way to do this.
-- TODO: nvim-tools

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
    M.list_filter_map(str_parts, function(part)
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
-- TODO: I think this function has a problem where if you have a chunk of text that is too
-- big for the wrap condition, it will just infinitely try to wrap it down without ever giving up.
-- MID: This should not break up code spans.
-- No need to rtrim here because the loop only grabs non-whitespace portions.

--- Assumes that lines are already cleanly separated by single "\n" characters
--- @param text string
--- @param first_indent integer Only applied to the first unwrapped line
--- @param indent integer
--- @param text_width integer
--- @param reset_indent boolean Remove all leading whitespace before adding new indentation.
--- @param align_right? boolean Within the indent and text_width boundary, align the text right
--- @return string wrapped Does not contain a trailing \n
function M.wrap(text, first_indent, indent, text_width, reset_indent, align_right)
    if text == "" or text_width < 1 then
        return ""
    end

    local lines = vim.split(text, "\n", { plain = true })
    local lines_len = #lines
    local reset_arg = (not reset_indent) and 0
        or M.list_fold(lines, math.huge, function(min_ws, line)
            if min_ws == 0 then
                return nil
            end

            if not string.find(line, "%S") then
                return min_ws
            end

            local _, ws_end = string.find(line, "^%s*")
            return math.min(ws_end or 0, min_ws)
        end)

    M.list_filter_map(lines, function(line)
        local this_fin_indent = string.find(line, "^•", 1) and first_indent + 2 or indent
        return wrap_line(line, first_indent, this_fin_indent, text_width, reset_arg)
    end, 1, 1)

    if lines_len > 1 then
        M.list_filter_map(lines, function(line)
            local this_indent = string.find(line, "^•", 1) and indent + 2 or indent
            return wrap_line(line, indent, this_indent, text_width, reset_arg)
        end, 2, 0)
    end

    if not align_right then
        return table.concat(lines, "\n")
    end

    for i = 1, lines_len do
        local line_len = #lines[i]
        local lpad = text_width - line_len
        lines[i] = string.rep(" ", lpad) .. lines[i]
    end

    M.list_filter_map(lines, function(line)
        local line_len = #line
        local lpad = text_width - line_len
        return string.rep(" ", lpad) .. line
    end)

    return table.concat(lines, "\n")
end
-- TODO: The alignment stuff might need value checking
-- TODO: This needs a way to preserve indent, so bulleted lists in briefs don't extend to
-- the beginning of the line.
-- NON: Don't remove the text width variable even though it exists as a constant. Keeps the
-- function flexible.

-----------------------
-- MARK: Other Stuff --
-----------------------

---@param t table<any, true>
---@param k any
---@param err string
function M.err_if_seen_or_add(t, k, err)
    if t[k] then
        error(err)
    else
        t[k] = true
    end
end

---@param map_mode string|nil  One-character mode: '', 'n','v','x','s','o','i','c','t','l','!'
---@return string[]
function M.mode_map_to_short(map_mode)
    if map_mode == nil then
        map_mode = ""
    end

    map_mode = tostring(map_mode):lower()
    if map_mode:match("^%s*$") then
        map_mode = ""
    end

    if map_mode == "" then
        return { "n", "v", "o", "s" }
    elseif map_mode == "n" then
        return { "n" }
    elseif map_mode == "v" then
        return { "v", "s" }
    elseif map_mode == "x" then
        return { "v" }
    elseif map_mode == "s" then
        return { "s" }
    elseif map_mode == "o" then
        return { "o" }
    elseif map_mode == "i" then
        return { "i" }
    elseif map_mode == "c" then
        return { "c" }
    elseif map_mode == "t" then
        return { "t" }
    elseif map_mode == "l" then
        return { "i", "c", "l" }
    elseif map_mode == "!" then
        return { "i", "c" }
    end

    -- TODO: Bad error message.
    local fmt_str = "map_mode.expand: unknown mode %q (expected 0 or 1 char from map-overview)"
    error(string.format(fmt_str, map_mode))
end

---@param abs_path string
---@return string
function M.get_requirable_path(abs_path)
    local dir, name = abs_path:match("^(.*)[/\\]([^/\\]+)%.lua$")
    if not dir or not name then
        error("Expected absolute path to a .lua file, got: " .. tostring(abs_path))
    end

    -- Prepend the directory so require() can find it (priority)
    package.path = dir .. "/?.lua;" .. package.path

    return name
end

return M

local api = vim.api
local fs = vim.fs
local fn = vim.fn
local uv = vim.uv

local M = {}

---------------
-- MARK: Buf --
---------------

---Create a temporary buffer. Always:
---- noml
---- nomod
---- noswf
---- noudf
---
---@param bh? ""|"hide"|"unload"|"delete"|"wipe" Set bufhidden
---"hide" is useful for cached buffers such as previews.
---"wipe" is useful for placeholders, like temporary help buffers used to open helptags in a
---targeted window.
---(default: `hide`)
---@param bl? boolean Set buflisted
---(default: `true`)
---@param bt? ""|"acwrite"|"help"|"nofile"|"nowrite"|"prompt"|"quickfix"|"terminal"
---"nofile" will make the buffer display as "scratch" in the statusline
---"help" can be used for targeted helptag opening
---(default: `""`)
---@param ft? string Set a filetype (useful for preview buffers). nil is a no-op. Set last.
---(default: `""`)
---@param ma? boolean Set modifiable
---(default: `true`)
---@return integer
function M.temp_buf_create(bh, bl, bt, ft, ma)
    local buf = api.nvim_create_buf(bl ~= false, true)
    local buf_scope = { buf = buf }

    if bt then
        api.nvim_set_option_value("bt", bt, buf_scope)
    end

    -- Set unconditionally because of autocmds/global settings
    api.nvim_set_option_value("bh", bh or "hide", buf_scope)
    api.nvim_set_option_value("swf", false, buf_scope)
    api.nvim_set_option_value("udf", false, buf_scope)

    if ma == false then
        api.nvim_set_option_value("ma", false, buf_scope)
    end

    if ft ~= nil then
        api.nvim_set_option_value("ft", ft, buf_scope)
    end

    return buf
end

--------------
-- MARK: Fs --
--------------

---@param path string
---@return boolean, string?
function M.file_read(path)
    local fd, o_err, o_err_name = uv.fs_open(path, "r", 292)
    if not fd then
        local msg = "(" .. path .. ") " .. o_err_name .. ": " .. o_err
        return false, msg
    end

    local fstat, f_err, f_err_name = uv.fs_fstat(fd)
    if not fstat then
        uv.fs_close(fd, function() end)
        local msg = "(" .. path .. ") " .. f_err_name .. ": " .. f_err
        return false, msg
    end

    local text, r_err, r_err_name = uv.fs_read(fd, fstat.size, 0)
    uv.fs_close(fd, function() end)
    if not text then
        local msg = "(" .. path .. ") " .. r_err_name .. ": " .. r_err
        return false, msg
    else
        return true, text
    end
end

----------------
-- MARK: Math --
----------------

---@param x integer
---@param y integer
---@param min integer
---@param max integer
---@return integer
function M.wrapping_add(x, y, min, max)
    local period = max - min + 1
    return ((x - min + y) % period) + min
end

---@param x integer
---@param y integer
---@param min integer
---@param max integer
---@return integer
function M.wrapping_sub(x, y, min, max)
    local period = max - min + 1
    return ((x - y - min) % period) + min
end

----------------
-- MARK: Misc --
----------------

---@param f fun(...:any): boolean
---@return fun(...:any): boolean
function M.complement(f)
    return function(...)
        return not f(...)
    end
end

---@param mode string Potentially multi-character mode.
---@return boolean
function M.is_vmode(mode)
    return mode == "v" or mode == "V" or mode == "\22"
end
-- MID: Unsure how to get to block mode with string.byte.

---@param pos_1 string
---@param pos_2 string
---@param mode? string
---@param exclusive? boolean If nil, use the option value.
function M.region_from_positions(pos_1, pos_2, mode, exclusive)
    local cur = fn.getpos(pos_1)
    local fin = fn.getpos(pos_2)
    mode = mode or "v"
    if exclusive == nil then
        ---@type string
        local sel = api.nvim_get_option_value("selection", { scope = "global" })
        exclusive = sel == "exclusive"
    end

    local region_opts = { type = mode, exclusive = exclusive }
    return fn.getregionpos(cur, fin, region_opts)
end

-----------------
-- MARK: Range --
-----------------

---@param region [[integer, integer, integer, integer], [integer, integer, integer, integer]][]
---@return [integer, integer, integer, integer]
function M.range_from_region(region)
    return {
        region[1][1][2],
        region[1][1][3],
        region[#region][2][2],
        region[#region][2][3],
    }
end

---Converts a qf range (1,1,1,1 end-exclusive) to API (0,0,0,0 end-exclusive)
---@param r [uinteger, uinteger, uinteger, uinteger] Modified in place!
---@return [uinteger, uinteger, uinteger, uinteger] Reference to `r`.
function M.qf_to_api(r)
    r[1] = r[1] - 1
    r[2] = r[2] - 1
    r[3] = r[3] - 1
    r[4] = r[4] - 1
    return r
end

---@param lnum integer
---@param col integer
---@param end_lnum integer
---@param end_col integer
---@return [uinteger, uinteger, uinteger, uinteger]
local function qf_unresolved(lnum, col, end_lnum, end_col)
    lnum = math.max(lnum, 1)
    col = math.max(col, 1)
    end_lnum = math.max(end_lnum, lnum)
    if end_lnum == lnum then
        end_col = math.max(end_col, col + 1)
    else
        end_col = math.max(end_col, 1)
    end

    return { lnum, col, end_lnum, end_col }
end

---Cannot use virtcol2col: it walks the window's display of a buffer line (inline virt text,
---'linebreak'/'showbreak'). This walks the string, like |strdisplaywidth()|.
---
---@param line string
---@param vcol integer 1-indexed
---@param charlen integer Result of strcharlen() on `line` (callers may already have it)
---@param qf boolean If true, tabs are always 8 cells (qf viscol / errorformat `%v`); otherwise
---the current window's 'tabstop' is used
---@return integer, integer, integer start byte, last byte, char idx (all 0-indexed)
local function vcol_to_byte_bounds(line, vcol, charlen, qf)
    if #line == 0 or vcol <= 0 then
        return 0, 0, 0
    end

    if charlen <= 1 then
        return 0, #line - 1, 0
    end

    local col = 0
    ---@type integer
    local start_byte = 0
    ---@type integer
    local fin_byte = 0
    for charidx = 0, charlen - 1 do
        start_byte = vim.call("byteidx", line, charidx)
        fin_byte = vim.call("byteidx", line, charidx + 1)
        local ch = string.sub(line, start_byte + 1, fin_byte)
        ---@type integer
        local w
        if qf and ch == "\t" then
            w = 8 - (col % 8)
        else
            w = vim.call("strdisplaywidth", ch, col)
        end

        col = col + w
        if col >= vcol then
            local last = fin_byte - 1
            ---@cast last integer
            return start_byte, last, charidx
        end
    end

    local last = fin_byte - 1
    local last_char = charlen - 1
    ---@cast last integer
    ---@cast last_char integer
    return start_byte, last, last_char
end

---@param end_col uinteger 0 for omitted, or 1 indexed (exclusive bytes, or last viscol if vcol)
---@param end_line string
---@param row_1 uinteger
---@param end_row_1 uinteger
---@param charlen uinteger
---@param col_1 uinteger
---@param vcol 0|1
---@return uinteger 1 indexed, exclusive
local function qf_end_col_get(end_col, end_line, row_1, end_row_1, charlen, col_1, vcol)
    local end_line_len = #end_line
    if end_line_len == 0 then
        return 1
    end

    local end_idx_ = end_line_len + 1
    if end_col == 0 then
        return end_idx_
    end

    local end_col_1_
    if vcol == 1 then
        -- qf_viscol applies to end_col too. %k with %v is the last screen column.
        local end_charlen = row_1 == end_row_1 and charlen or vim.call("strcharlen", end_line)
        local _, last_b, _ = vcol_to_byte_bounds(end_line, end_col, end_charlen, true)
        end_col_1_ = math.min(last_b + 2, end_idx_)
    else
        end_col_1_ = math.min(end_col, end_idx_)
    end

    if row_1 ~= end_row_1 then
        return end_col_1_
    end

    local charidx = vim.call("charidx", end_line, col_1 - 1, 1)
    local next_byteidx = charidx < charlen and vim.call("byteidx", end_line, charidx + 1)
        or end_line_len

    return math.max(end_col_1_, next_byteidx + 1)
end

---@param col uinteger 0 for omitted, or 1 indexed, inclusive
---@param vcol 0|1
---@param line string
---@param charlen uinteger
---@return uinteger 1 indexed
local function qf_col_get(col, vcol, line, charlen)
    if col == 0 or #line == 0 then
        return 1
    end

    if vcol == 0 then
        return math.min(col, #line)
    end

    local col_0, _, _ = vcol_to_byte_bounds(line, col, charlen, true)
    return col_0 + 1
end

---Loaded buffers and non-file URIs use the buffer. `file://` unloaded buffers are read from disk
---so ftplugin / local options are not run.
---@param buf uinteger
---@return boolean
local function buf_use_loaded_lines(buf)
    if api.nvim_buf_is_loaded(buf) then
        return true
    end

    if vim.startswith(vim.uri_from_bufnr(buf), "file://") then
        return false
    end

    fn.bufload(buf)
    return true
end

---@param buf uinteger
---@return string?
local function unloaded_file_text(buf)
    local abs_path = fs.normalize(fn.fnamemodify(api.nvim_buf_get_name(buf), ":p"))
    local ok, text = M.file_read(abs_path)
    if ok == false or text == nil then
        return nil
    end

    return text
end

---@param text string
---@return uinteger
local function text_line_count(text)
    if text == "" then
        return 1
    end

    local n = 1
    for _ in string.gmatch(text, "\n") do
        n = n + 1
    end

    if vim.endswith(text, "\n") then
        n = n - 1
    end

    return n
end

---@param buf uinteger
---@return uinteger
local function get_line_count(buf)
    if buf_use_loaded_lines(buf) then
        return api.nvim_buf_line_count(buf)
    end

    local text = unloaded_file_text(buf)
    if text == nil then
        return 0
    end

    return text_line_count(text)
end

---@param buf uinteger
---@param lines table<uinteger, string> Modified in place! 0 indexed.
local function get_lines_from_buf_loaded(buf, lines)
    for row, _ in pairs(lines) do
        lines[row] = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    end
end

---Create a new |lua-dict| from mapped values of `t` with an accumulator.
---@generic K, V, M, A
---@param t table<K, V>
---@param init A Returns an empty table if `nil`.
---@param f fun(acc:A, k:K, v:V): A?, M? Accumulator always updates even if the value is filtered.
---@return table<K, M>, A
---New table and final accumulator.
local function filter_map_accum_to(t, init, f)
    local ret = {}
    local acc = init
    if acc == nil then
        return ret, acc
    end

    for k, v in pairs(t) do
        local acc_new, vm = f(acc, k, v)
        if acc_new == nil then
            return ret, acc
        end

        acc = acc_new
        if vm ~= nil then
            ret[k] = vm
        end
    end

    return ret, acc
end

---Bespoke version because the Nvim core util is private.
---@param buf uinteger
---@param rows table<uinteger, boolean> 0 indexed
---@return table<uinteger, string>
local function get_lines(buf, rows)
    local lines, needed = filter_map_accum_to(rows, 0, function(total, _, _)
        return total + 1, ""
    end)

    ---@cast lines table<uinteger, string>
    if buf_use_loaded_lines(buf) then
        get_lines_from_buf_loaded(buf, lines)
        return lines
    end

    local text = unloaded_file_text(buf)
    if text == nil then
        -- LOW-DEP: Can design more nuanced error handling if an actual scenario comes up.
        return lines
    end

    local row = 0
    for line in vim.gsplit(text, "\n", { plain = true }) do
        if lines[row] ~= nil then
            lines[row] = line
            needed = needed - 1
            if needed == 0 then
                break
            end
        end

        row = row + 1
    end

    return lines
end

---Treat qf byte columns as end exclusive because vimgrep and LSP diagnostics are.
---When vcol is set, col/end_col are screen columns (errorformat %v/%k); end_col is the last
---included screen column.
---@param entry vim.quickfix.entry
---@return [uinteger, uinteger, uinteger, uinteger] 1,1,1,1 indexed, end exclusive
function M.qf_from_entry(entry)
    local lnum = entry.lnum or 1
    local col = entry.col or 0
    local end_lnum = entry.end_lnum or 0
    local end_col = entry.end_col or 0
    local buf = entry.bufnr
    if buf == nil or buf < 1 or lnum < 1 or not api.nvim_buf_is_valid(buf) then
        return qf_unresolved(lnum, col, end_lnum, end_col)
    end

    local line_count = get_line_count(buf)
    if line_count < 1 then
        return qf_unresolved(lnum, col, end_lnum, end_col)
    end

    local vcol = entry.vcol or 0
    ---@cast vcol (0|1)
    local row_1 = math.min(lnum, line_count)
    local end_row_1 = math.min(math.max(end_lnum, row_1), line_count)
    local lines = get_lines(buf, { [row_1 - 1] = true, [end_row_1 - 1] = true })
    local line = lines[row_1 - 1] or ""
    local charlen = vim.call("strcharlen", line)
    local col_1 = qf_col_get(col, vcol, line, charlen)

    local end_line = end_row_1 == row_1 and line or (lines[end_row_1 - 1] or "")

    local end_col_1_ = qf_end_col_get(end_col, end_line, row_1, end_row_1, charlen, col_1, vcol)
    return { row_1, col_1, end_row_1, end_col_1_ }
end

-----------------
-- MARK: Table --
-----------------

---@param start uinteger
---@param stop uinteger
---@param rev? boolean
---@return uinteger start, uinteger stop, uinteger step
local function resolve_rev(start, stop, rev)
    if not rev then
        return start, stop, 1
    end

    return stop, start, -1
end

-- Port of Neovim core logic since their table module is private
local has_clear, clear = pcall(require, "table.clear")
if not has_clear then
    clear = function(t)
        for k in pairs(t) do
            t[k] = nil
        end
    end
end
---@cast clear fun(tab: table)

---Clear all list and dict data from a table. Runs `table.clear` on LuaJIT builds.
---@type fun(tab:table)
M.clear = clear

---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean
local function i_all_do(t_len, t, f)
    for i = 1, t_len do
        if not f(t[i]) then
            return false
        end
    end

    return true
end

---Checks if all items in |lua-list| `t` satisfy predicate function `f`.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean `True` if length of `t` is zero.
function M.i_all(t, f)
    return i_all_do(#t, t, f)
end

---Checks if any items in |lua-list| `t` satisfy predicate function `f`.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@return boolean `False` if `t` is empty.
function M.i_any(t, f)
    local t_len = #t
    for i = 1, t_len do
        if f(t[i]) then
            return true
        end
    end

    return false
end

---@generic T
---@param lists_len uinteger
---@param lists T[][]
---@param dst T[] Modified in place!
local function lists_append(lists_len, lists, dst)
    local j = #dst + 1
    for i = 1, lists_len do
        local tn = lists[i]
        local tn_len = #tn
        for k = 1, tn_len do
            dst[j] = tn[k]
            j = j + 1
        end
    end
end

---Append each list in `...`, in order, to `t1`. References are shallow-copied.
---@generic T
---@param t1 T[] Modified in place!
---@param ... T[]
---@return T[] Reference to `t1`.
function M.i_append(t1, ...)
    local nargs = select("#", ...)
    if nargs == 0 then
        return t1
    end

    lists_append(nargs, { ... }, t1)
    return t1
end

---Assumes:
---- Length of `t` > 0
---- `start` and `stop` are valid.
---@generic T
---@param t T[]
---@param start uinteger
---@param stop uinteger
local function i_copy_exact(t, start, stop)
    local ret = M.new(stop - start + 1, 0)
    local j = 1
    for i = start, stop do
        ret[j] = t[i]
        j = j + 1
    end

    return ret
end

---Creates a shallow copy of the |lua-list| elements of `t`.
---@nodiscard
---@generic T
---@param t T[]
---@return T[]
function M.i_copy(t)
    local t_len = #t
    if t_len == 0 then
        return {}
    end

    return i_copy_exact(t, 1, t_len)
end

---@generic T, U
---@param t_len uinteger
---@param t T[]
---@param f fun(x:T, idx:uinteger): T|U|nil
---@param dst T[] Modified in place!
---@return uinteger
local function i_filter_map_do(t_len, t, f, dst)
    local j = 1
    for i = 1, t_len do
        local vm = f(t[i], i)
        if vm ~= nil then
            dst[j] = vm
            j = j + 1
        end
    end

    return j
end

---Create a new |lua-list| by applying function `f` to the values of `t`.
---@generic T, U
---@param t T[]
---@param f fun(x:T, idx:uinteger): U `nil` returns are filtered.
---@return U[] New table. Empty if all elements are filtered.
function M.i_filter_map_to(t, f)
    local ret = {}
    i_filter_map_do(#t, t, f, ret)
    return ret
end

---Return the first item and its index from `t` satisfying predicate function `f`.
---@generic T
---@param t T[]
---@param f fun(x:T): boolean
---@param rev? boolean (Default: `false`) Iterate from the end.
---@return T?, uinteger?
function M.i_find(t, f, rev)
    local t_len = #t
    if t_len == 0 then
        return
    end

    local start, stop, step = resolve_rev(1, t_len, rev)
    for i = start, stop, step do
        local v = t[i]
        if f(v) then
            return v, i
        end
    end
end

---Transform the elements of `t` into a single value using an accumulator.
---@see |i_reduce()| to initialize with the first value of the list.
---@generic T, A
---@param t T[]
---@param init A First accumulator value. No-op if this is `nil`.
---@param f fun(acc:A, x:T, idx:uinteger): A? If `nil` is returned, folding stops and the
---current accumulator is returned.
---@return A `init` if `t` is length zero.
function M.i_fold(t, init, f)
    local t_len = #t
    if t_len == 0 or init == nil then
        return init
    end

    local acc_ret = init
    for i = 1, t_len, 1 do
        local acc = f(acc_ret, t[i], i)
        if acc == nil then
            return acc_ret
        end

        acc_ret = acc
    end

    return acc_ret
end

---Credit: Nvim core.
---@generic T
---@param key nil|string|fun(v:T): any
---@return fun(v: T): any
local function key_fn_from_key(key)
    if not key then
        return function(v)
            return v
        end
    end

    if type(key) == "string" then
        local field = key
        key = function(v)
            return v and v[field]
        end
    end

    return key
end

---Check if any item in `t` matches `val`, optionally comparing based on `key`.
---@generic T
---@param t T[]
---@param val T
---@param key nil|string|fun(v:T): any See: |key_fn|.
---@return boolean `False` if `t` is empty or `key` returns any `nil` values.
function M.i_includes(t, val, key)
    local key_fn = key_fn_from_key(key)
    local vh_target = key_fn(val)
    if vh_target == nil then
        return false
    end

    local t_len = #t
    for i = 1, t_len do
        local vh = key_fn(t[i])
        if vh == vh_target then
            return true
        elseif vh == nil then
            return false
        end
    end

    return false
end

---Keep only values from |lua-list| `t` that pass predicate function `f`.
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@return T[] Reference to `t`.
function M.i_keep(t, f)
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

    return t
end

---Apply a function to all elements of a list, transforming them into a single value. The first
---accumulator will be the first element of the list (last if iterating in reverse).
---@see |i_fold()| to specify an initial accumulator.
---@generic T
---@param t T[]
---@param f fun(acc:T, v:T, idx:uinteger): T? If `nil` is returned, reducing stops and the current
---accumulator is returned.
---@return T? `nil` if `t` is length zero.
local function i_reduce(t, f)
    local t_len = #t
    if t_len == 0 then
        return nil
    end

    local acc_ret = t[1]
    for i = 2, t_len, 1 do
        local acc = f(acc_ret, t[i], i)
        if acc == nil then
            return acc_ret
        end

        acc_ret = acc
    end

    return acc_ret
end

---@generic T
---@param t T[]
---@return T `nil` if `t` is length zero.
function M.i_max(t)
    return i_reduce(t, function(acc, v)
        return v > acc and v or acc
    end)
end

---@generic T
---@param t T[]
---@return T `nil` if `t` is length zero.
function M.i_min(t)
    return i_reduce(t, function(acc, v)
        return v < acc and v or acc
    end)
end

-- Port of Neovim core logic since their table module is private
local has_new, new = pcall(require, "table.new")
if not has_new then
    new = function(_narray, _nhash)
        return {}
    end
end
---@cast new fun(narray: integer, nhash: integer): table

---Create a new table. Runs `table.new` on LuaJIT builds.
---@type fun(narray:integer, nhash:integer): table
M.new = new

--------------------
-- MARK: Quickfix --
--------------------

---@param src_win integer|nil
---@param title string
---@return integer|nil
function M.list_nr_with_title(src_win, title)
    local max_nr = M.get_list(src_win, { nr = "$" }).nr ---@type uinteger
    if src_win ~= nil then
        for i = max_nr, 1, -1 do
            local title_i = fn.getloclist(src_win, { nr = i, title = 0 }).title ---@type string
            if title_i == title then
                return i
            end
        end
    else
        for i = max_nr, 1, -1 do
            local title_i = fn.getqflist({ nr = i, title = 0 }).title ---@type string
            if title_i == title then
                return i
            end
        end
    end

    return nil
end

---@param src_win integer|nil
---@param what table
---@return any
function M.get_list(src_win, what)
    return src_win and fn.getloclist(src_win, what) or fn.getqflist(what)
end

---@param src_win uinteger|nil
---@param action "a"|"f"|"r"|"u"|" "
---@param what table
---@return -1|0
function M.set_list(src_win, action, what)
    return src_win and fn.setloclist(src_win, {}, action, what) or fn.setqflist({}, action, what)
end

---@param what_ret table
---@return table
function M.what_ret_to_set(what_ret)
    local what_set = {}

    local wr_nr = what_ret.nr
    what_set.nr = wr_nr ~= nil and wr_nr or 0

    local wr_context = what_ret.context
    what_set.context = type(wr_context) == "table" and wr_context or nil
    local wr_idx = what_ret.idx
    what_set.idx = type(wr_idx) == "number" and wr_idx or nil
    local wr_items = what_ret.items
    what_set.items = type(wr_items) == "table" and wr_items or {}

    local wr_quickfixtextfunc = what_ret.quickfixtextfunc
    local is_qftf_func = type(wr_quickfixtextfunc) == "function"
    local is_qftf_str = type(wr_quickfixtextfunc) == "string" and #wr_quickfixtextfunc > 0
    if is_qftf_func or is_qftf_str then
        what_set.quickfixtextfunc = wr_quickfixtextfunc
    end

    local wr_title = what_ret.title
    local is_title_str = type(wr_title) == "string" and #wr_title > 0
    what_set.title = is_title_str and wr_title or nil

    return what_set
end

---Assumes the cursor is in a list win.
---@param src_win integer|nil
---@return boolean, string, vim.quickfix.entry
function M.get_item_under_cursor(src_win)
    local cur_bt = api.nvim_get_option_value("bt", { buf = 0 }) ---@type string
    if cur_bt ~= "quickfix" then
        return false, "Not a quickfix buffer", {}
    end

    local idx = api.nvim_win_get_cursor(0)[1]
    local items = M.get_list(src_win, { nr = 0, idx = idx, items = true }).items
    if #items >= 1 then
        return true, "", items[1]
    else
        return false, "List is empty", {}
    end
end

---------------
-- MARK: Win --
---------------

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
        local other_wins = M.i_any(tabpage_wins, function(w)
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

---@param p [uinteger, uinteger] 1,0 indexed
---@param buf integer
---@return [uinteger, uinteger] Reference to `p`
local function adj_mark_pos(p, buf)
    if not api.nvim_buf_is_loaded(buf) then
        error("Buffer " .. buf .. " is not loaded")
    end

    p[1] = math.max(math.min(p[1], api.nvim_buf_line_count(buf)), 1)
    local lnum = p[1]

    local line = api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
    local len_line = #line
    local col_0 = math.max(math.min(p[2], len_line - 1), 0)
    p[2] = col_0 + (len_line > 0 and vim.str_utf_start(line, col_0 + 1) or 0)

    return p
end

---@param win integer
---@param cur_pos { [1]:integer, [2]: integer }
---@ return { [1]:integer, [2]: integer }
function M.protected_set_cursor(win, cur_pos)
    local win_buf = api.nvim_win_get_buf(win)
    local new_cur_pos = M.i_copy(cur_pos)
    adj_mark_pos(new_cur_pos, win_buf)
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

--------------
-- MARK: UI --
--------------

---@param opts? vim.ui.input.Opts
---@return boolean, string
function M.input(opts)
    ---@type boolean, string
    local ok, result = pcall(function()
        return fn.input(opts --[[@as table]])
    end)

    if (not ok) and result == "Keyboard interrupt" then
        return true, ""
    else
        return ok, result
    end
end

return M

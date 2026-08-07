local ntt = require("nvim-tools.table")
local nts = require("nvim-tools.str")

--- @class nvim.util.MDNode
--- @field [integer] nvim.util.MDNode
--- @field type string
--- @field text? string

local M = {}

--------------------------
-- MARK: Table Functions --
--------------------------

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
-- TODO: This is used for the deeply nested unravelling in keymaps. That file will change because
-- the input data is changing. I'm not sure this function will survive because it awkwardly
-- captures how I unroll the keymap data.

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
-- TODO: THis is like an in place filter_modify2 or something. Maybe goes into nvim-tools

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

    return nts.checked_surround(prefixed, "*")
end
-- TODO: This is named very generally but also does something quite specific. Bad design.

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
-- TODO: This function is confusing and dumb. Yeet.

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
-- TODO: This function is confusing and dumb. Yeet.

---@param str string
---@param sep string
---@param f fun(part:string): string
function M.str_op_by_sep(str, sep, f)
    local str_parts = vim.split(str, sep)
    ntt.i_filter_modify(str_parts, function(part)
        return f(part)
    end)

    return table.concat(str_parts, sep)
end
-- TODO: Unsure what to do here since it deals with like one really obscure case.

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
        or ntt.i_fold(lines, math.huge, function(min_ws, line)
            if min_ws == 0 then
                return nil
            end

            if not string.find(line, "%S") then
                return min_ws
            end

            local _, ws_end = string.find(line, "^%s*")
            return math.min(ws_end or 0, min_ws)
        end)

    ntt.i_filter_modify(lines, function(line)
        local this_fin_indent = string.find(line, "^•", 1) and first_indent + 2 or indent
        return wrap_line(line, first_indent, this_fin_indent, text_width, reset_arg)
    end, 1, 1)

    if lines_len > 1 then
        ntt.i_filter_modify(lines, function(line)
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

    ntt.i_filter_modify(lines, function(line)
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
-- TODO: This handles some weird nonsense in the keymap writing that I can't rationally comprehend.
-- I think it was something to do with like, different plugs being written for different modes
-- or something. But the docs should just be written like how the keymaps are defined, since
-- that's how it behaves in Neovim.

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

-- TODO: Remove bespoke implementations from here and use nvim-tools as the source of truth.
-- TODO: Go through everything. See if it should be in nvim-tools and/or if the current
-- implementation matches what's in Nvim-tools.

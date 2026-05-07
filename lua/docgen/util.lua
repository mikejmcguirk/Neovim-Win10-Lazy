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

-- --- @param x string
-- --- @param start_indent integer
-- --- @param indent integer
-- --- @param text_width integer
-- --- @return string
-- function M.wrap(x, start_indent, indent, text_width)
--     local words = vim.split(vim.trim(x), "%s+")
--     local parts = { string.rep(" ", start_indent) } --- @type string[]
--     local len_cur_line = indent
--
--     for i, w in ipairs(words) do
--         if len_cur_line > indent and len_cur_line + #w > text_width - 1 then
--             parts[#parts + 1] = "\n"
--             parts[#parts + 1] = string.rep(" ", indent)
--             len_cur_line = indent
--         elseif i ~= 1 then
--             parts[#parts + 1] = " "
--             len_cur_line = len_cur_line + 1
--         end
--         len_cur_line = len_cur_line + #w
--         parts[#parts + 1] = w
--     end
--
--     return (table.concat(parts):gsub("%s+\n", "\n"):gsub("\n+$", ""))
-- end

-- Pre-compiled regexes (zero cost after first use)
local non_ws_re = vim.regex([[\S+]])
local ws_re = vim.regex([[\s+]])

local function wrap_single_line(line, first_indent, cont_indent, width)
    if line == "" then
        return string.rep(" ", first_indent)
    end

    local parts = { string.rep(" ", first_indent) }
    local cur_len = first_indent
    local pos = 0
    local is_first_chunk = true

    -- TODO: How does the current code handle the thing where you are able to successfully
    -- wrap to text width on the half complete line

    while true do
        local s, e = non_ws_re:match_str(line:sub(pos + 1))
        if not s then
            break
        end

        -- TODO: We should not be doing this
        local token = line:sub(pos + s + 1, pos + e)
        local token_len = e - s

        -- Soft-wrap *before* this token if it doesn't fit (never on the very first chunk)
        if not is_first_chunk and cur_len + token_len > width then
            -- Remove now-trailing whitespace from the line we're leaving
            parts[#parts] = parts[#parts]:gsub("%s+$", "")

            -- New split starts with continuation indent
            table.insert(parts, "\n")
            table.insert(parts, string.rep(" ", cont_indent))
            cur_len = cont_indent
            is_first_chunk = true
        end

        table.insert(parts, token)
        cur_len = cur_len + token_len
        is_first_chunk = false
        pos = pos + e

        -- === Preserve the following \s+ run exactly (if it fits) ===
        s, e = ws_re:match_str(line:sub(pos + 1))
        if s then
            local ws = line:sub(pos + s + 1, pos + e)
            local ws_len = e - s

            if cur_len + ws_len <= width then
                table.insert(parts, ws)
                cur_len = cur_len + ws_len
            end
            -- (If the whitespace run didn't fit we just drop it – it becomes the
            -- leading whitespace on the *new* line that we already replaced.)
            pos = pos + e
        end
    end

    return table.concat(parts)
end

--- @param x string
--- @param first_indent integer
--- @param indent integer
--- @param text_width integer
--- @return string
function M.wrap(x, first_indent, indent, text_width)
    x = x:gsub("\t", string.rep(" ", 8))
    local orig_lines = vim.split(x, "\n", { plain = true })

    local result = {}
    for _, line in ipairs(orig_lines) do
        -- TODO: This is only relevant once
        if #result > 0 then
            table.insert(result, "\n")
        end

        if not line:match("^%s*$") then
            local wrapped = wrap_single_line(line, first_indent, indent, text_width)
            table.insert(result, wrapped)
        end
    end

    local out = table.concat(result)

    local sub_line, _ = string.gsub(string.gsub(out, "%s+\n", "\n"), "\n+$", "")
    return sub_line
end

return M

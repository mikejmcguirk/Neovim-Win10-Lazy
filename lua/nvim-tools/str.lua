local api = vim.api

local M = {}

---@param str string
---@param char string
---@param target_width integer
local function str_pad_get_chars_count(str, char, target_width)
    -- Use nvim_strwidth instead of strdisplaywidth because the latter's tab expansions are
    -- dependent on window context.
    local width_rem = target_width - api.nvim_strwidth(str)
    if width_rem > 0 then
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
---@param target_width integer
function M.lpad(str, char, target_width)
    local chars_count = str_pad_get_chars_count(str, char, target_width)
    if chars_count > 0 then
        return string.rep(char, chars_count) .. str
    end

    return str
end

---@param str string
---@return string
function M.ltrim(str)
    local gsubbed, _ = string.gsub(str, "^%s+", "")
    return gsubbed
end

---@param str string
---@return string
function M.rtrim(str)
    local matched = string.match(str, "^.*%S")
    if matched then
        return matched
    end

    return ""
end

---@param str string
---@param char string
---@param target_width integer
function M.rpad(str, char, target_width)
    local chars_count = str_pad_get_chars_count(str, char, target_width)
    if chars_count > 0 then
        return str .. string.rep(char, chars_count)
    end

    return str
end

---@param str string
---@return string, integer
function M.lua_pattern_escape(str)
    return string.gsub(str, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
end

---@audited 2026-07-03
---@param str string
---@param byte integer
---@return boolean
function M.startswith_byte(str, byte)
    return #str > 0 and string.byte(str, 1) == byte
end

---@audited 2026-07-03
---@param str string
---@param byte integer
---@return boolean
function M.endswith_byte(str, byte)
    local len_str = #str
    return len_str > 0 and string.byte(str, len_str) == byte
end

---@param str string
---@return string[]
function M.split_map(str)
    local result = {}
    local i = 1
    while i <= #str do
        if string.byte(str, i) == 60 then
            local j = str:find(">", i)
            if j then
                table.insert(result, str:sub(i, j))
                i = j + 1
            else
                table.insert(result, str:sub(i, i))
                i = i + 1
            end
        else
            table.insert(result, str:sub(i, i))
            i = i + 1
        end
    end

    return result
end

---@param str string
---@param left string
---@param right? string Same as left if nil
---@return string
function M.surround(str, left, right)
    right = right or left
    return left .. str .. right
end
-- TODO: This should also optionally handle seeing if the surround is already present on each side
-- before adding.

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
-- TODO: Combine this with "surround"

---@audited 2026-07-03
---Bespoke version to strip out guard code. Always relaxed indexing.
---@param s string
---@param encoding "utf-16"|"utf-32"
---@param idx uinteger
---@return integer
function M.str_utfindex(s, encoding, idx)
    local col_32, col_16 = vim._str_utfindex(s, idx) --[[@as integer?, integer?]]
    if encoding == "utf-16" then
        if col_16 then
            return col_16
        end

        local _, max_16 = vim._str_utfindex(s) --[[@as integer, integer]]
        return max_16
    end

    if col_32 then
        return col_32
    end

    local max_32, _ = vim._str_utfindex(s) --[[@as integer, integer]]
    return max_32
end

return M

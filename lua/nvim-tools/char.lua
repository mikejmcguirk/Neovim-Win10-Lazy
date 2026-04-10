local M = {}

-- stylua: ignore
-- Copied from Nvim source
---@type integer[]
local utf8_len_tbl = {
    -- ?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9 ?A ?B ?C ?D ?E ?F
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 0?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 1?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 2?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 3?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 4?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 5?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 6?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 7?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 8?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 9?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- A?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- B?
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  -- C?
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  -- D?
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,  -- E?
    4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 1, 1,  -- F?
}

-- NOTE: For anything line related, you could take the row, col, and buf as inputs and conver
-- them to the line and idx. But, the choice of position format would be arbitrary, so just take
-- line and idx as inputs.

---@param line string
---@param b1 integer Raw character byte
---@param idx integer 1 indexed byte on the line
---@return integer
function M.get_char_len(line, b1, idx)
    vim.validate("line", line, "string")
    local len_line = #line
    vim.validate("idx", idx, function()
        return require("nvim-tools.types").is_uint(idx) and idx <= len_line
    end)

    local len_utf = utf8_len_tbl[b1 + 1]
    if len_utf == 1 or len_utf > 4 or idx + len_utf - 1 > len_line then
        return 1
    else
        return len_utf
    end
end

---@param line string
---@param idx integer 1 indexed byte on the line
---@return integer Prev char length. 0 if unable to find a previous char length.
function M.get_prev_char_len(line, idx)
    vim.validate("line", line, "string")
    local len_line = #line
    vim.validate("idx", idx, function()
        return require("nvim-tools.types").is_uint(idx) and idx <= len_line
    end)

    for i = idx - 1, 1, -1 do
        local b1 = string.byte(line, i)
        if b1 <= 0x80 or b1 >= 0xC0 then
            return M.get_char_len(line, b1, i)
        end
    end

    return 0
end

---@param line string
---@param b1 integer Raw character byte
---@param idx integer 1 indexed byte on the line
---@return integer, integer Codepoint and char length
function M.get_utf_codepoint(line, b1, idx)
    vim.validate("line", line, "string")
    local len_line = #line
    vim.validate("idx", idx, function()
        local is_uint = require("nvim-tools.types").is_uint(idx)
        return is_uint and idx <= len_line
    end)

    local len_utf = utf8_len_tbl[b1 + 1]
    if len_utf == 1 or len_utf > 4 or idx + len_utf - 1 > len_line then
        return b1, 1
    end

    local bit_lshift = require("bit").lshift
    local b2 = string.byte(line, idx + 1)
    if len_utf == 2 then
        return bit_lshift(b1 - 0xC0, 6) + (b2 - 0x80), 2
    end

    local b3 = string.byte(line, idx + 2)
    if len_utf == 3 then
        local b1_lshift = bit_lshift(b1 - 0xE0, 12)
        local b2_lshift = bit_lshift(b2 - 0x80, 6)
        return b1_lshift + b2_lshift + (b3 - 0x80), 3
    end

    local b4 = string.byte(line, idx + 3)
    local b1_shift = bit_lshift(b1 - 0xF0, 18)
    local b2_shift = bit_lshift(b2 - 0x80, 12)
    local b3_shift = bit_lshift(b3 - 0x80, 6)
    return b1_shift + b2_shift + b3_shift + (b4 - 0x80), 4
end
-- TODO: Is the return doc line correct?
-- TODO: If there aren't enough bytes left to render the whole character, is just returning 1 the
-- best solution?

---@param line string
---@param idx integer 1 indexed byte on the line
---@return integer, integer Codepoint and char length
function M.get_prev_utf8_codepoint(line, idx)
    for i = idx - 1, 1, -1 do
        local b1 = string.byte(line, i)
        if b1 <= 0x80 or b1 >= 0xC0 then
            return M.get_utf_codepoint(line, b1, i)
        end
    end

    return -1, 0
end
-- TODO: I'm not sure if the default case is best

return M

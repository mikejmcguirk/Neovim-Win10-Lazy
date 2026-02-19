-- https://www.unicode.org/Public/17.0.0/emoji/
-- https://www.unicode.org/emoji/charts/full-emoji-list.html
-- https://util.unicode.org/UnicodeJsps/list-unicodeset.jsp?a=%5B%3AEmoji%3DYes%3A%5D&esc=on&g=&i=

local api = vim.api
local lookup = require("farsight._lookup")

local basic_emoji_ranges = lookup._basic_emoji_ranges
local bit_lshift = require("bit").lshift
local math_floor = math.floor
local str_byte = string.byte
local utf8_len_tbl = lookup._utf8_len_tbl
local utf_punctuation_ranges = lookup._utf_punctuation_ranges

local SPACE = 32
local COMMA = 44
local DASH = 45
local ZERO = 48
local NINE = 57
local AT_CHAR = 64
local CARET = 94

---@param target integer
---@param ranges [integer, integer, integer][]
---@return integer|nil
local function bisearch_ranges(target, ranges)
    local len_ranges = #ranges
    if target < ranges[1][1] or target > ranges[len_ranges][2] then
        return nil
    end

    local bot = 1
    local top = len_ranges
    while bot <= top do
        local mid = math_floor((bot + top) * 0.5)
        local range = ranges[mid]
        if target < range[1] then
            top = mid - 1
        elseif target > range[2] then
            bot = mid + 1
        else
            return range[3]
        end
    end

    return nil
end

---@param line string
---@param b1 integer
---@param idx integer
---@return integer, integer
local function get_utf_codepoint(line, b1, idx)
    local b1_1 = b1 + 1
    local len_utf = utf8_len_tbl[b1_1]
    if len_utf == 1 or len_utf > 4 or idx + len_utf - 1 > #line then
        return b1, 1
    end

    local b2 = str_byte(line, idx + 1)
    if len_utf == 2 then
        return bit_lshift(b1 - 0xC0, 6) + (b2 - 0x80), 2
    end

    local b3 = str_byte(line, idx + 2)
    if len_utf == 3 then
        local b1_lshift = bit_lshift(b1 - 0xE0, 12)
        local b2_lshift = bit_lshift(b2 - 0x80, 6)
        return b1_lshift + b2_lshift + (b3 - 0x80), 3
    end

    local b4 = str_byte(line, idx + 3)
    local b1_shift = bit_lshift(b1 - 0xF0, 18)
    local b2_shift = bit_lshift(b2 - 0x80, 12)
    local b3_shift = bit_lshift(b3 - 0x80, 6)
    return b1_shift + b2_shift + b3_shift + (b4 - 0x80), 4
end

---@param c integer
---@param c2 integer
---@param tilde boolean
---@param isk_tbl boolean[]
---@return boolean[]
local function set_isk_tbl(c, c2, tilde, isk_tbl)
    local alpha_char = c == 1 and c2 == 255
    if not alpha_char then
        for b = c, c2 do
            isk_tbl[b + 1] = not tilde
        end
    else
        isk_tbl = lookup._get_is_alpha()
    end

    return isk_tbl
end

---@param c integer
---@param c2 integer
---@param i integer
---@param isk string
---@return boolean
local function is_invalid_position(c, c2, i, isk)
    local invalid_c = c <= 0 or c >= 256
    local invalid_c2 = (c2 < c and c2 ~= -1) or c2 >= 256
    local invalid_i = not (i > #isk or str_byte(isk, i) == COMMA)
    return invalid_c or invalid_c2 or invalid_i
end

---@param isk string
---@param i integer
---@return integer, integer
local function get_unknown_part(isk, i)
    local b = str_byte(isk, i)
    if b >= ZERO and b <= NINE then
        local c = b - ZERO
        i = i + 1

        local len_isk = #isk
        while i <= len_isk do
            b = str_byte(isk, i)
            if b < ZERO or b > NINE then
                break
            end

            c = c * 10 + (b - ZERO)
            i = i + 1
        end

        return i, c
    else
        local c, c_len = get_utf_codepoint(isk, b, i)
        return i + c_len, c
    end
end

---Edits isk_tbl in place
---@param buf integer
---@param isk_tbl boolean[]
local function resolve_lisp_mode(buf, isk_tbl)
    if not api.nvim_get_option_value("lisp", { buf = buf }) then
        isk_tbl[DASH] = false
    else
        isk_tbl[DASH] = true
    end
end

local M = {}

---Return table values are Lua indexed. For example: isk_tbl[49] will give you the status of zero
---@param isk string
---@return boolean[]
function M._parse_isk(buf, isk)
    local cached_isk = lookup._get_cached_isk(isk)
    if cached_isk then
        -- Setting 'lisp' does not change isk or chartab. Don't re-check here
        return cached_isk
    end

    local isk_tbl = {}
    for i = 0, 255 do
        isk_tbl[i] = false
    end

    resolve_lisp_mode(buf, isk_tbl)

    local i = 1
    local len_isk = #isk
    while i <= len_isk do
        local tilde = str_byte(isk, i) == CARET
        if tilde then
            i = i + 1
        end

        local c
        if i <= len_isk then
            i, c = get_unknown_part(isk, i)
        end

        local c2 = -1
        if i <= len_isk and str_byte(isk, i) == DASH and i + 1 <= len_isk then
            i = i + 1
            i, c2 = get_unknown_part(isk, i)
        end

        if is_invalid_position(c, c2, i, isk) then
            return lookup._get_default_isk()
        end

        if c2 == -1 then
            if c == AT_CHAR then
                c = 1
                c2 = 255
            else
                c2 = c
            end
        end

        isk_tbl = set_isk_tbl(c, c2, tilde, isk_tbl)
        if str_byte(isk, i) == COMMA then
            if i < len_isk then
                i = i + 1
            else
                -- Ending commas not allowed
                return lookup._get_default_isk()
            end
        end

        -- The source only skips spaces
        while str_byte(isk, i) == SPACE do
            i = i + 1
        end
    end

    lookup._add_cached_isk(isk, isk_tbl)
    return isk_tbl
end

-- TODO: The nested function call in hot paths is not great. I'm unsure right now if this module
-- will be exported for user purposes, hence the M table declaration layout. If this ends up
-- being fully private, declare M at the top and re-order functions accordingly, eliminating
-- this issue.

---idx is one indexed
---@param line string
---@param b1 integer
---@param idx integer
---@return integer, integer
function M._get_utf_codepoint(line, b1, idx)
    return get_utf_codepoint(line, b1, idx)
end

---@param char_nr integer
---@param isk_tbl boolean[]
---@return 0|1|2|3|integer
function M._get_char_class(char_nr, isk_tbl)
    if char_nr == 0x20 or char_nr == 0x09 or char_nr == 0x0 then
        return 0
    end

    if char_nr < 0x100 then
        if char_nr ~= 0xA0 then
            if isk_tbl[char_nr + 1] then
                return 2
            end

            return 1
        end

        return 0
    end

    local emoji_class = bisearch_ranges(char_nr, basic_emoji_ranges)
    if emoji_class then
        return emoji_class
    end

    local utf_punctuation_class = bisearch_ranges(char_nr, utf_punctuation_ranges)
    if utf_punctuation_class then
        return utf_punctuation_class
    end

    return 2
end

return M

-- TODO: isk should be checked and cached on every Farsight function. Helpers should be made
-- available for users to plug into these.
-- TODO: Be less sloppy with aliasing codepoints

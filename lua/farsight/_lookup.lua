-- Data module only

local default_isk = (function()
    local default_isk = {}
    for i = 0, 255 do
        default_isk[i] = false
    end

    for i = 65, 90 do
        default_isk[i] = true
    end

    for i = 97, 122 do
        default_isk[i] = true
    end

    for i = 48, 57 do
        default_isk[i] = true
    end

    default_isk[95] = true

    for i = 192, 255 do
        default_isk[i] = true
    end

    return default_isk
end)()

---@type table<string, boolean[]>
local isk_cache = {}

---@type table<string, string[]>
local isk_token_cache = {}

local is_alpha = (function()
    local is_alpha = {} ---@type boolean[]
    for b = 0, 255 do
        is_alpha[b] = false
    end

    -- Code points are Lua Indexed
    for b = 66, 91 do
        is_alpha[b] = true
    end

    for b = 98, 123 do
        is_alpha[b] = true
    end

    is_alpha[171] = true
    is_alpha[182] = true
    is_alpha[187] = true

    for b = 193, 215 do
        is_alpha[b] = true
    end

    for b = 217, 247 do
        is_alpha[b] = true
    end

    for b = 249, 256 do
        is_alpha[b] = true
    end

    return is_alpha
end)()

local M = {}

---Makes a unique copy of the list
---@param isk string
---@param isk_tbl boolean[]
function M._add_cached_isk(isk, isk_tbl)
    isk_cache[isk] = require("farsight.util")._list_copy(isk_tbl)
end

---@param isk string
---@return boolean[]|nil
function M._get_cached_isk(isk)
    local cached_isk = isk_cache[isk]
    if cached_isk then
        return require("farsight.util")._list_copy(cached_isk)
    else
        return nil
    end
end

---Makes a unique copy of the list
---@param isk string
---@param isk_tokens boolean[]
function M._add_cached_isk_tokens(isk, isk_tokens)
    isk_token_cache[isk] = require("farsight.util")._list_copy(isk_tokens)
end

---@param isk string
---@return string[]|nil
function M._get_cached_isk_tokens(isk)
    local cached_isk_tokens = isk_token_cache[isk]
    if cached_isk_tokens then
        return require("farsight.util")._list_copy(cached_isk_tokens)
    else
        return nil
    end
end

---@return boolean[]
function M._get_default_isk()
    return require("farsight.util")._list_copy(default_isk)
end

function M._get_is_alpha()
    return require("farsight.util")._list_copy(is_alpha)
end

-- stylua: ignore
-- Copied from Nvim source
---Used in hot paths, so no data protection
---@type integer[]
M._utf8_len_tbl = {
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

--Used in hot paths, so no data protection
M._utf_punctuation_ranges = {
    { 0x037e, 0x037e, 1 }, -- Greek question mark
    { 0x0387, 0x0387, 1 }, -- Greek ano teleia
    { 0x055a, 0x055f, 1 }, -- Armenian punctuation
    { 0x0589, 0x0589, 1 }, -- Armenian full stop
    { 0x05be, 0x05be, 1 },
    { 0x05c0, 0x05c0, 1 },
    { 0x05c3, 0x05c3, 1 },
    { 0x05f3, 0x05f4, 1 },
    { 0x060c, 0x060c, 1 },
    { 0x061b, 0x061b, 1 },
    { 0x061f, 0x061f, 1 },
    { 0x066a, 0x066d, 1 },
    { 0x06d4, 0x06d4, 1 },
    { 0x0700, 0x070d, 1 }, -- Syriac punctuation
    { 0x0964, 0x0965, 1 },
    { 0x0970, 0x0970, 1 },
    { 0x0df4, 0x0df4, 1 },
    { 0x0e4f, 0x0e4f, 1 },
    { 0x0e5a, 0x0e5b, 1 },
    { 0x0f04, 0x0f12, 1 },
    { 0x0f3a, 0x0f3d, 1 },
    { 0x0f85, 0x0f85, 1 },
    { 0x104a, 0x104f, 1 }, -- Myanmar punctuation
    { 0x10fb, 0x10fb, 1 }, -- Georgian punctuation
    { 0x1361, 0x1368, 1 }, -- Ethiopic punctuation
    { 0x166d, 0x166e, 1 }, -- Canadian Syl. punctuation
    { 0x1680, 0x1680, 0 },
    { 0x169b, 0x169c, 1 },
    { 0x16eb, 0x16ed, 1 },
    { 0x1735, 0x1736, 1 },
    { 0x17d4, 0x17dc, 1 }, -- Khmer punctuation
    { 0x1800, 0x180a, 1 }, -- Mongolian punctuation
    { 0x2000, 0x200b, 0 }, -- spaces
    { 0x200c, 0x2027, 1 }, -- punctuation and symbols
    { 0x2028, 0x2029, 0 },
    { 0x202a, 0x202e, 1 }, -- punctuation and symbols
    { 0x202f, 0x202f, 0 },
    { 0x2030, 0x205e, 1 }, -- punctuation and symbols
    { 0x205f, 0x205f, 0 },
    { 0x2060, 0x206f, 1 }, -- punctuation and symbols
    { 0x2070, 0x207f, 0x2070 }, -- superscript
    { 0x2080, 0x2094, 0x2080 }, -- subscript
    { 0x20a0, 0x27ff, 1 }, -- all kinds of symbols
    { 0x2800, 0x28ff, 0x2800 }, -- braille
    { 0x2900, 0x2998, 1 }, -- arrows, brackets, etc.
    { 0x29d8, 0x29db, 1 },
    { 0x29fc, 0x29fd, 1 },
    { 0x2e00, 0x2e7f, 1 }, -- supplemental punctuation
    { 0x3000, 0x3000, 0 }, -- ideographic space
    { 0x3001, 0x3020, 1 }, -- ideographic punctuation
    { 0x3030, 0x3030, 1 },
    { 0x303d, 0x303d, 1 },
    { 0x3040, 0x309f, 0x3040 }, -- Hiragana
    { 0x30a0, 0x30ff, 0x30a0 }, -- Katakana
    { 0x3300, 0x9fff, 0x4e00 }, -- CJK Ideographs
    { 0xac00, 0xd7a3, 0xac00 }, -- Hangul Syllables
    { 0xf900, 0xfaff, 0x4e00 }, -- CJK Ideographs
    { 0xfd3e, 0xfd3f, 1 },
    { 0xfe30, 0xfe6b, 1 }, -- punctuation forms
    { 0xff00, 0xff0f, 1 }, -- half/fullwidth ASCII
    { 0xff1a, 0xff20, 1 }, -- half/fullwidth ASCII
    { 0xff3b, 0xff40, 1 }, -- half/fullwidth ASCII
    { 0xff5b, 0xff65, 1 }, -- half/fullwidth ASCII
    { 0x1d000, 0x1d24f, 1 }, -- Musical notation
    { 0x1d400, 0x1d7ff, 1 }, -- Mathematical Alphanumeric Symbols
    { 0x1f000, 0x1f2ff, 1 }, -- Game pieces; enclosed characters
    { 0x1f300, 0x1f9ff, 1 }, -- Many symbol blocks
    { 0x20000, 0x2a6df, 0x4e00 }, -- CJK Ideographs
    { 0x2a700, 0x2b73f, 0x4e00 }, -- CJK Ideographs
    { 0x2b740, 0x2b81f, 0x4e00 }, -- CJK Ideographs
    { 0x2f800, 0x2fa1f, 0x4e00 }, -- CJK Ideographs
}

-- TODO: The emoji generator needs to output the three

--Used in hot paths, so no data protection
M._basic_emoji_ranges = {
    { 0xA9, 0xA9 },
    { 0xAE, 0xAE },
    { 0x203C, 0x203C, 3 },
    { 0x2049, 0x2049, 3 },
    { 0x2122, 0x2122, 3 },
    { 0x2139, 0x2139, 3 },
    { 0x2194, 0x2199, 3 },
    { 0x21A9, 0x21AA, 3 },
    { 0x231A, 0x231B, 3 },
    { 0x2328, 0x2328, 3 },
    { 0x23CF, 0x23CF, 3 },
    { 0x23E9, 0x23F3, 3 },
    { 0x23F8, 0x23FA, 3 },
    { 0x24C2, 0x24C2, 3 },
    { 0x25AA, 0x25AB, 3 },
    { 0x25B6, 0x25B6, 3 },
    { 0x25C0, 0x25C0, 3 },
    { 0x25FB, 0x25FE, 3 },
    { 0x2600, 0x2604, 3 },
    { 0x260E, 0x260E, 3 },
    { 0x2611, 0x2611, 3 },
    { 0x2614, 0x2615, 3 },
    { 0x2618, 0x2618, 3 },
    { 0x261D, 0x261D, 3 },
    { 0x2620, 0x2620, 3 },
    { 0x2622, 0x2623, 3 },
    { 0x2626, 0x2626, 3 },
    { 0x262A, 0x262A, 3 },
    { 0x262E, 0x262F, 3 },
    { 0x2638, 0x263A, 3 },
    { 0x2640, 0x2640, 3 },
    { 0x2642, 0x2642, 3 },
    { 0x2648, 0x2653, 3 },
    { 0x265F, 0x2660, 3 },
    { 0x2663, 0x2663, 3 },
    { 0x2665, 0x2666, 3 },
    { 0x2668, 0x2668, 3 },
    { 0x267B, 0x267B, 3 },
    { 0x267E, 0x267F, 3 },
    { 0x2692, 0x2697, 3 },
    { 0x2699, 0x2699, 3 },
    { 0x269B, 0x269C, 3 },
    { 0x26A0, 0x26A1, 3 },
    { 0x26A7, 0x26A7, 3 },
    { 0x26AA, 0x26AB, 3 },
    { 0x26B0, 0x26B1, 3 },
    { 0x26BD, 0x26BE, 3 },
    { 0x26C4, 0x26C5, 3 },
    { 0x26C8, 0x26C8, 3 },
    { 0x26CE, 0x26CF, 3 },
    { 0x26D1, 0x26D1, 3 },
    { 0x26D3, 0x26D4, 3 },
    { 0x26E9, 0x26EA, 3 },
    { 0x26F0, 0x26F5, 3 },
    { 0x26F7, 0x26FA, 3 },
    { 0x26FD, 0x26FD, 3 },
    { 0x2702, 0x2702, 3 },
    { 0x2705, 0x2705, 3 },
    { 0x2708, 0x270D, 3 },
    { 0x270F, 0x270F, 3 },
    { 0x2712, 0x2712, 3 },
    { 0x2714, 0x2714, 3 },
    { 0x2716, 0x2716, 3 },
    { 0x271D, 0x271D, 3 },
    { 0x2721, 0x2721, 3 },
    { 0x2728, 0x2728, 3 },
    { 0x2733, 0x2734, 3 },
    { 0x2744, 0x2744, 3 },
    { 0x2747, 0x2747, 3 },
    { 0x274C, 0x274C, 3 },
    { 0x274E, 0x274E, 3 },
    { 0x2753, 0x2755, 3 },
    { 0x2757, 0x2757, 3 },
    { 0x2763, 0x2764, 3 },
    { 0x2795, 0x2797, 3 },
    { 0x27A1, 0x27A1, 3 },
    { 0x27B0, 0x27B0, 3 },
    { 0x27BF, 0x27BF, 3 },
    { 0x2934, 0x2935, 3 },
    { 0x2B05, 0x2B07, 3 },
    { 0x2B1B, 0x2B1C, 3 },
    { 0x2B50, 0x2B50, 3 },
    { 0x2B55, 0x2B55, 3 },
    { 0x3030, 0x3030, 3 },
    { 0x303D, 0x303D, 3 },
    { 0x3297, 0x3297, 3 },
    { 0x3299, 0x3299, 3 },
    { 0x1F004, 0x1F004, 3 },
    { 0x1F0CF, 0x1F0CF, 3 },
    { 0x1F170, 0x1F171, 3 },
    { 0x1F17E, 0x1F17F, 3 },
    { 0x1F18E, 0x1F18E, 3 },
    { 0x1F191, 0x1F19A, 3 },
    { 0x1F201, 0x1F202, 3 },
    { 0x1F21A, 0x1F21A, 3 },
    { 0x1F22F, 0x1F22F, 3 },
    { 0x1F232, 0x1F23A, 3 },
    { 0x1F250, 0x1F251, 3 },
    { 0x1F300, 0x1F321, 3 },
    { 0x1F324, 0x1F393, 3 },
    { 0x1F396, 0x1F397, 3 },
    { 0x1F399, 0x1F39B, 3 },
    { 0x1F39E, 0x1F3F0, 3 },
    { 0x1F3F3, 0x1F3F5, 3 },
    { 0x1F3F7, 0x1F4FD, 3 },
    { 0x1F4FF, 0x1F53D, 3 },
    { 0x1F549, 0x1F54E, 3 },
    { 0x1F550, 0x1F567, 3 },
    { 0x1F56F, 0x1F570, 3 },
    { 0x1F573, 0x1F57A, 3 },
    { 0x1F587, 0x1F587, 3 },
    { 0x1F58A, 0x1F58D, 3 },
    { 0x1F590, 0x1F590, 3 },
    { 0x1F595, 0x1F596, 3 },
    { 0x1F5A4, 0x1F5A5, 3 },
    { 0x1F5A8, 0x1F5A8, 3 },
    { 0x1F5B1, 0x1F5B2, 3 },
    { 0x1F5BC, 0x1F5BC, 3 },
    { 0x1F5C2, 0x1F5C4, 3 },
    { 0x1F5D1, 0x1F5D3, 3 },
    { 0x1F5DC, 0x1F5DE, 3 },
    { 0x1F5E1, 0x1F5E1, 3 },
    { 0x1F5E3, 0x1F5E3, 3 },
    { 0x1F5E8, 0x1F5E8, 3 },
    { 0x1F5EF, 0x1F5EF, 3 },
    { 0x1F5F3, 0x1F5F3, 3 },
    { 0x1F5FA, 0x1F64F, 3 },
    { 0x1F680, 0x1F6C5, 3 },
    { 0x1F6CB, 0x1F6D2, 3 },
    { 0x1F6D5, 0x1F6D8, 3 },
    { 0x1F6DC, 0x1F6E5, 3 },
    { 0x1F6E9, 0x1F6E9, 3 },
    { 0x1F6EB, 0x1F6EC, 3 },
    { 0x1F6F0, 0x1F6F0, 3 },
    { 0x1F6F3, 0x1F6FC, 3 },
    { 0x1F7E0, 0x1F7EB, 3 },
    { 0x1F7F0, 0x1F7F0, 3 },
    { 0x1F90C, 0x1F93A, 3 },
    { 0x1F93C, 0x1F945, 3 },
    { 0x1F947, 0x1F9FF, 3 },
    { 0x1FA70, 0x1FA7C, 3 },
    { 0x1FA80, 0x1FA8A, 3 },
    { 0x1FA8E, 0x1FAC6, 3 },
    { 0x1FAC8, 0x1FAC8, 3 },
    { 0x1FACD, 0x1FADC, 3 },
    { 0x1FADF, 0x1FAEA, 3 },
    { 0x1FAEF, 0x1FAF8, 3 },
}

return M

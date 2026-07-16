-- Data module only

---@type boolean[]
local default_isk = (function()
    local d_isk = {} ---@type boolean[]
    for i = 1, 256 do
        d_isk[i] = false
    end

    for i = 65, 90 do
        d_isk[i] = true
    end

    for i = 97, 122 do
        d_isk[i] = true
    end

    for i = 48, 57 do
        d_isk[i] = true
    end

    d_isk[95] = true

    for i = 192, 255 do
        d_isk[i] = true
    end

    return d_isk
end)()

---@type table<string, boolean[]>
local isk_cache = {}

local is_alpha = (function()
    local d_is_alpha = {} ---@type boolean[]
    for b = 0, 255 do
        d_is_alpha[b] = false
    end

    -- Code points are Lua Indexed
    for b = 66, 91 do
        d_is_alpha[b] = true
    end

    for b = 98, 123 do
        d_is_alpha[b] = true
    end

    d_is_alpha[171] = true
    d_is_alpha[182] = true
    d_is_alpha[187] = true

    for b = 193, 215 do
        d_is_alpha[b] = true
    end

    for b = 217, 247 do
        d_is_alpha[b] = true
    end

    for b = 249, 256 do
        d_is_alpha[b] = true
    end

    return d_is_alpha
end)()

local M = {}

---Makes a unique copy of the list
---@param isk string
---@param isk_tbl boolean[]
function M._add_cached_isk(isk, isk_tbl)
    isk_cache[isk] = require("nvim-tools.table").i_copy(isk_tbl)
end
-- TODO: Still used by csearch

---@param isk string
---@return boolean[]|nil
function M._get_cached_isk(isk)
    local cached_isk = isk_cache[isk]
    if cached_isk ~= nil then
        return require("nvim-tools.table").i_copy(cached_isk)
    else
        return nil
    end
end
-- TODO: Still used by csearch

---@return boolean[]
function M._get_default_isk()
    return require("nvim-tools.table").i_copy(default_isk)
end
-- TODO: Still used by csearch

function M._get_is_alpha()
    return require("nvim-tools.table").i_copy(is_alpha)
end
-- TODO: Still used by csearch

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
-- TODO: Still used by csearch
-- TODO: Might want to keep this one for csearch still, because crossing the bridge for UTF is
-- slow

return M

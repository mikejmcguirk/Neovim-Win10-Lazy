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

-- TODO: These need to be one indexed
-- TODO: These need to take is_alpha since that's part of the default
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

local M = {}

-- TODO: Can all the isopts use the same cache or no?
-- TODO: I think this type is right. Fundamentally, the result of the parse should be an integer[]
-- so that way you can check characters with fast O(1) lookups
local parsed = {} ---@type table<string, integer[]>

-- TODO: add cached needs to copy the returned list
-- TODO: get cached needs to copy the cached list

-- TODO: Do you provide some kind of helper for doing the 0 indexed byte to one indexed char
-- translation? Or do you just flag it in documentation?

---@param isopt string
---@param buf integer
---@param default "isf"|"isi"|"isk"|"isp"
---@return integer[]
function M.parse_isopt(isopt, buf, default)
    return { 0 }
end

-- TODO: have functions to return copies of the defaults

return M

local M = {}

local MAX_INT = 2 ^ 53
local FACTORIAL = {
    [0] = 1,
    [1] = 1,
    [2] = 2,
    [3] = 6,
    [4] = 24,
    [5] = 120,
    [6] = 720,
    [7] = 5040,
    [8] = 40320,
    [9] = 362880,
    [10] = 3628800,
    [11] = 39916800,
    [12] = 479001600,
    [13] = 6227020800,
    [14] = 87178291200,
    [15] = 1307674368000,
    [16] = 20922789888000,
    [17] = 355687428096000,
    [18] = 6402373705728000,
}

---@param n uinteger
function M.capped_factorial(n)
    return FACTORIAL[n] or MAX_INT
end

---@audited 2026-07-03
---@param n number
---@param min number
---@param max number
---@return number
function M.clamp(n, min, max)
    if n < min then
        return min
    elseif n > max then
        return max
    else
        return n
    end
end

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

return M

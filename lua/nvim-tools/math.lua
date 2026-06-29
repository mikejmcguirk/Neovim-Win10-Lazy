local M = {}

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

return M

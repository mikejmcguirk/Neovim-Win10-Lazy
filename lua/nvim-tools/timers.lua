local uv = vim.uv

local M = {}

---@param timer uv.uv_timer_t|nil
---@return nil
function M.timer_close(timer)
    if timer and not uv.is_closing(timer) then
        uv.timer_stop(timer)
        uv.close(timer)
    end

    return nil
end
-- TODO: I guess you have to return nil to the original var rather than being able to nil
-- by reference? FeelsBadMan

---@param timer uv.uv_timer_t
function M.timer_stop(timer)
    if uv.is_active(timer) then
        uv.timer_stop(timer)
    end
end

---@generic T
---@param timers table<T, uv.uv_timer_t|nil>
---@param k T
function M.timers_get_with_checked_create(timers, k)
    local timer = timers[k]
    if timer ~= nil then
        return timer
    end

    timer = assert(uv.new_timer())
    timers[k] = timer
    return timer
end

---@generic T
---@param timers table<T, uv.uv_timer_t|nil>
---@param k T
function M.timers_rm(timers, k)
    local timer = timers[k]
    if timer == nil then
        return
    end

    if uv.is_closing(timer) ~= true then
        uv.timer_stop(timer)
        uv.close(timer)
    end

    timers[k] = nil
end

---@generic T
---@param timers table<T, uv.uv_timer_t|nil>
---@param k T
---@param debounce uinteger
---@param f function
function M.timers_do_after_debounce(timers, k, debounce, f)
    local timer = M.timers_get_with_checked_create(timers, k)
    uv.timer_start(timer, debounce, 0, f)
end

---@generic T
---@param timers table<T, uv.uv_timer_t|nil>
---@param k T
function M.timers_stop(timers, k)
    local timer = timers[k]
    if timer ~= nil then
        M.timer_stop(timer)
    end
end

return M

-- TODO: Remove the timer stuff from misc.

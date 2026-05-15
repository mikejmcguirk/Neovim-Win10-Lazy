local fs = vim.fs
local uv = vim.uv

local M = {}

---@param path string
---@return string norm_abs_path
function M.get_norm_abs(path)
    -- vim.fs.abspath might be changed to use fnamemodify :p:h, so use this for stability
    return fs.normalize(vim.call("fnamemodify", path, ":p"))
end

---@class FileCheckerOpts
---@field max_jobs? integer (default: 8) Maximum simultaneous `fs_stat` calls
---@field timeout? integer (default: 10000) Timeout in milliseconds
---@field validator? fun(path: string, stat: uv.fs_stat.result|nil, err: string|nil): boolean Return `false` to mark overall failure

---@param filepaths string[]
---@param on_complete fun(success:boolean)
---@param opts FileCheckerOpts
local function _fs_stat_list_async(filepaths, on_complete, opts)
    local max_jobs = opts.max_jobs or 8
    local timeout = opts.timeout or 10000
    local validator = opts.validator or function(_, stat)
        return stat ~= nil
    end

    local total = #filepaths
    local active = 0
    local next_idx = 1

    local done = false
    local failed = false
    local timed_out = false
    local timer = nil

    ---@param success boolean
    local function finish(success)
        if done then
            return
        end

        done = true
        if timer then
            timer:stop()
            timer:close()
            timer = nil
        end

        on_complete(success)
    end

    local function start_next()
        if done or failed or timed_out or next_idx > total or active >= max_jobs then
            return
        end

        local path = filepaths[next_idx]
        next_idx = next_idx + 1
        active = active + 1

        uv.fs_stat(path, function(err, stat)
            vim.schedule(function()
                if done then
                    return
                end

                active = active - 1

                local ok = validator(path, stat, err)
                if not ok then
                    failed = true
                end

                start_next()

                if active == 0 and (next_idx > total or failed or timed_out) then
                    finish(not failed and not timed_out)
                end
            end)
        end)
    end

    for _ = 1, math.min(max_jobs, total) do
        start_next()
    end

    if timeout > 0 then
        timer = assert(uv.new_timer())
        timer:start(
            timeout,
            0,
            vim.schedule_wrap(function()
                if not done then
                    timed_out = true
                    finish(false)
                end
            end)
        )
    end
end

---@param filepaths string[]
---@param opts FileCheckerOpts
local function validate_fs_stat_list(filepaths, opts)
    vim.validate("filepaths", filepaths, "table")
    vim.validate("opts.max_jobs", opts.max_jobs, "number", true)
    vim.validate("opts.timeout", opts.timeout, "number", true)
    vim.validate("opts.validator", opts.validator, "number", true)
end

---@async
---@param filepaths string[]
---@param opts FileCheckerOpts?
function M.fs_stat_list_async(filepaths, on_complete, opts)
    opts = opts or {}
    validate_fs_stat_list(filepaths, opts)
    _fs_stat_list_async(filepaths, on_complete, opts)
end

---@param filepaths string[]
---@param opts FileCheckerOpts?
---@return boolean success
function M.fs_stat_list(filepaths, opts)
    opts = opts or {}
    validate_fs_stat_list(filepaths, opts)

    if #filepaths == 0 then
        return true
    end

    local done = false
    local ok = false
    -- local err = nil

    _fs_stat_list_async(filepaths, function(success)
        ok = success
        done = true
    end, opts)

    vim.wait(opts.timeout or 10000, function()
        return done
    end, 10)

    return ok
end

return M

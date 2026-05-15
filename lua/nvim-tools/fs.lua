local fs = vim.fs
local uv = vim.uv

local DEFAULT_TIMEOUT = 1000

local M = {}

---@param path string
---@return string norm_abs_path
function M.get_norm_abs(path)
    -- vim.fs.abspath might be changed to use fnamemodify :p:h, so use this for stability
    return fs.normalize(vim.call("fnamemodify", path, ":p"))
end

---@param path string
---@param stat uv.fs_stat.result|nil
---@param err string|nil
---@return boolean ok, string|nil msg
local function fs_stat_list_validator_default(path, stat, err)
    if err then
        return false, string.format("fs_stat error on %s: %s", path, err)
    elseif not stat then
        return false, string.format("%s does not exist", path)
    else
        return true
    end
end

---@class nvim-tools.fs.FsStatListOpts
---@field jobs_max? integer (default: 8) Maximum simultaneous |uv.fs_stat()| calls
---@field timeout? integer (default: 1000) Timeout (ms).
---@field validator? fun(path: string, stat: uv.fs_stat.result|nil, err: string|nil): boolean, string?

---@param paths string[] Assumes at least one path is provided.
---@param on_complete fun(success:boolean, timed_out: boolean, errs:[string,string][])
---@param opts nvim-tools.fs.FsStatListOpts
local function _fs_stat_list_async(paths, on_complete, opts)
    local paths_count = #paths
    local jobs_max = opts.jobs_max or 8
    jobs_max = jobs_max == 0 and paths_count or jobs_max
    local timeout = opts.timeout or DEFAULT_TIMEOUT
    local validator = opts.validator or fs_stat_list_validator_default

    local jobs_active = 0
    local idx_next = 1

    local timer = nil ---@type uv.uv_timer_t|nil
    local timed_out = false -- Only use this for the results return.
    local is_done = false -- `done()` is a busted function.
    local errs = {} ---@type [string,string][]

    local function finish()
        if timer and not timer:is_closing() then
            timer:stop()
            timer:close()
            timer = nil
        end

        local success = #errs == 0 and not timed_out
        is_done = true
        on_complete(success, timed_out, errs)
    end

    local function start_next()
        local path = paths[idx_next]
        idx_next = idx_next + 1

        jobs_active = jobs_active + 1
        uv.fs_stat(path, function(err, stat)
            vim.schedule(function()
                if is_done then
                    return
                end

                jobs_active = jobs_active - 1
                local ok, msg = validator(path, stat, err)
                if not ok then
                    errs[#errs + 1] = { path, msg }
                end

                if idx_next <= paths_count then
                    start_next()
                elseif jobs_active == 0 then
                    finish()
                end
            end)
        end)
    end

    local jobs_init_count = math.min(jobs_max, paths_count)
    for _ = 1, jobs_init_count do
        start_next()
    end

    if timeout > 0 then
        timer = assert(uv.new_timer())
        timer:start(
            timeout,
            0,
            vim.schedule_wrap(function()
                if not is_done then
                    timed_out = true
                    finish()
                end
            end)
        )
    end
end

---@param filepaths string[]
---@param opts nvim-tools.fs.FsStatListOpts
local function validate_fs_stat_list(filepaths, opts)
    local nty = require("nvim-tools.types")
    vim.validate("filepaths", filepaths, function()
        return nty.valid_list(filepaths, { item_type = "string", min_len = 1 })
    end)

    vim.validate("opts.max_jobs", opts.jobs_max, nty.is_uint, true)
    vim.validate("opts.timeout", opts.timeout, nty.is_uint, true)
    vim.validate("opts.validator", opts.validator, "callable", true)
end

---@async
---@param paths string[]
---@param on_complete fun(success:boolean, timed_out: boolean, errs:[string,string][])
---@param opts nvim-tools.fs.FsStatListOpts?
---`false`, `false`, `nil` if no paths.
function M.fs_stat_list_async(paths, on_complete, opts)
    opts = opts or {}
    validate_fs_stat_list(paths, opts)
    if #paths == 0 then
        return false, false, nil
    end

    _fs_stat_list_async(paths, on_complete, opts)
end

---Run simultaneous |uv.fs_stat()| jobs and use |vim.wait()| to mimic async join behavior.
---@param paths string[]
---@param opts nvim-tools.fs.FsStatListOpts?
---@return boolean ok, boolean timed_out, string[]|nil errs
---`false`, `false`, `nil` if no paths.
function M.fs_stat_list(paths, opts)
    opts = opts or {}
    validate_fs_stat_list(paths, opts)
    if #paths == 0 then
        return false, false, nil
    end

    local complete = false
    local ok = false
    local timed_out = false
    local errs ---@type string[]|nil

    M.fs_stat_list_async(paths, function(cb_ok, cb_timed_out, cb_errs)
        ok = cb_ok
        timed_out = cb_timed_out
        errs = cb_errs
        complete = true
    end, opts)

    vim.wait(opts.timeout or DEFAULT_TIMEOUT, function()
        return complete
    end, 10)

    return ok, timed_out, errs
end

return M

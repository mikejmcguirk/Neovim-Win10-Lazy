local fs = vim.fs
local uv = vim.uv

local DEFAULT_TIMEOUT = 1000

local M = {}

---@param path string
---@return string norm_abs_path
function M.norm_abs_path_get(path)
    -- vim.fs.abspath might be changed to use fnamemodify :p:h, so use this for stability
    return fs.normalize(vim.call("fnamemodify", path, ":p"))
end

---@param path string
---@param err uv.callback.err
---@param stat uv.fs_stat.result?
---@param fstat boolean True for fstat, false for stat
---@return boolean ok, string? msg
local function stat_file_validate(path, stat, err, fstat)
    local fun = fstat and "fstat" or "stat"
    if not stat then
        local fmt_str = "input file %s: %s returned no stat (%s)"
        local msg = string.format(fmt_str, path, fun, err or "Does this file exist?")
        return false, msg
    elseif stat.type ~= "file" then
        local fmt_str = "input %s exists but is not a regular file (type: %s)"
        local msg = string.format(fmt_str, path, stat.type)
        return false, msg
    end

    return true, nil
end

---@param path string
---@param permission boolean|nil
---@param err string|nil
---@param err_name string|nil
---@return boolean ok, string|nil msg
function M.fs_access_validation(path, permission, err, err_name)
    if not permission then
        local err_str = err or ("Does " .. path .. " exist?")
        local err_msg = (err_name or "Unknown error") .. ": " .. err_str
        return false, err_msg
    end

    return true, nil
end

---@param path string
---@param err uv.callback.err
---@param stat uv.fs_stat.result?
---@return boolean ok, string? msg
function M.fs_stat_file_validate(path, err, stat)
    return stat_file_validate(path, stat, err, false)
end

---@param path string
---@param err uv.callback.err
---@param stat uv.fs_stat.result?
---@return boolean ok, string? msg
function M.fs_fstat_file_validate(path, err, stat)
    return stat_file_validate(path, stat, err, true)
end

---@param path string
---@param err uv.callback.err
---@param fd integer|nil
---@return boolean ok, string? msg
function M.fs_open_validate(path, err, fd)
    if err then
        return false, string.format("fs_open error on %s: %s", path, err)
    elseif not fd then
        local fmt_str = "fs_open failed on %s: no file descriptor returned"
        local msg = string.format(fmt_str, path)
        return false, msg
    end

    return true, nil
end

---------------------------
-- MARK: Async Functions --
---------------------------

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
    local stop_timer = require("nvim-tools.misc").stop_timer
    local is_done = false -- `done()` is a busted function.
    ---@type [string,string][]
    local errs = require("nvim-tools.table").table_new(paths_count, 0)

    local function finish()
        timer = stop_timer(timer)

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

    _fs_stat_list_async(paths, function(cb_ok, cb_timed_out, cb_errs)
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
-- DEPRECATE: I would guess that vim.async would make this irrelevant.

---@class nvim-tools.fs.FsReadOpts
---@field jobs_max? integer (default: 8) Maximum simultaneous file reads
---@field timeout? integer (default: 1000) Timeout (ms).

---@alias nvim-tools.fs.FsReadListResult [boolean,string?,uv.callback.err]

---@param path string
---@param callback fun(err:uv.callback.err, content:string|nil)
local function read_file_async(path, callback)
    uv.fs_open(path, "r", 292, function(open_err, fd)
        local ok_o, err_o = M.fs_open_validate(path, open_err, fd)
        if not ok_o then
            callback(err_o, nil)
            return
        end

        uv.fs_fstat(fd, function(stat_err, stat)
            local ok_s, err_s = M.fs_fstat_file_validate(path, stat_err, stat)
            if not ok_s then
                uv.fs_close(fd, function() end)
                callback(err_s, nil)
                return
            end

            uv.fs_read(fd, stat.size, 0, function(read_err, content)
                uv.fs_close(fd, function() end)
                callback(read_err, content)
            end)
        end)
    end)
end

---@param paths string[] Assumes at least one path is provided.
---@param on_complete fun(success:boolean, timed_out: boolean, results:table<string, nvim-tools.fs.FsReadListResult>)
---@param opts nvim-tools.fs.FsReadOpts
local function _fs_read_list_async(paths, on_complete, opts)
    local paths_count = #paths
    local jobs_max = opts.jobs_max or 8
    jobs_max = jobs_max == 0 and paths_count or jobs_max
    local jobs_active = 0
    local idx_next = 1
    local is_done = false

    local timer = nil ---@type uv.uv_timer_t|nil
    local timeout = opts.timeout or DEFAULT_TIMEOUT
    local timed_out = false
    local stop_timer = require("nvim-tools.misc").stop_timer

    ---@type table<string, nvim-tools.fs.FsReadListResult>
    local results = require("nvim-tools.table").table_new(paths_count, 0)

    -- Assumes same synchronous context as the caller
    local function finish()
        timer = stop_timer(timer)

        local success = idx_next == (paths_count + 1) and not timed_out
        for _, result in pairs(results) do
            if not result[1] then
                success = false
                break
            end
        end

        is_done = true
        on_complete(success, timed_out, results)
    end

    local function start_next()
        local path = paths[idx_next]
        idx_next = idx_next + 1
        jobs_active = jobs_active + 1

        read_file_async(path, function(err, content)
            vim.schedule(function()
                if is_done then
                    return
                end

                jobs_active = jobs_active - 1
                results[path] = { content ~= nil, content, err }

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

---@param paths string[]
---@param opts nvim-tools.fs.FsReadOpts
local function validate_fs_read_list(paths, opts)
    local nty = require("nvim-tools.types")
    vim.validate("paths", paths, function()
        return nty.valid_list(paths, { item_type = "string", min_len = 1 })
    end)

    vim.validate("opts.max_jobs", opts.jobs_max, nty.is_uint, true)
    vim.validate("opts.timeout", opts.timeout, nty.is_uint, true)
end

---@async
---@param paths string[]
---@param on_complete fun(success:boolean, timed_out: boolean, results:table<string, nvim-tools.fs.FsReadListResult>)
---@param opts nvim-tools.fs.FsReadOpts
function M.fs_read_list_async(paths, on_complete, opts)
    opts = opts or {}
    validate_fs_read_list(paths, opts)
    if #paths == 0 then
        return false, false, {}
    end

    _fs_read_list_async(paths, on_complete, opts)
end

---Run simultaneous |uv.fs_read()| jobs with file validation and use |vim.wait()| to mimic
---async join.
---@param paths string[]
---@param opts nvim-tools.fs.FsReadOpts
---@return boolean ok, boolean timed_out, table<string, nvim-tools.fs.FsReadListResult>|nil results
function M.fs_read_list(paths, opts)
    opts = opts or {}
    validate_fs_read_list(paths, opts)
    if #paths == 0 then
        return false, false, nil
    end

    local complete = false
    local ok = false
    local timed_out = false
    local results ---@type table<string, nvim-tools.fs.FsReadListResult>|nil

    _fs_read_list_async(paths, function(cb_ok, cb_timed_out, cb_results)
        ok = cb_ok
        timed_out = cb_timed_out
        results = cb_results
        complete = true
    end, opts)

    vim.wait(opts.timeout or DEFAULT_TIMEOUT, function()
        return complete
    end, 10)

    return ok, timed_out, results
end
-- DEPRECATE: I would guess that vim.async would make this irrelevant.

---@param results table<string, nvim-tools.fs.FsReadListResult>?
function M.fs_read_list_get_errs(results)
    if not results then
        return ""
    end

    local errs_tbl = {} ---@type string[]
    for file, result in pairs(results) do
        if not results[1] then
            errs_tbl[#errs_tbl + 1] = file .. ": " .. (result[3] or "Unknown error")
        end
    end

    if #errs_tbl == 0 then
        return
    end

    return table.concat(errs_tbl, "\n")
end

return M

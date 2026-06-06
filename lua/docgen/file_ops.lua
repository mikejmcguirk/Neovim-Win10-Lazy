local fn = vim.fn
local fs = vim.fs
local uv = vim.uv

local util = require("docgen.util")
local stop_timer = util.stop_timer
local table_new = util.table_new

DEFAULT_TIMEOUT = 1000

local M = {}

function M.get_debug_path()
    local debug_info = debug.getinfo(2, "S")
    if not debug_info then
        debug_info = debug.getinfo(1, "S")
    end

    return vim.call("fnamemodify", debug_info.source:gsub("^@", ""), ":p:h")
end

----------------------
-- MARK: Read Files --
----------------------

---@param path string
---@param err uv.callback.err
---@param stat uv.fs_stat.result?
---@return boolean ok, string? msg
local function fs_fstat_file_validate(path, err, stat)
    if not stat then
        local fmt_str = "input file %s: fstat returned no stat (%s)"
        local msg = string.format(fmt_str, path, err or "Does this file exist?")
        return false, msg
    elseif stat.type ~= "file" then
        local fmt_str = "input %s exists but is not a regular file (type: %s)"
        local msg = string.format(fmt_str, path, stat.type)
        return false, msg
    end

    return true, nil
end
-- TODO: This should be merged in with the code the sync version uses

---@param path string
---@param err uv.callback.err
---@param fd integer|nil
---@return boolean ok, string? msg
local function fs_open_validate(path, err, fd)
    if err then
        return false, string.format("fs_open error on %s: %s", path, err)
    elseif not fd then
        local fmt_str = "fs_open failed on %s: no file descriptor returned"
        local msg = string.format(fmt_str, path)
        return false, msg
    end

    return true, nil
end
-- TODO: This should be merged in with the code the sync version uses

---@async
---@param path string
---@param callback fun(err:uv.callback.err, content:string|nil)
local function read_file_async(path, callback)
    uv.fs_open(path, "r", 292, function(open_err, fd)
        local ok_o, err_o = fs_open_validate(path, open_err, fd)
        if not ok_o then
            callback(err_o, nil)
            return
        end

        uv.fs_fstat(fd, function(stat_err, stat)
            local ok_s, err_s = fs_fstat_file_validate(path, stat_err, stat)
            if not ok_s then
                uv.fs_close(fd, function() end)
                callback(err_s, nil)
                return
            end

            ---@diagnostic disable-next-line: need-check-nil Checked in validation.
            uv.fs_read(fd, stat.size, 0, function(read_err, content)
                uv.fs_close(fd, function() end)
                callback(read_err, content)
            end)
        end)
    end)
end

---@class docgen.file.FsReadListOpts
---@field jobs_max? integer (default: 8) Maximum simultaneous file reads
---@field timeout? integer (default: 1000) Timeout (ms).

---@alias docgen.file.FsReadListResult [boolean,string?,uv.callback.err]

---@param paths string[] Assumes at least one path is provided.
---@param on_complete fun(success:boolean, timed_out:boolean, results:table<string,docgen.file.FsReadListResult>)
---@param opts docgen.file.FsReadListOpts
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

    ---@type table<string,docgen.file.FsReadListResult>
    local results = table_new(paths_count, 0)

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
---@param opts docgen.file.FsReadListOpts
local function validate_fs_read_list(paths, opts)
    local nty = require("nvim-tools.types")
    vim.validate("paths", paths, function()
        return nty.valid_list(paths, { item_type = "string", min_len = 1 })
    end)

    vim.validate("opts.max_jobs", opts.jobs_max, nty.is_uint, true)
    vim.validate("opts.timeout", opts.timeout, nty.is_uint, true)
end

---Run simultaneous |uv.fs_read()| jobs with file validation and use |vim.wait()| to mimic
---async join.
---@param paths string[]
---@param opts docgen.file.FsReadListOpts?
---@return boolean ok, boolean timed_out, table<string,docgen.file.FsReadListResult>? results
function M.fs_read_list(paths, opts)
    opts = opts or {}
    validate_fs_read_list(paths, opts)
    if #paths == 0 then
        return true, false, nil
    end

    local complete = false
    local ok = false
    local timed_out = false
    local results ---@type table<string,docgen.file.FsReadListResult>|nil

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
-- TODO: Refresh the nvim-tools code

---@param results table<string,docgen.file.FsReadListResult>?
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

-----------------------
-- MARK: Write Files --
-----------------------

---Assumes that incoming paths are absolute or properly relative to the caller.
---@param dir_default string
---@param fname_default string
---@param path? string
---@return boolean ok, string path, uv.fs_stat.result? stat, string? err, uv.error_name? err_name
function M.path_for_open_setup_checked(dir_default, fname_default, path)
    if not (path and string.find(path, "[^%s]") ~= nil) then
        path = fs.joinpath(dir_default, fname_default)
    end

    local stat, err, err_name = uv.fs_stat(path)
    if stat then
        if stat.type == "file" then
            return true, path, stat, err, err_name
        elseif stat.type == "directory" then
            return true, fs.joinpath(path, fname_default), stat, err, err_name
        else
            return false, path, stat, err, err_name
        end
    end

    local path_dir = fn.fnamemodify(path, ":h")
    local d_stat, d_err, d_err_name = uv.fs_stat(path_dir)
    if d_stat then
        if d_stat.type == "directory" then
            return true, path, d_stat, d_err, d_err_name
        else
            return false, path_dir, d_stat, d_err, d_err_name
        end
    end

    local did_mkdir = fn.mkdir(path_dir, "p")
    if did_mkdir == 1 then
        return true, path, d_stat, d_err, d_err_name
    end

    return false, path_dir, d_stat, d_err, d_err_name
end
-- TODO: In the no stat case, we need to check I think that the file path doesn't end in a fwd
-- slash or something to make sure it's not a dir.
-- TODO: Make a light attempt at making uv_fs_access work here. If issue is more involved, needs
-- to go in MID.
-- MID:DEP: If we come across an application where this function is used repeatedly, can add an
-- opt to return the default without validation.

return M

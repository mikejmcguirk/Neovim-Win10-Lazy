local uv = vim.uv

local file_ops = require("docgen.file_ops")
local path_for_open_setup_checked = file_ops.path_for_open_setup_checked

local DEFAULT_LOG_FILE = "nvim-tools_docgen.log"
local level = 0 ---@type 0|1
local handle = nil
local log_path_res = nil

local M = {}

---@param priority string
---@param msg string
local function log(priority, msg)
    if not handle then
        print(msg)
        return
    end

    local log_line = {}

    local sec, usec = uv.gettimeofday()
    local datetime = os.date("%Y-%m-%d %H:%M:%S", sec)
    local fmt_usec = string.format(".%03d", math.floor(usec / 1000))

    log_line[#log_line + 1] = datetime
    log_line[#log_line + 1] = fmt_usec
    log_line[#log_line + 1] = " - "
    log_line[#log_line + 1] = priority
    log_line[#log_line + 1] = msg
    log_line[#log_line + 1] = "\n"

    local bytes, w_err, w_err_name = uv.fs_write(handle, table.concat(log_line))
    if not bytes then
        local fmt_str = "On write - %s (%s): %s"
        error(string.format(fmt_str, w_err_name, log_path_res, w_err))
    end

    print(table.concat(log_line, "", 4, 5))
end

---@param msg string
function M.log_warning(msg)
    if level < 1 then
        return
    end

    log("WARNING: ", msg)
end

---@param msg string
function M.log(msg)
    log("", msg)
end

-- Add a "default_fname" param

---@param level_in (0|1)?
---@param debug_path string
---@param log_path? string
function M.create_logger(level_in, debug_path, log_path)
    level = level_in or 0
    if level <= 0 then
        return
    end

    local ok, path_res, stat, err, err_name =
        path_for_open_setup_checked(debug_path, DEFAULT_LOG_FILE, log_path)
    if not ok then
        local fmt_str = "%s (%s): %s.\nStat: %s"
        error(string.format(fmt_str, err_name, path_res, err, vim.inspect(stat)))
    end

    -- TODO: What is 438 again?
    local fd, o_err, o_err_name = uv.fs_open(path_res, "a", 438)
    if not fd then
        local fmt_str = "On open - %s (%s): %s. \nStat: %s"
        error(string.format(fmt_str, o_err_name, path_res, o_err, vim.inspect(stat)))
    end

    handle = fd
end

function M.close_logger()
    if handle then
        uv.fs_close(handle)
    end
end

return M

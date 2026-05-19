local uv = vim.uv

local file_ops = require("docgen.file_ops")
local fs_write_checked = file_ops.fs_write_checked
local open_path_validated = file_ops.open_path_validated

local DEFAULT_LOG_FILE = "nvim-tools_docgen.log"
local level = 0 ---@type 0|1
local handle = nil

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

    local _, err = fs_write_checked(handle, table.concat(log_line))
    if err then
        error(err)
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

---@param level_in 0|1
---@param path string
function M.create_logger(level_in, path)
    level = level_in or 0
    if level <= 0 then
        return
    end

    local fd, err = open_path_validated(path, "a", 438, DEFAULT_LOG_FILE)
    if not fd then
        error(err)
    end

    handle = fd
end

function M.close_logger()
    if handle then
        uv.fs_close(handle)
    end
end

return M

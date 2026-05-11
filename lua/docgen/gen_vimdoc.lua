#!/usr/bin/env -S nvim -l

local fn = vim.fn
local fs = vim.fs
local uv = vim.uv

local debug_info = debug.getinfo(2, "S")
if not debug_info then
    debug_info = debug.getinfo(1, "S")
end

local debug_source = debug_info.source:gsub("^@", "")
local script_path = fn.fnamemodify(debug_source, ":p:h")

local DEFAULT_LOG_FILE = "docgen.log"
local DEFAULT_OUTPUT_FILE = "doc_output.txt"

--------------------------------------
-- MARK: Logging Data and Functions --
--------------------------------------

local log_level = 0
local log_file_handle = nil

---0: Outputs to console, even if no log file present
---1: Standard logging
---2: Debug logging
---@alias LogLevel 0|1|2

---@param prefix string
---@param msg string
local function get_log_msg(prefix, msg)
    local sec, usec = uv.gettimeofday()
    local datetime = os.date("%Y-%m-%d %H:%M:%S", sec)
    local fmt_usec = string.format(".%03d", math.floor(usec / 1000))
    local timestamp = datetime .. fmt_usec

    return string.format("%s %s : %s\n", prefix, timestamp, tostring(msg))
end

---@param msg string
local function log_error(msg)
    if not log_file_handle then
        return
    end

    local line = get_log_msg("ERROR:", msg)
    log_file_handle:write(line)
    log_file_handle:flush()
    log_file_handle:close()
end
-- MID: Is it possible to put the error() call in here and have Lua_Ls recognize that it ends the
-- program?

-----------------------------
-- MARK: Param Bookkeeping --
-----------------------------

---@param path string?
---@param default_fname string
---@return string
local function resolve_output_path(path, default_fname)
    -- Doing it this way makes Lua_Ls happy
    if type(path) ~= "string" or path == "" then
        return fs.joinpath(script_path, default_fname)
    end

    -- vim.fs.abspath might be changed to use fnamemodify :p:h, so use this for stability
    local abs = fs.normalize(fn.fnamemodify(path, ":p"))
    local dir = fs.dirname(abs)
    local stat, err = uv.fs_stat(dir)
    if not stat then
        local err_msg = err or "unknown error"
        local msg = string.format("output parent directory %s: %s", dir, err_msg)
        log_error(msg)
        error(msg)
    elseif stat.type ~= "directory" then
        local msg = string.format("%s exists but is not a directory (type: %s)", dir, stat.type)
        log_error(msg)
        error(msg)
    end

    local basename = fs.basename(abs)
    if fn.isdirectory(abs) == 1 or basename == "" then
        return fs.joinpath(abs, "/doc_output.txt")
    end

    -- vim.fs.ext is just a wrapper for this
    local ext = fn.fnamemodify(abs, ":e")
    if ext == "" then
        abs = fs.joinpath(abs, ".txt")
    end

    return abs
end
-- MID: Could the check for a valid output file be more robust?
-- MID: More detailed error reporting.

---@param paths string[]
local function validate_input_files(paths)
    for _, path in ipairs(paths) do
        local stat, err = uv.fs_stat(path)
        if not stat then
            local fmt_str = "input file %s: %s"
            local msg = string.format(fmt_str, path, err or "does not exist")
            log_error(msg)
            error(msg)
        elseif stat.type ~= "file" then
            local fmt_str = "input %s exists but is not a regular file (type: %s)"
            local msg = string.format(fmt_str, path, stat.type)
            log_error(msg)
            error(msg)
        end
    end
end

---@param level? integer
---@param path? string
local function setup_log(level, path)
    log_level = level or 0
    if log_level <= 0 then
        return
    end

    local log_path = resolve_output_path(path, DEFAULT_LOG_FILE)
    local file, err = io.open(log_path, "a")
    if not file then
        local err_msg = err or "unknown error"
        local msg = string.format("Failed to open log file %s: %s", log_path, err_msg)
        log_error(msg)
        error(msg)
    end

    log_file_handle = file
end
-- MID: Should create numbered log files based on the file size of the path.

---@param inputs string[]
---@param output string?
---@param level integer?
---@param log_path string?
local function validate_target_inputs(inputs, output, level, log_path)
    if type(inputs) ~= "table" or #inputs == 0 then
        print("No source files provided")
        os.exit(1)
    end

    vim.validate("output", output, "string", true)
    vim.validate("log_path", log_path, "string", true)
    vim.validate("level", level, function()
        return level % 1 == 0 and 0 <= level and level <= 2
    end, true)
end

local M = {}

---Main generator function
---@param inputs string[] Input filepaths
---@param output string? Output file
---@param level integer? Log level
---- 0 Standard output only
---- 1 Standard messages
---- 2 Debug messages
---@param log_path string? Log path
function M.generate(inputs, output, level, log_path)
    validate_target_inputs(inputs, output, level, log_path)

    setup_log(level, log_path)
    validate_input_files(inputs)
    local output_path = resolve_output_path(output, DEFAULT_OUTPUT_FILE)

    require("docgen.renderer").render_docs(inputs, output_path)
end

local function print_help()
    print([[
docgen.lua - Generate Vimdoc from Lua files

Usage:
  ./docgen.lua [OPTIONS] input1.lua [input2.lua ...]

Options:
  -o, --output <path>      Output file or directory.
                           Default: doc_output.txt in script directory.
                           Pre-existing files are overwritten.

  -l, --log-level <0|1|2>  0 = console messages only
                           1 = standard logging
                           2 = debug logging (default: 0)

  -g, --log-file <path>    Custom log file path.
                           Default: docgen.log in script directory.
                           Pre-existing files are appended to.

  -h, --help               Show this help message and exit.
]])
end
-- TODO: Document that, if called from another Lua script, that other Lua script will be treated
-- as the pwd

---@param args string[]
---Input files, output path, log level, log path
---@return string[], string?, integer?,string?
local function parse_args(args)
    local inputs = {} ---@type string[]
    local output = nil ---@type string?
    local level = nil ---@type integer?
    local log_path = nil ---@type string?

    local i = 1
    local in_inputs = false
    local len_args = #args

    while i <= len_args do
        local arg = args[i]
        if in_inputs then
            inputs[#inputs + 1] = arg
        elseif arg == "--" then
            in_inputs = true
        elseif arg == "-o" or arg == "--output" then
            i = i + 1
            if i <= len_args then
                output = args[i]
            else
                error("Output flag provided with no path")
            end
        elseif arg == "-l" or arg == "--log-level" then
            i = i + 1
            if i <= len_args then
                local lvl_arg = args[i]
                local lvl = tonumber(lvl_arg)
                if not lvl or lvl < 0 or lvl > 2 or lvl % 1 ~= 0 then
                    local fmt_str = "Log level must be 0, 1, or 2 (%s provided)"
                    error(string.format(fmt_str, lvl_arg))
                end

                level = lvl
            else
                error("Log level flag provided with no level")
            end
        elseif arg == "-g" or arg == "--log-file" then
            i = i + 1
            if i <= len_args then
                log_path = args[i]
            else
                error("Log path flag provided with no path")
            end
        else
            in_inputs = true
            inputs[#inputs + 1] = arg
        end

        i = i + 1
    end

    return inputs, output, level, log_path
end

if arg then
    for _, a in ipairs(arg) do
        if a == "-h" or a == "--help" then
            print_help()
            os.exit(0)
        end
    end

    local inputs, output, level, log_path = parse_args(arg)
    if #inputs > 0 then
        M.generate(inputs, output, level, log_path)
    end
end

return M

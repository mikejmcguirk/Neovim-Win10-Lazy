#!/usr/bin/env -S nvim -l

if not jit then
    error("Requires Neovim built with LuaJIT to run.")
end

local luacats_parser = require("docgen.luacats_parser")
local parsed_from_file = luacats_parser.parsed_from_file

local holistic = require("docgen.holistic")
local resolve_holistic = holistic.parsed_sources_resolve_holistic

local renderer = require("docgen.renderer")
local render_docs = renderer.render_docs

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

---@class docgen.Source
---@field [1] string Name
---@field [2] "file"|"lines"|"str" Type
---@field [3] string[] Lines to parse
---@field [4] string String to parse

---@class docgen.ParsedSource
---@field [1] string Formatted Source Name
---@field [2] docgen.ParserObj[] Objs

---Main generator function
---@param sources string[] Input filepaths
---@param output string? Output file
---@param level integer? Log level
---- 0 Standard output only
---- 1 Standard messages
---- 2 Debug messages
---@param log_path string? Log path
function M.generate(sources, output, level, log_path)
    validate_target_inputs(sources, output, level, log_path)

    -- TODO: Outline this business
    setup_log(level, log_path)
    -- TODO: It should be possible to parse strings or line collections as well
    validate_input_files(sources)
    local output_path = resolve_output_path(output, DEFAULT_OUTPUT_FILE)

    -- TODO: This is about where this should be determined.
    -- TODO: This needs to be validated to be a string with at least one character and
    -- valid helptag text.
    -- TODO: Bring in the spec's helptag syntax for evaluation. Needed here because we are basing
    -- on external info.
    _G.Nvim_Tools_Docgen_Help_Prefix = "demo-help"

    local parsed_sources = {} --- @type docgen.ParsedSource[]
    for _, source in vim.spairs(sources) do
        local parsed = parsed_from_file(source)
        parsed_sources[#parsed_sources + 1] = parsed
    end

    resolve_holistic(parsed_sources)
    if #parsed_sources == 0 then
        -- TODO: Improve
        print("No parsed data to render")
        return
    end

    -- TODO: Printing output should not also be handled here
    render_docs(parsed_sources, output_path)
end
-- NON: Leave the help prefix as a global.
-- - It does not change throughout program execution
-- - Passing it through the callstack is cumbersome, especially because text parsing is a
--   lower-level task that can sit in different, deeply nested places.

return M

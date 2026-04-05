#!/usr/bin/env -S nvim -l

local fn = vim.fn
local fs = vim.fs
local uv = vim.uv

local DEFAULT_LOG_FILE = "docgen.log"
local DEFAULT_OUTPUT_FILE = "doc_output.txt"

local log_level = 0
local log_file_handle = nil

---0: Outputs to console, even if no log file present
---1: Standard logging
---2: Debug logging
---@alias OldLogLevel 0|1|2

---@type table<LogLevel, string>
local log_prefixes = {
    [0] = "MSG:",
    [1] = "LOG:",
    [2] = "DEBUG:",
}

---@param prefix string
---@param msg string
local function get_log_msg(prefix, msg)
    local sec, usec = uv.gettimeofday()
    local timestamp = os.date("%Y-%m-%d %H:%M:%S", sec)
        .. string.format(".%03d", math.floor(usec / 1000))

    return string.format("%s %s : %s\n", prefix, timestamp, tostring(msg))
end

---@param msg string
---@param level LogLevel
local function log(msg, level)
    if log_level < level then
        return
    end

    if level <= 0 then
        print(msg)
    end

    if not log_file_handle then
        return
    end

    local prefix = log_prefixes[level] or "LOG:"
    local line = get_log_msg(prefix, msg)
    log_file_handle:write(line)
    log_file_handle:flush()
end
-- MID: Is this the fastest way to do this? These can fire a lot if in in debug mode.

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

local M = {}

local function get_exec_dir()
    local source = debug.getinfo(2, "S").source:gsub("^@", "")
    return fn.fnamemodify(source, ":p:h")
end

local debug_info = debug.getinfo(2, "S")
if not debug_info then
    debug_info = debug.getinfo(1, "S")
end

local debug_source = debug_info.source:gsub("^@", "")
local script_path = fn.fnamemodify(debug_source, ":p:h")
print(script_path)

---@param path string?
---@param default_fname string
---@return string
local function resolve_output_path(path, default_fname)
    -- Doing it this way makes Lua_Ls happy
    if type(path) ~= "string" or path == "" then
        return fs.joinpath(get_exec_dir(), default_fname)
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

---@param path string
---@param lines string[]
local function write_file_lines(path, lines)
    local file, err = io.open(path, "w")
    if not file then
        local msg = err or ("Unknown error opening " .. path)
        log_error(msg)
        error(msg)
    end

    local content = table.concat(lines, "\n") .. "\n"
    file:write(content)
    file:close()
end

---@alias BlockType 0|1|2|3|4|5

local NO_BLOCK = 0
local UNKNOWN = 1
local CLASS = 2
local INLINE = 3
local CLASS_INLINE = 4
local FUNCTION = 5

---@alias BlockState 0|1

local OPEN = 0
local COMPLETE = 1

local annotation_type_map = {
    ["class"] = CLASS,
    ["inlinedoc"] = INLINE,
    ["param"] = FUNCTION,
}

---@param line string
---@return string?
local function get_annotation_tag(line)
    return string.match(line, "^%-%-%-%s*@(%S+)")
end

---@alias StartAnnotations "class"|"param"

local start_annotations = { "class", "param" }

---@param line string
---@return BlockType?
local function is_annotation_start(line)
    local annotation = get_annotation_tag(line)
    if not annotation then
        return nil
    end

    for _, start_annotation in ipairs(start_annotations) do
        if annotation == start_annotation then
            return annotation_type_map[annotation]
        end
    end

    return nil
end

---@param line string
---@return boolean
local function is_doc_only_comment(line)
    return string.find(line, "^%-%-%-") ~= nil
end

---@param line string
---@return BlockType?
local function find_class(line)
    local annotation = get_annotation_tag(line)
    if annotation == "class" then
        return CLASS
    end
end

---@param line string
---@return BlockType?
local function find_inline_in_class(line)
    local annotation = get_annotation_tag(line)
    if annotation == "inlinedoc" then
        return CLASS_INLINE
    end
end

---@param line string
---@return BlockType?
local function find_any_doc_comment(line)
    local annotation = is_annotation_start(line)
    if annotation then
        return annotation
    end

    if is_doc_only_comment(line) then
        return UNKNOWN
    end
end

---@param line string
---@return BlockType?
local function find_annotation_start(line)
    local annotation = is_annotation_start(line)
    if annotation then
        return annotation
    end
end

---@param line string
---@return BlockType?
local function find_start_or_no_block(line)
    local annotation = is_annotation_start(line)
    if annotation then
        return annotation
    end

    if not is_doc_only_comment(line) then
        return NO_BLOCK
    end
end

---@class (exact) block.Properties
---@field commit boolean Is the block saved upon completion?
---Found block ending
---@field interrupt fun(line:string): boolean
---Block needs to change type
---@field morph fun(line:string): BlockType?
---Found start of a new block
---@field new_start fun(line:string): BlockType?

local block_properties = {
    ---@type block.Properties
    [NO_BLOCK] = {
        commit = false,
        interrupt = function()
            return false
        end,
        morph = function() end,
        new_start = find_any_doc_comment,
    },
    [UNKNOWN] = {
        commit = false,
        interrupt = function()
            return false
        end,
        morph = find_annotation_start,
        new_start = find_start_or_no_block,
    },
    [CLASS] = {
        commit = true,
        interrupt = function()
            return false
        end,
        morph = find_inline_in_class,
        new_start = find_start_or_no_block,
    },
    [INLINE] = {
        commit = false,
        interrupt = function()
            return false
        end,
        morph = find_class,
        new_start = find_start_or_no_block,
    },
    [CLASS_INLINE] = {
        commit = true,
        interrupt = function()
            return false
        end,
        morph = function() end,
        new_start = find_start_or_no_block,
    },
    [FUNCTION] = {
        commit = true,
        interrupt = function()
            return false
        end,
        morph = function() end,
        new_start = find_start_or_no_block,
    },
}

---@class (exact) Block : block.Properties
---@field block_type BlockType
---Checks if the line ends the block
---@field start integer inclusive, 1 indexed
---@field fin integer inclusive, 1 indexed
---Checks if the line changes the block type
---
---@field __index Block
---@field new fun(start:integer, block_type:BlockType): Block
local Block = {}
Block.__index = Block

---@param block_type BlockType
function Block:set_block_type(block_type)
    self.block_type = block_type
    local properties = block_properties[self.block_type]
    for k, v in pairs(properties) do
        self[k] = v
    end
end

---@param start integer
---@param block_type BlockType
function Block:reset_block(start, block_type)
    self.start = start
    self.fin = 0

    if self.block_type ~= block_type then
        self:set_block_type(block_type)
    end
end

---@param line string
---@param lnum integer
---@return BlockState, boolean, BlockType
function Block:ingest(line, lnum)
    if self.interrupt(line) then
        self.fin = lnum
        return COMPLETE, true, self.block_type
    end

    local morph = self.morph(line)
    if morph then
        self:set_block_type(morph)
        return OPEN, true, morph
    end

    local new_start = self.new_start(line)
    if new_start and new_start ~= self.block_type then
        self.fin = math.max(lnum - 1, 1)
        return COMPLETE, false, new_start
    end

    return OPEN, true, self.block_type
end

function Block:validate()
    assert(self.start > 0, "Block:validate - start (" .. self.start .. ") <= 0")
    assert(self.fin > 0, "Block:validate - fin (" .. self.fin .. ") <= 0")
    assert(
        self.start <= self.fin,
        "Block:validate - start(" .. self.start .. ") > fin (" .. self.fin .. ")"
    )
    assert(type(self.block_type) == "number", tostring(self.block_type) .. " is not a number")
end

---@param start integer
---@param block_type BlockType
function Block.new(start, block_type)
    local self = setmetatable({}, Block)
    self:reset_block(start, block_type)
    return self
end

---@param lines string[]
---@return Block[]
local function get_blocks(lines)
    local len_lines = #lines
    if len_lines < 1 then
        return {}
    end

    -- TODO: I think you need a separate inline_classes table common to all files for inlinedoc
    local blocks = {}
    local cur_block = Block.new(1, NO_BLOCK)

    local i = 1
    local count = 0
    while i <= len_lines and count <= 10000 do
        local block_state, advance, next_block_type = cur_block:ingest(lines[i], i)
        print(i, block_state, advance, next_block_type)
        if block_state == OPEN then
            i = i + 1
        else
            cur_block:validate()
            if advance then
                i = i + 1
            end

            if cur_block.commit then
                blocks[#blocks + 1] = cur_block
                cur_block = Block.new(i, next_block_type)
            else
                cur_block:reset_block(i, next_block_type)
            end
        end

        count = count + 1
    end

    return blocks
end
-- TODO: It would be better if it returned nil on no block, but don't want to fight data typing

---@param path string
---@return string[]
local function read_lines(path)
    local file, err = io.open(path, "r")
    if not file then
        local msg = err or ("Unknown error opening " .. path)
        log_error(msg)
        error(msg)
    end

    local lines = {} ---@type string[]
    for line in file:lines() do
        lines[#lines + 1] = line
    end

    file:close()
    return lines
end

---@param paths string[]
---@return string[]
local function generate_doc(paths)
    local all_lines = {} ---@type string[]
    local file_lines = {} ---@type table<string, string[]>
    for _, path in ipairs(paths) do
        local lines = read_lines(path)
        file_lines[path] = lines
    end

    local all_blocks = {} ---@type table<string, Block>
    for path, lines in pairs(file_lines) do
        all_blocks[path] = get_blocks(lines)
    end

    -- TODO: For debug. Eventually get rid of this
    for path, blocks in pairs(all_blocks) do
        local lines = file_lines[path]
        for _, block in ipairs(blocks) do
            for i = block.start, block.fin do
                all_lines[#all_lines + 1] = lines[i]
            end
        end
    end

    return all_lines
end

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

---Entry point if running from another Lua script.
---@param inputs string[]
---@param output string?
---@param level integer?
---@param log_path string?
function M.generate(inputs, output, level, log_path)
    if type(inputs) ~= "table" or #inputs == 0 then
        error("docgen.generate: expected non-empty table of file paths")
    end

    setup_log(level, log_path)
    validate_input_files(inputs)
    local output_path = resolve_output_path(output, DEFAULT_OUTPUT_FILE)

    log("Getting file data", 1)
    local combined = generate_doc(inputs)

    log("Writing output", 1)
    write_file_lines(output_path, combined)
    local fmt_str = "Generated %s from %d file(s) (%d lines total)"
    log(string.format(fmt_str, output_path, #inputs, #combined), 0)
end
-- TODO: Use vim.validate here

---@param args string[]
---Input files, output path, log level, log path
---@return string[], string?, integer?,string?
local function parse_cli_args(args)
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
                    error(string.format("Log level must be 0, 1, or 2 (%s provided)", lvl_arg))
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

-- For running as a standalone script.
if arg then
    for _, a in ipairs(arg) do
        if a == "-h" or a == "--help" then
            print_help()
            os.exit(0)
        end
    end

    local inputs, output, level, log_path = parse_cli_args(arg)
    if level then
        log_level = level
    end

    if #inputs > 0 then
        M.generate(inputs, output, level, log_path)
    end
end

return M

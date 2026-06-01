#!/usr/bin/env -S nvim -l

if not jit then
    error("Requires Neovim built with LuaJIT to run.")
end

local fs = vim.fs
local uv = vim.uv

local holistic = require("docgen.holistic")
local resolve_holistic = holistic.parsed_sources_resolve_holistic

local logger = require("docgen.logger")
local log = logger.log
local close_logger = logger.close_logger
local create_logger = logger.create_logger

local luacats_parser = require("docgen.luacats_parser")
local parsed_from_str = luacats_parser.parsed_from_str

local file_ops = require("docgen.file_ops")
local fs_write_checked = file_ops.fs_write_checked
local get_debug_path = file_ops.get_debug_path
local open_path_validated = file_ops.open_path_validated

local renderer = require("docgen.renderer")
local render_docs = renderer.render_docs

local util = require("docgen.util")
local list_common_prefix = util.list_common_prefix
local list_filter_map_accum = util.list_filter_map_accum
local list_filter_map_to = util.list_filter_map_to
local list_intersperse = util.list_intersperse
local list_splice = util.list_splice
local table_new = util.table_new

---@brief Full-featured Vimdoc generator for LuaCATs annotations. Simply run it with a list of
---files to get properly tagged and formatted docs.
---
---Supports the following features:
---  - Help tags are automatically generated based on the directory structure of the target files
---  - `@tag` annotations for defining additional helptags
---  - `@inlinedoc` and `@nodoc` to control display
---  - Automatic table of contents generation
---  - Descriptive text is parsed as markdown and automatically formatted, including line
---    wrapping
---  - `@deprecated` tags allow for a one-line description
---  - Optional output logging
---  - Async file read
---
---Requirements: ~
---
---Neovim built with LuaJIT. Supported versions:
---- Nightly
---- Current (`0.12`) and previous release (`0.11`)
---
---Installation: ~
---
---Clone the repo.
---
---CI Usage: ~
---
---Attribution: ~
---
---This is a fork of the Neovim core's doc generator. Accordingly, this project is also released
---under an Apache 2.0 license, with notices in the files containing modified core code.

-----------------------------
-- MARK: Param Bookkeeping --
-----------------------------

---@param sources [string,string?][]
---@return string help_prefix
---@return string[] header_tags Same order as the input.
local function header_tags_from_paths(sources)
    local split_paths = list_filter_map_to(sources, function(source)
        local segments = table_new(4, 0) ---@type string[]
        segments[#segments + 1] = "/" -- Reduce contrivance upstream
        for segment in vim.gsplit(source[1], "/", { plain = true }) do
            if segment ~= "" then
                segments[#segments + 1] = segment
            end
        end

        return segments
    end)

    local prefix_idx = list_common_prefix(split_paths) or 1
    for _, path in ipairs(split_paths) do
        list_splice(path, prefix_idx)
    end

    local prefix = split_paths[1][1]
    for _, path in ipairs(split_paths) do
        list_intersperse(path, "-", 1, 1, #path - 1)
    end

    for _, path in ipairs(split_paths) do
        local path_len = #path
        local fname = path[path_len]
        if fname ~= "init.lua" then
            path[path_len] = vim.call("fnamemodify", fname, ":r")
            list_intersperse(path, ".", 1, path_len - 1, path_len)
        else
            path[path_len] = nil
        end
    end

    local header_tags = list_filter_map_to(split_paths, function(path)
        local path_str = string.gsub(table.concat(path), "[ \t]", "__")
        return path_str
    end)

    return prefix, header_tags
end

---@param sources [string,string?][] Modified in place!
local function add_contents_to_sources(sources)
    local file_inputs = list_filter_map_to(sources, function(source)
        return source[2] == nil and source[1] or nil
    end)

    if #file_inputs == 0 then
        return
    end

    local ok, timed_out, results = file_ops.fs_read_list(file_inputs)
    if not (ok and results) then
        if timed_out then
            error("Time out while reading file data")
        else
            error(file_ops.fs_read_list_get_errs(results))
        end
    end

    list_filter_map_accum(sources, results, function(acc_results, source)
        source[2] = source[2] or acc_results[source[1]][2]
        return acc_results, source
    end)
end

---@param inputs string[]
---@param output string?
---@param level integer?
---@param log_path string?
local function generate_params_validate(inputs, output, level, log_path)
    -- TODO: Also validate elements
    if type(inputs) ~= "table" or #inputs == 0 then
        print("No source files provided")
        os.exit(1) -- TODO: Is this right? I feel like there was some Nvim core issue about this.
    end

    vim.validate("output", output, "string", true)
    vim.validate("log_path", log_path, "string", true)
    vim.validate("level", level, function()
        return level % 1 == 0 and 0 <= level and level <= 1
    end, true)
end

local M = {}

-- TODO: The bullets under level don't indent
-- TODO: If the bullets under level are manually indented, they don't bullet format.

---Main generator function
---@param sources [string,string?][] Input filepaths. The second part of the tuple can contain a
---string to parse, skipping file reading.
---@param output string? Output file
---@param level integer? Log level
---- 0 No log messages
---- 1 Warning messages
---@param log_path string? Log path
function M.generate(sources, output, level, log_path)
    generate_params_validate(sources, output, level, log_path)

    for _, source in ipairs(sources) do
        source[1] = fs.normalize(vim.call("fnamemodify", source[1], ":p"))
    end

    local debug_path = get_debug_path()
    create_logger(level, debug_path, log_path)

    add_contents_to_sources(sources)
    local prefix, header_tags = header_tags_from_paths(sources)
    _G.Nvim_Tools_Docgen_Help_Prefix = prefix
    list_filter_map_accum(sources, header_tags, function(acc_tags, source, idx)
        source[3] = acc_tags[idx]
        return acc_tags, source
    end)

    --- @type docgen.ParsedSource[]
    local parsed_sources = list_filter_map_to(sources, function(source)
        return parsed_from_str(source[2], source[3])
    end)

    resolve_holistic(parsed_sources, header_tags)
    if #parsed_sources == 0 then
        -- TODO: Improve
        log("No parsed data to render")
        close_logger()
        return
    end

    local docs = render_docs(parsed_sources)
    log("Writing output")
    local default_output_fname = Nvim_Tools_Docgen_Help_Prefix .. ".txt"
    if not (output and string.find(output, "[^%s]") ~= nil) then
        output = fs.joinpath(debug_path, default_output_fname)
    end

    -- TODO: There should be two calls here, the first is "get_uv_validated_path" and the other
    -- is "uv_write_checked" or something.
    -- Like, below, just as a read, it doesn't make sense that we resolved output above but
    -- we're then also feeding the default as a backup to the open path.
    -- TODO: Also, I'm not sure if the output path should be eagerly validated, but the
    -- string data at least needs to be resolved. Maybe that involves eagerly checking if the
    -- provided path is a directory so that we know if we need to run joinpath.

    local fd, err = open_path_validated(output, "w", 438, default_output_fname)
    if not fd then
        error("On output path open: " .. tostring(err))
    end

    local _, write_err = fs_write_checked(fd, docs)
    if write_err then
        error(err)
    end

    uv.fs_close(fd)
    close_logger()
end
-- NON: Leave the help prefix as a global.
-- - It does not change throughout program execution
-- - Passing it through the callstack is cumbersome

return M

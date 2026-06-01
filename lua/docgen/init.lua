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
local list_filter_map_to = util.list_filter_map_to
local list_filter_map_accum = util.list_filter_map_accum

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

---@param inputs string[]
---@param output string?
---@param level integer?
---@param log_path string?
local function validate_params(inputs, output, level, log_path)
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
    validate_params(sources, output, level, log_path)

    for _, source in ipairs(sources) do
        source[1] = fs.normalize(vim.call("fnamemodify", source[1], ":p"))
    end

    local debug_path = get_debug_path()
    create_logger(level, debug_path, log_path)

    local file_inputs = list_filter_map_to(sources, function(source)
        return source[2] == nil and source[1] or nil
    end)

    local ok, timed_out, results = file_ops.fs_read_list(file_inputs)
    if not (ok and results) then
        if timed_out then
            error("Time out while reading file data")
        else
            error(file_ops.fs_read_list_get_errs(results))
        end
    end

    -- TODO: It feels like there has to be some kind of functional list op for getting the
    -- common prefix from a group of sub-lists. So you'd get that first, then use that to
    -- get the header tags. I also want to be plugging everything into the sources list rather
    -- than another intermediate table.
    --
    -- - For sanity purposes, map sources to the split filenames
    -- - Create a generalized common prefix idx function that can be used on the split
    --   filepaths.
    -- - For re-combining, the end of the common prefix is used so we have a common header. So
    --   you want to map the parts starting there. We also want to add a basic intersperse function
    --   to add the dashes between most of the name components. We still want the dot both
    --   because it mirrors Lua requires and it helps to guard against duplicates where you have
    --   a folder containing init.lua with a file in the same directory. After doing the
    --   intersperse in place, then do another round where you add the dot unless it's init.lua,
    --   in which case you lop it off. Also make sure to do fnamemodify :r. I'm unsure if the
    --   table_new thing stays or is even necessary, since we should be able to map the split
    --   parts in place. Like, do a splice first, then intersperse. So you aren't allocating
    --   new RAM. And then finally you would map_two in place on top of the original sources.
    -- - Also, take the code out of file_ops, since it doesn't actually interact with the
    --   file system.
    local prefix, header_tags = file_ops.header_tags_from_paths(sources)
    _G.Nvim_Tools_Docgen_Help_Prefix = prefix
    list_filter_map_accum(sources, header_tags, function(acc_tags, source, idx)
        source[2] = source[2] or results[source[1]][2]
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

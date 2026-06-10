#!/usr/bin/env -S nvim -l

if not jit then
    error("Requires Neovim built with LuaJIT to run.")
end

local fs = vim.fs
local uv = vim.uv

local const = require("docgen.const")
local INDENT = const.INDENT

local holistic = require("docgen.holistic")
local resolve_holistic = holistic.parsed_sources_resolve_holistic

local logger = require("docgen.logger")
local log = logger.log
local logger_close = logger.close_logger
local logger_create = logger.create_logger

local luacats_parser = require("docgen.luacats_parser")
local parsed_from_str = luacats_parser.parsed_from_str

local file_ops = require("docgen.file_ops")
local debug_path_get = file_ops.get_debug_path
local path_for_open_setup_checked = file_ops.path_for_open_setup_checked

local renderer = require("docgen.obj_renderer")
local get_header = renderer.get_header
local render_objs = renderer.render_objs

local util = require("docgen.util")
local err_if_seen_or_append = util.err_if_seen_or_add
local get_requirable_path = util.get_requirable_path
local list_chain = util.list_chain
-- local list_fold = util.list_fold
local list_filter_map_to = util.list_filter_map_to
local list_intersperse = util.list_intersperse
-- local list_map_to_table = util.list_map_to_table
local list_splice = util.list_splice
local table_common_prefix = util.table_common_prefix
local list_filter_map = util.list_filter_map
local list_filter_map_two = util.list_filter_map_two
local table_filter_map_to = util.table_filter_map_to
local table_new = util.table_new

---@param default_fname string
---@param debug_path string
---@param output_path string?
---@param docs string
local function write_all(default_fname, debug_path, output_path, docs)
    local ok, output_res, stat, err, err_name =
        path_for_open_setup_checked(debug_path, default_fname, output_path)
    if not ok then
        local fmt_str = "%s (%s): %s.\nStat: %s"
        error(string.format(fmt_str, err_name, output_res, err, vim.inspect(stat)))
    end

    -- TODO: What is 438 again?
    local fd, o_err, o_err_name = uv.fs_open(output_res, "w", 438)
    if not fd then
        local fmt_str = "On open - %s (%s): %s. \nStat: %s"
        error(string.format(fmt_str, o_err_name, output_res, o_err, vim.inspect(stat)))
    end

    local bytes, w_err, w_err_name = uv.fs_write(fd, docs)
    if not bytes then
        local fmt_str = "On write - %s (%s): %s. \nStat: %s"
        error(string.format(fmt_str, w_err_name, output_res, w_err, vim.inspect(stat)))
    end

    uv.fs_close(fd)
end

----------------------
-- MARK: Gen Plugin --
----------------------

---@param prefix string
---@param debug_path string
---@param output_path string?
---@param docs string
local function write_plugin(prefix, debug_path, output_path, docs)
    log("Writing plugin.lua")
    local default_output_fname = prefix .. ".lua"
    write_all(default_output_fname, debug_path, output_path, docs)
end

---@alias docgen.PluginPartFn fun(source:docgen.gen.input.Plugin, prefix:string): docgen.gen.VimdocPart

---@type table<string, docgen.PluginPartFn>
local plugin_part_fns = {
    ["default_map"] = function(source, prefix)
        local header =
            "---------------------------\n-- MARK: Default Keymaps --\n ---------------------------"
        if source.text then
            return { header = header, txt = source.text }
        end

        local req_path = get_requirable_path(source.path)
        local maps = require(req_path)
        local lua = require("docgen.gen_keymaps").gen_default_maps_lua(maps, prefix)
        return { header = header, txt = lua }
    end,
    ["plug_map"] = function(source, prefix)
        local header = "---------------------\n-- MARK: Plug Maps --\n---------------------"
        if source.text then
            return { header = header, txt = source.text }
        end

        local req_path = get_requirable_path(source.path)
        local maps = require(req_path)
        local lua = require("docgen.gen_keymaps").gen_plug_maps_lua(maps, prefix)
        return { header = header, txt = lua }
    end,
    ["_default"] = function(source, _)
        return { txt = source.text or "" }
    end,
}

---@param source docgen.gen.input.Plugin
---@param prefix string
---@param plugin_parts string[]
local function plugin_part_append(source, prefix, imported, plugin_parts)
    local plugin_part_tbl = {}

    local plugin_part_fn = plugin_part_fns[source.type] or plugin_part_fns["_default"]
    local plugin_part = plugin_part_fn(source, prefix)
    if plugin_part.header then
        plugin_part_tbl[#plugin_part_tbl + 1] = plugin_part.header
    end

    if source.cond then
        plugin_part_tbl[#plugin_part_tbl + 1] = "if " .. source.cond .. " then"
    end

    if plugin_part.txt then
        plugin_part_tbl[#plugin_part_tbl + 1] = plugin_part.txt
    end

    if source.cond then
        plugin_part_tbl[#plugin_part_tbl + 1] = "end"
    end

    -- TODO: Why pass the ref to do this here. You should be able to be like
    -- parts[#parts + 1] = append_fn(whatever)
    plugin_parts[#plugin_parts + 1] = table.concat(plugin_part_tbl, "\n")
end
-- TODO: plugin part is bad naming because it implies that, like doc parts, they encode data
-- beyond text.

---@param plugin_sources docgen.gen.input.Plugin[]
---@param imported table<string, string>
---@param prefix string
---@param debug_path string
---@param opts docgen.gen.Opts
local function gen_plugin(plugin_sources, imported, prefix, debug_path, opts)
    local plugin_tbl = {} ---@type string[]
    plugin_tbl[#plugin_tbl + 1] = "-- stylua: ignore start"
    for _, source in ipairs(plugin_sources) do
        plugin_part_append(source, prefix, imported, plugin_tbl)
    end

    plugin_tbl[#plugin_tbl + 1] = "-- stylua: ignore end"
    local docs = table.concat(plugin_tbl, "\n\n")
    write_plugin(prefix, debug_path, opts.plugin_output_path, docs)
end

----------------------
-- MARK: Gen README --
----------------------

---@param debug_path string
---@param output_path string?
---@param docs string
local function write_readme(debug_path, output_path, docs)
    log("Writing README")
    local default_output_fname = "README.md"
    write_all(default_output_fname, debug_path, output_path, docs)
end

---@alias docgen.ReadmePartFn fun(source:docgen.gen.input.Readme, prefix:string): docgen.gen.VimdocPart

---@type table<string, docgen.ReadmePartFn>
local readme_part_fns = {
    ["keymap"] = function(source, _)
        local header = "## Keymaps"
        if source.text then
            return { header = header, txt = source.text }
        end

        local req_path = get_requirable_path(source.path)
        local maps = require(req_path)
        local md = require("docgen.gen_keymaps").gen_keymap_md(maps)
        return { header = header, txt = md }
    end,
    ["_default"] = function(source, _)
        return { txt = source.text or "" }
    end,
}

---@param source docgen.gen.input.Readme
---@param prefix string
---@param readme_parts string[]
local function readme_part_append(source, prefix, imported, readme_parts)
    local part_tbl = {}

    local readme_part_fn = readme_part_fns[source.type] or readme_part_fns["_default"]
    local readme_part = readme_part_fn(source, prefix)
    if readme_part.header then
        part_tbl[#part_tbl + 1] = readme_part.header
    end

    if readme_part.txt then
        part_tbl[#part_tbl + 1] = readme_part.txt
    end

    readme_parts[#readme_parts + 1] = table.concat(part_tbl, "\n")
end
-- TODO: readme part is bad naming because it implies that, like doc parts, they encode data
-- beyond text.

---@param readme_sources docgen.gen.input.Readme[]
---@param imported table<string, string>
---@param prefix string
---@param debug_path string
---@param opts docgen.gen.Opts
local function gen_readme(readme_sources, imported, prefix, debug_path, opts)
    local readme_tbl = {} ---@type string[]
    for _, source in ipairs(readme_sources) do
        readme_part_append(source, prefix, imported, readme_tbl)
    end

    local docs = table.concat(readme_tbl, "\n\n")
    write_readme(debug_path, opts.readme_output_path, docs)
end

---@param help_prefix string
---@param debug_path string
---@param output_path string?
---@param docs string
local function write_vimdoc(help_prefix, debug_path, output_path, docs)
    log("Writing Vimdoc")
    local default_output_fname = help_prefix .. ".txt"
    write_all(default_output_fname, debug_path, output_path, docs)
end

----------------------
-- MARK: Gen Vimdoc --
----------------------

---@alias docgen.DocPartFn fun(source:docgen.gen.source.Vimdoc, prefix:string, imported:table<string, string>): doc_part:docgen.gen.VimdocPart

---@type table<string, docgen.DocPartFn>
local doc_part_fns = {
    ["luacats"] = function(source, prefix, imported)
        local header = get_header(source.name, "=", { source.header_tag })
        local objs = parsed_from_str(imported[source.path], prefix, source.header_tag)
        return { header = header, objs = objs }
    end,
    ["keymap"] = function(source, prefix, _)
        local header = get_header(source.name, "=", { source.header_tag })
        local req_path = get_requirable_path(source.path)
        local maps = require(req_path)
        local vimdoc = require("docgen.gen_keymaps").gen_keymap_vimdoc(maps, prefix)
        return { header = header, txt = vimdoc }
    end,
}

---@param source docgen.gen.source.Vimdoc
---@param doc_parts docgen.gen.VimdocPart[]
---@param objs_list docgen.ParserObj[]
local function doc_part_append(source, prefix, imported, doc_parts, objs_list)
    local doc_part_fn = doc_part_fns[source.type]
    if doc_part_fn then
        local doc_part = doc_part_fn(source, prefix, imported)
        doc_parts[#doc_parts + 1] = doc_part
        if doc_part.objs then
            objs_list[#objs_list + 1] = doc_part.objs
        end
    end
end

-- TODO: Gotta break out VimdocPart because readme and plug don't need to save header tags

---@nodoc
---@class (exact) docgen.gen.VimdocPart
---@field header? string
---@field header_tag? string
---@field objs? docgen.ParserObj
---@field txt? string

---@param vimdoc_sources docgen.gen.source.Vimdoc[]
---@param imported table<string, string>
---@param prefix string
---@param debug_path string
---@param opts docgen.gen.Opts
local function gen_vimdoc(vimdoc_sources, imported, prefix, debug_path, opts)
    local doc_parts = {} ---@type docgen.gen.VimdocPart[]
    local obj_lists = {} ---@type docgen.ParserObj[][]
    for _, source in ipairs(vimdoc_sources) do
        doc_part_append(source, prefix, imported, doc_parts, obj_lists)
    end

    local all_tags = {} ---@type table<string, true>
    for _, part in ipairs(doc_parts) do
        local tag = part.header_tag
        if tag then
            err_if_seen_or_append(all_tags, tag, "Duplicate tag " .. tag)
        end
    end

    for _, list in ipairs(obj_lists) do
        for _, obj in ipairs(list) do
            if obj.tag then
                err_if_seen_or_append(all_tags, obj.tag, "Duplicate tag " .. obj.tag)
            end

            if obj.tags_addtl then
                for _, tag_addtl in ipairs(obj.tags_addtl) do
                    err_if_seen_or_append(all_tags, tag_addtl, "Duplicate tag " .. tag_addtl)
                end
            end
        end
    end

    resolve_holistic(obj_lists)
    list_filter_map(doc_parts, function(part)
        return ((not part.objs) or #part.objs > 0) and part or nil
    end)

    local docs_tbl = {} ---@type string[]
    docs_tbl[#docs_tbl + 1] = "*" .. prefix .. ".txt*"
    local toc_tags = list_filter_map_to(doc_parts, function(part)
        if part.header_tag then
            return "|" .. part.header_tag .. "|"
        end
    end)

    docs_tbl[#docs_tbl + 1] = table.concat(toc_tags, "\n")
    -- local vimdoc_intro_path

    for _, part in ipairs(doc_parts) do
        if part.header then
            docs_tbl[#docs_tbl + 1] = part.header
        end

        if part.txt then
            docs_tbl[#docs_tbl + 1] = part.txt
        end

        if part.objs then
            local rendered = render_objs(part.objs)
            docs_tbl[#docs_tbl + 1] = rendered
        end
    end

    local ml = string.format("\n vim:tw=78:ts=8:sw=%d:sts=%d:et:ft=help:norl:\n", INDENT, INDENT)
    docs_tbl[#docs_tbl + 1] = ml
    local docs = table.concat(docs_tbl, "\n\n")
    write_vimdoc(prefix, debug_path, opts.vimdoc_output_path, docs)
end

---@param sources docgen.gen.source.Vimdoc[] Modified in place!
---@return string help_prefix
local function doc_sources_add_names_headers(sources)
    local split_paths = list_filter_map_to(sources, function(source)
        local segments = table_new(4, 0) ---@type string[]
        segments[#segments + 1] = "/" -- Reduce contrivance upstream
        for segment in vim.gsplit(source.path, "/", { plain = true }) do
            if segment ~= "" then
                segments[#segments + 1] = segment
            end
        end

        return segments
    end)

    local prefix_idx = table_common_prefix(split_paths) or 1
    for _, path in pairs(split_paths) do
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

    list_filter_map_two(sources, split_paths, function(source, path)
        source.name = path[#path]
        local tag_str, _ = string.gsub(table.concat(path), "[ \t]", "__")
        source.header_tag = tag_str
        return source
    end)

    return prefix
end

---@param plugin_sources docgen.gen.input.Plugin[]
---@param readme_sources docgen.gen.input.Readme[]
---@param vimdoc_sources docgen.gen.source.Vimdoc[]
---@param opts docgen.gen.Opts
---@return table<string, string>
local function source_text_import(plugin_sources, readme_sources, vimdoc_sources, opts)
    local inputs_vimdoc = list_filter_map_to(vimdoc_sources, function(source)
        return (source.type == "luacats" and source.text == nil) and source.path or nil
    end)

    local inputs_readme = list_filter_map_to(readme_sources, function(source)
        -- TODO: I have no idea if this name works
        return (source.type == "paragraph" and source.text == nil) and source.path or nil
    end)

    local inputs_plugin = list_filter_map_to(plugin_sources, function(source)
        -- TODO: I have no idea if this name works
        return (source.type == "paragraph" and source.text == nil) and source.path or nil
    end)

    local imports_other = { opts.vimdoc_intro_path }
    local inputs = list_chain(inputs_vimdoc, inputs_readme, inputs_plugin, imports_other)
    vim.list.unique(inputs)

    local ok, timed_out, results = file_ops.fs_read_list(inputs)
    if not (ok and results) then
        if timed_out then
            error("Time out while reading file data")
        else
            error(file_ops.fs_read_list_get_errs(results))
        end
    end

    local res_only = {}
    for path, res in pairs(results) do
        res_only[path] = res[2]
    end

    return res_only
end

---@param plugin_sources docgen.gen.input.Plugin[]
---@param readme_sources docgen.gen.input.Readme[]
---@param vimdoc_sources docgen.gen.source.Vimdoc[]
---@param opts docgen.gen.Opts
local function abs_paths_set(plugin_sources, readme_sources, vimdoc_sources, opts)
    for _, source in pairs(plugin_sources) do
        source.path = fs.normalize(vim.call("fnamemodify", source.path, ":p"))
    end

    for _, source in pairs(readme_sources) do
        source.path = fs.normalize(vim.call("fnamemodify", source.path, ":p"))
    end

    for _, source in pairs(vimdoc_sources) do
        source.path = fs.normalize(vim.call("fnamemodify", source.path, ":p"))
    end

    if opts.vimdoc_intro_path then
        opts.vimdoc_intro_path =
            fs.normalize(vim.call("fnamemodify", opts.vimdoc_intro_path, ":p"))
    end
end

---@alias docgen.gen.input.plugin.Type "default_map"|"luacats"|"plug_map"

---@alias docgen.gen.input.readme.Type "keymap"

---@alias docgen.gen.input.vimdoc.Type "keymap"|"luacats"

---@inlinedoc
---@class docgen.gen.input.Plugin
---@field cond? string
---@field path string
---@field text? string
---@field type docgen.gen.input.plugin.Type

---@inlinedoc
---@class docgen.gen.input.Readme
---@field path string
---@field text? string
---@field type docgen.gen.input.readme.Type

---@inlinedoc
---@class docgen.gen.source.Vimdoc
---@field header_tag? string
---@field name? string
---@field path string
---@field text? string
---@field type docgen.gen.input.vimdoc.Type

---@inlinedoc
---@class docgen.gen.Opts
---@field log_level? 0|1
---@field log_path? string
---@field plugin_output_path? string
---@field readme_output_path? string
---@field vimdoc_intro_path? string
---@field vimdoc_output_path? string

--- TODO: docgen.gen.VimdocPart is currently used for vimdoc and Readme. Either specificize or
--- further abstract.

local M = {}

---Main generator function
---@param vimdoc_sources? docgen.gen.source.Vimdoc[][]
---@param readme_sources? docgen.gen.input.Readme[]
---@param plugin_sources? docgen.gen.input.Plugin[]
---@param opts? docgen.gen.Opts
function M.gen_all(vimdoc_sources, readme_sources, plugin_sources, opts)
    opts = opts or {}
    -- TODO: validate inputs

    local debug_path = debug_path_get()
    logger_create(opts.log_level, debug_path, opts.log_path)

    vimdoc_sources = vimdoc_sources or {}
    readme_sources = readme_sources or {}
    plugin_sources = plugin_sources or {}
    abs_paths_set(plugin_sources, readme_sources, vimdoc_sources, opts)

    local imported = source_text_import(plugin_sources, readme_sources, vimdoc_sources, opts)
    local prefix = doc_sources_add_names_headers(vimdoc_sources)

    gen_vimdoc(vimdoc_sources, imported, prefix, debug_path, opts)
    gen_readme(readme_sources, imported, prefix, debug_path, opts)
    gen_plugin(plugin_sources, imported, prefix, debug_path, opts)

    logger_close()
end
-- TODO: There's no fallback or defense in depth here for what happens if certain things drop
-- out or go missing during the process.

return M

#!/usr/bin/env -S nvim -l

local fn = vim.fn
local fs = vim.fs
local uv = vim.uv

local util = require("docgen.util")
local md_to_vimdoc = util.md_to_vimdoc

local str_fmt = string.format

local TEXT_WIDTH = 78
local INDENTATION = 4

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
    local datetime = os.date("%Y-%m-%d %H:%M:%S", sec)
    local fmt_usec = string.format(".%03d", math.floor(usec / 1000))
    local timestamp = datetime .. fmt_usec

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

-------------------------------------------
-- MARK: Other helper data and functions --
-------------------------------------------

local debug_info = debug.getinfo(2, "S")
if not debug_info then
    debug_info = debug.getinfo(1, "S")
end

local debug_source = debug_info.source:gsub("^@", "")
local script_path = fn.fnamemodify(debug_source, ":p:h")

---@alias nvim.gen_vimdoc.HelptagTarget
---| nvim.luacats.parser.obj
---| nvim.luacats.parser.field
---| nvim.luacats.parser.param

--- @param fun nvim.gen_vimdoc.HelptagTarget
--- @return string
local function fn_helptag_fmt_common(fun)
    local fn_sfx = fun.table and "" or "()"
    if fun.classvar then
        return str_fmt("%s:%s%s", fun.classvar, fun.name, fn_sfx)
    end
    if fun.module then
        return str_fmt("%s.%s%s", fun.module, fun.name, fn_sfx)
    end
    return fun.name .. fn_sfx
end

--- @param ty string
--- @param generics table<string,string>
--- @return string
local function replace_generics(ty, generics)
    if ty:sub(-2) == "[]" then
        local ty0 = ty:sub(1, -3)
        if generics[ty0] then
            return generics[ty0] .. "[]"
        end
    elseif ty:sub(-1) == "?" then
        local ty0 = ty:sub(1, -2)
        if generics[ty0] then
            return generics[ty0] .. "?"
        end
    end

    return generics[ty] or ty
end

--- @param name string
local function fmt_field_name(name)
    local name0, opt = name:match("^([^?]*)(%??)$")
    return str_fmt("{%s}%s", name0, opt)
end

--- @param p nvim.luacats.parser.param|nvim.luacats.parser.field
local function should_render_field_or_param(p)
    return not p.nodoc
        and not p.access
        and not util.list_find({ "_", "self" }, p.name)
        and not vim.startswith(p.name, "_")
end

-----------------------------
-- MARK: Section Rendering --
-----------------------------

--- @param section nvim.gen_vimdoc.Section
--- @param add_header? boolean
local function render_section(section, add_header)
    local doc = {} --- @type string[]

    if not section.title then
        error(
            ("section.title is nil, check section_fmt(). section: %s"):format(vim.inspect(section))
        )
    end

    if add_header ~= false then
        vim.list_extend(doc, {
            string.rep("=", TEXT_WIDTH),
            "\n",
            section.title,
            str_fmt("%" .. (TEXT_WIDTH - section.title:len()) .. "s", section.help_tag),
        })
    end

    if next(section.briefs) then
        local briefs_txt = {} --- @type string[]
        for _, b in ipairs(section.briefs) do
            briefs_txt[#briefs_txt + 1] = md_to_vimdoc(b, 0, 0, TEXT_WIDTH)
        end

        local sdoc = "\n\n" .. table.concat(briefs_txt, "\n")
        if sdoc:find("[^%s]") then
            doc[#doc + 1] = sdoc
        end
    end

    if section.classes_txt ~= "" then
        table.insert(doc, "\n\n")
        table.insert(doc, (section.classes_txt:gsub("\n+$", "\n")))
    end

    if section.funs_txt ~= "" then
        table.insert(doc, "\n\n")
        table.insert(doc, section.funs_txt)
    end

    return table.concat(doc)
end

--- @param x string
local function mktitle(x)
    if x == "ui" then
        return "UI"
    end
    return x:sub(1, 1):upper() .. x:sub(2)
end

------------------------------------------------
-- MARK: General Part Rendering Sub-Functions --
------------------------------------------------

--- @class nvim.gen_vimdoc.Section
--- @field name string
--- @field title string
--- @field help_tag string
--- @field funs_txt string
--- @field classes_txt string
--- @field briefs string[]

--- @param filename string
--- @param briefs string[]
--- @param funs_txt string
--- @param classes_txt string
--- @return nvim.gen_vimdoc.Section?
local function make_section(filename, briefs, funs_txt, classes_txt)
    -- filename: e.g., 'autocmd.c'
    -- name: e.g. 'autocmd'
    local name = filename:match("(.*)%.[a-z]+")

    -- Formatted (this is what's going to be written in the vimdoc)
    -- e.g., "Autocmd Functions"
    local sectname = mktitle(name)

    -- TODO: Unsure how to address without config
    -- Probably use @mod tags
    local help_labels = "demo-help-" .. sectname
    if type(help_labels) == "table" then
        help_labels = table.concat(help_labels, "* *")
    end
    local help_tags = "*" .. help_labels .. "*"

    if funs_txt == "" and classes_txt == "" and #briefs == 0 then
        return
    end

    return {
        name = sectname,
        -- TODO: This is a conversion where like, if the name is lsp, then it's turned into
        -- vim.lsp. I'm less sure this is necessary because it seems to be a product of how
        -- Neovim grafts their files together
        title = sectname,
        help_tag = help_tags,
        funs_txt = funs_txt,
        classes_txt = classes_txt,
        briefs = briefs,
    }
end

--- @param ty string
--- @param generics? table<string,string>
--- @param default? string
local function render_type(ty, generics, default)
    ty = ty:gsub("vim%.lsp%.protocol%.Method.[%w.]+", "string")

    if generics then
        ty = replace_generics(ty, generics)
    end
    ty = ty:gsub("%s*|%s*nil", "?")
    ty = ty:gsub("nil%s*|%s*(.*)", "%1?")
    ty = ty:gsub("%s*|%s*", "|")
    if default then
        return str_fmt("(`%s`, default: %s)", ty, default)
    end
    return str_fmt("(`%s`)", ty)
end

--- Gets a field's description and its "(default: …)" value, if any (see `lsp/client.lua` for
--- examples).
---
--- @param desc? string
--- @return string?, string?
local function get_default(desc)
    if not desc then
        return
    end

    local default = desc:match("\n%s*%([dD]efault: ([^)]+)%)")
    if default then
        desc = desc:gsub("\n%s*%([dD]efault: [^)]+%)", "")
    end

    return desc, default
end

--- @param ty string
--- @param classes? table<string,nvim.luacats.parser.obj>
--- @return nvim.luacats.parser.obj?
local function get_class(ty, classes)
    if not classes then
        return
    end

    local cty = ty:gsub("%s*|%s*nil", "?"):gsub("?$", ""):gsub("%[%]$", "")

    return classes[cty]
end

--- @param obj nvim.luacats.parser.param|nvim.luacats.parser.return|nvim.luacats.parser.field
--- @param classes? table<string,nvim.luacats.parser.obj>
local function inline_type(obj, classes)
    local ty = obj.type
    if not ty then
        return
    end

    local cls = get_class(ty, classes)

    if not cls or cls.nodoc then
        return
    end

    if not cls.inlinedoc then
        -- Not inlining so just add a: "See |tag|."
        local tag = str_fmt("|%s|", cls.name)
        if obj.desc and obj.desc:find(tag) then
            -- Tag already there
            return
        end

        -- TODO(lewis6991): Aim to remove this. Need this to prevent dead
        -- references to types defined in runtime/lua/vim/lsp/_meta/protocol.lua
        if not vim.startswith(cls.name, "vim.") then
            return
        end

        obj.desc = obj.desc or ""
        local period = (obj.desc == "" or vim.endswith(obj.desc, ".")) and "" or "."
        obj.desc = obj.desc .. str_fmt("%s See %s.", period, tag)
        return
    end

    local ty_isopt = (ty:match("%?$") or ty:match("%s*|%s*nil")) ~= nil
    local ty_islist = (ty:match("%[%]$")) ~= nil
    ty = ty_isopt and "table?" or ty_islist and "table[]" or "table"

    local desc = obj.desc or ""
    if cls.desc then
        desc = desc .. cls.desc
    elseif desc == "" then
        if ty_islist then
            desc = desc .. "A list of objects with the following fields:"
        elseif cls.parent then
            desc = desc .. str_fmt("Extends |%s| with the additional fields:", cls.parent)
        else
            desc = desc .. "A table with the following fields:"
        end
    end

    local desc_append = {}
    for _, f in ipairs(cls.fields) do
        if not f.access then
            local fdesc, default = get_default(f.desc)
            local fty = render_type(f.type, nil, default)
            local fnm = fmt_field_name(f.name)
            table.insert(desc_append, table.concat({ "-", fnm, fty, fdesc }, " "))
        end
    end

    desc = desc .. "\n" .. table.concat(desc_append, "\n")
    obj.type = ty
    obj.desc = desc
end

--- @param xs (nvim.luacats.parser.param|nvim.luacats.parser.field)[]
--- @param generics? table<string,string>
--- @param classes? table<string,nvim.luacats.parser.obj>
local function render_fields_or_params(xs, generics, classes)
    local ret = {} --- @type string[]

    xs = vim.tbl_filter(should_render_field_or_param, xs)

    local indent = 0
    for _, p in ipairs(xs) do
        if p.type or p.desc then
            indent = math.max(indent, #p.name + 3)
        end
    end

    for _, p in ipairs(xs) do
        local pdesc, default = get_default(p.desc)
        p.desc = pdesc

        inline_type(p, classes)
        -- TODO: Hacky assert
        local nm, ty = assert(p.name), p.type

        local desc = p.classvar and str_fmt("See |%s|.", fn_helptag_fmt_common(p)) or p.desc

        local fnm = p.kind == "operator" and str_fmt("op(%s)", nm) or fmt_field_name(nm)
        local pnm = str_fmt("      • %-" .. indent .. "s", fnm)

        if ty then
            local pty = render_type(ty, generics, default)

            if desc then
                table.insert(ret, pnm)
                if #pty > TEXT_WIDTH - indent then
                    vim.list_extend(ret, { " ", pty, "\n" })
                    table.insert(ret, md_to_vimdoc(desc, 9 + indent, 9 + indent, TEXT_WIDTH, true))
                else
                    desc = str_fmt("%s %s", pty, desc)
                    table.insert(ret, md_to_vimdoc(desc, 1, 9 + indent, TEXT_WIDTH, true))
                end
            else
                table.insert(ret, str_fmt("%s %s\n", pnm, pty))
            end
        else
            if desc then
                table.insert(ret, pnm)
                table.insert(ret, md_to_vimdoc(desc, 1, 9 + indent, TEXT_WIDTH, true))
            end
        end
    end

    return table.concat(ret)
end

---------------------------
-- MARK: Class Rendering --
---------------------------

--- @param class nvim.luacats.parser.obj
--- @param classes table<string,nvim.luacats.parser.obj>
local function render_class(class, classes)
    if class.access or class.nodoc or class.inlinedoc then
        return
    end

    local ret = {} --- @type string[]

    table.insert(ret, str_fmt("*%s*\n", class.name))

    if class.parent then
        local txt = str_fmt("Extends: |%s|", class.parent)
        table.insert(ret, md_to_vimdoc(txt, INDENTATION, INDENTATION, TEXT_WIDTH))
        table.insert(ret, "\n")
    end

    if class.desc then
        table.insert(ret, md_to_vimdoc(class.desc, INDENTATION, INDENTATION, TEXT_WIDTH))
    end

    local fields_txt = render_fields_or_params(class.fields, nil, classes)
    if not fields_txt:match("^%s*$") then
        table.insert(ret, "\n    Fields: ~\n")
        table.insert(ret, fields_txt)
    end

    table.insert(ret, "\n")
    return table.concat(ret)
end

--- @param classes table<string,nvim.luacats.parser.obj>
local function render_classes(classes)
    local ret = {} --- @type string[]

    for _, class in vim.spairs(classes) do
        ret[#ret + 1] = render_class(class, classes)
    end

    return table.concat(ret)
end

------------------------------
-- MARK: Function Rendering --
------------------------------

--- @param returns nvim.luacats.parser.return[]
--- @param generics? table<string,string>
--- @param classes? table<string,nvim.luacats.parser.obj>
--- @return string?
local function render_returns(returns, generics, classes)
    local ret = {} --- @type string[]

    if #returns == 1 and returns[1].type == "nil" then
        return
    end

    if #returns > 1 then
        table.insert(ret, "    Return (multiple): ~\n")
    elseif #returns == 1 and next(returns[1]) then
        table.insert(ret, "    Return: ~\n")
    end

    for _, p in ipairs(returns) do
        inline_type(p, classes)
        local rnm, ty, desc = p.name, p.type, p.desc

        local blk = {} --- @type string[]
        if ty then
            blk[#blk + 1] = render_type(ty, generics)
        end
        blk[#blk + 1] = rnm
        blk[#blk + 1] = desc

        ret[#ret + 1] = md_to_vimdoc(table.concat(blk, " "), 8, 8, TEXT_WIDTH, true)
    end

    return table.concat(ret)
end

--- @param fun nvim.luacats.parser.obj
local function render_fun_header(fun)
    local ret = {} --- @type string[]

    local args = {} --- @type string[]
    for _, p in ipairs(fun.params or {}) do
        if p.name ~= "self" then
            args[#args + 1] = fmt_field_name(p.name)
        end
    end

    local nm = fun.name
    if fun.classvar then
        nm = str_fmt("%s:%s", fun.classvar, nm)
    end
    if nm == "vim.bo" then
        nm = "vim.bo[{bufnr}]"
    end
    if nm == "vim.wo" then
        nm = "vim.wo[{winid}][{bufnr}]"
    end

    local proto = fun.table and nm or nm .. "(" .. table.concat(args, ", ") .. ")"

    local tag = "*" .. fn_helptag_fmt_common(fun) .. "*"

    if #proto + #tag > TEXT_WIDTH - 8 then
        table.insert(ret, str_fmt("%78s\n", tag))
        local name, pargs = proto:match("([^(]+%()(.*)")
        table.insert(ret, name)
        table.insert(ret, util.wrap(pargs, 0, #name, TEXT_WIDTH))
    else
        local pad = TEXT_WIDTH - #proto - #tag
        table.insert(ret, proto .. string.rep(" ", pad) .. tag)
    end

    return table.concat(ret)
end

--- @param fun nvim.luacats.parser.obj
--- @param classes table<string,nvim.luacats.parser.obj>
--- @return string|nil
local function render_fun(fun, classes)
    if fun.access or fun.deprecated or fun.nodoc then
        return
    end

    if not fun.name then
        error(("fun.name is nil, check fn_xform(). fun: %s"):format(vim.inspect(fun)))
    end

    if vim.startswith(fun.name, "_") or fun.name:find("[:.]_") then
        return
    end

    local ret = {} --- @type string[]

    table.insert(ret, render_fun_header(fun))
    table.insert(ret, "\n")

    -- TODO: Feels arbitrary to have here now that it's not tied to Nvim version validation.
    -- Would need to check Nvim's docs + luacats syntax, but I think this is a case where the
    -- user just puts a number in their annotation and the literal is used. I'm not sure how
    -- you would get to an annotation map here.
    if fun.since then
        table.insert(fun.attrs, str_fmt("Since: %s", fun.since))
    end

    if fun.desc then
        table.insert(ret, md_to_vimdoc(fun.desc, INDENTATION, INDENTATION, TEXT_WIDTH))
    end

    if fun.notes then
        table.insert(ret, "\n    Note: ~\n")
        for _, p in ipairs(fun.notes) do
            table.insert(ret, "      • " .. md_to_vimdoc(p.desc, 0, 8, TEXT_WIDTH, true))
        end
    end

    if fun.attrs then
        table.insert(ret, "\n    Attributes: ~\n")
        for _, attr in ipairs(fun.attrs) do
            local attr_str = ({
                textlock = "not allowed when |textlock| is active or in the |cmdwin|",
                textlock_allow_cmdwin = "not allowed when |textlock| is active",
                fast = "|api-fast|",
                remote_only = "|RPC| only",
                lua_only = "Lua |vim.api| only",
            })[attr] or attr
            table.insert(ret, str_fmt("        %s\n", attr_str))
        end
    end

    if fun.params and #fun.params > 0 then
        local param_txt = render_fields_or_params(fun.params, fun.generics, classes)
        if not param_txt:match("^%s*$") then
            table.insert(ret, "\n    Parameters: ~\n")
            ret[#ret + 1] = param_txt
        end
    end

    if fun.overloads then
        table.insert(ret, "\n    Overloads: ~\n")
        for _, p in ipairs(fun.overloads) do
            table.insert(ret, str_fmt("      • `%s`\n", p))
        end
    end

    if fun.returns then
        local txt = render_returns(fun.returns, fun.generics, classes)
        if txt and not txt:match("^%s*$") then
            table.insert(ret, "\n")
            ret[#ret + 1] = txt
        end
    end

    if fun.see then
        table.insert(ret, "\n    See also: ~\n")
        for _, p in ipairs(fun.see) do
            table.insert(ret, "      • " .. md_to_vimdoc(p.desc, 0, 8, TEXT_WIDTH, true))
        end
    end

    table.insert(ret, "\n")
    return table.concat(ret)
end

--- @param funs nvim.luacats.parser.obj[]
--- @param classes table<string,nvim.luacats.parser.obj>
local function render_funs(funs, classes)
    local ret = {} --- @type string[]
    for _, f in ipairs(funs) do
        ret[#ret + 1] = render_fun(f, classes)
    end

    -- Sort via prototype. Experimental API functions ("nvim__") sort last.
    table.sort(ret, function(a, b)
        local a1 = ("\n" .. a):match("\n[a-zA-Z_][^\n]+\n")
        local b1 = ("\n" .. b):match("\n[a-zA-Z_][^\n]+\n")

        local a1__ = a1:find("^%s*nvim__") and 1 or 0
        local b1__ = b1:find("^%s*nvim__") and 1 or 0
        if a1__ ~= b1__ then
            return a1__ < b1__
        end

        return a1:lower() < b1:lower()
    end)
    -- TODO: yeet this when we have lnum based rendering

    return table.concat(ret)
end
-- TODO: There's some tweaking the cfg does with the functions using the fn_xform key. I'm not
-- sure what the generalized usecase here is

--- @param classes table<string,nvim.luacats.parser.obj>
--- @return string?
local function find_module_class(classes, modvar)
    for nm, cls in pairs(classes) do
        local _, field = next(cls.fields or {})
        if cls.desc and field and field.classvar == modvar then
            return nm
        end
    end
end

-----------------------------------
-- MARK: Main rendering function --
-----------------------------------

---@param inputs string[]
---@param output_path string
local function render_docs(inputs, output_path)
    local sections = {} --- @type table<string,nvim.gen_vimdoc.Section>

    --- @type table<string,[table<string,nvim.luacats.parser.obj>, nvim.luacats.parser.obj[], string[]]>
    local file_results = {}

    --- @type table<string,nvim.luacats.parser.obj>
    local all_classes = {}

    local parser = require("docgen.luacats_parser").parse
    for _, f in vim.spairs(inputs) do
        local classes, funs, briefs = parser(f)
        file_results[f] = { classes, funs, briefs }
        all_classes = vim.tbl_extend("error", all_classes, classes)
    end

    for f, r in vim.spairs(file_results) do
        local classes, funs, briefs = r[1], r[2], r[3]

        -- TODO: Does the luacats parser convert everything to M? This is fine but need to confirm.
        local mod_cls_nm = find_module_class(classes, "M")
        if mod_cls_nm then
            local mod_cls = classes[mod_cls_nm]
            classes[mod_cls_nm] = nil
            -- If the module documentation is present, add it to the briefs
            -- so it appears at the top of the section.
            briefs[#briefs + 1] = mod_cls.desc
        end

        log("    Processing file:" .. f, 0)

        -- TODO: A note here is, even if we do an ordered list, we want to see if it's still
        -- possible to do all of the function rendering then all of the class rendering, since this
        -- promotes cache locality.
        -- I cannot help but think that "the way" here is to build a giant SoA that contains
        -- everything you need, and that includes pre-merging by file. Although pre-merging by
        -- file immediately creates the issue of class lookups crossing over. So maybe that doesn't
        -- get to work out. But you could be able to iteration functions in order or classes in
        -- order or get them by name. And then the like, all-inclusive, ordered iteration with
        -- mixed types should be saved to the end. Would be even better if they could all be
        -- saved as sections, meaning they're all the same datatype
        local f_base = vim.fs.basename(f)
        sections[f_base] =
            make_section(f_base, briefs, render_funs(funs, all_classes), render_classes(classes))
    end

    local docs = {} --- @type string[]
    for _, section in pairs(sections) do
        print(str_fmt("    Rendering section: '%s'", section.title))
        docs[#docs + 1] = render_section(section, true)
    end

    table.insert(
        docs,
        str_fmt(" vim:tw=78:ts=8:sw=%d:sts=%d:et:ft=help:norl:\n", INDENTATION, INDENTATION)
    )

    log("Writing output", 1)
    local fp = assert(io.open(output_path, "w"))
    fp:write(table.concat(docs, "\n"))
    fp:close()
end

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

---@param inputs string[]
---@param output string?
---@param level integer?
---@param log_path string?
function M.generate(inputs, output, level, log_path)
    validate_target_inputs(inputs, output, level, log_path)

    setup_log(level, log_path)
    validate_input_files(inputs)
    local output_path = resolve_output_path(output, DEFAULT_OUTPUT_FILE)

    render_docs(inputs, output_path)
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

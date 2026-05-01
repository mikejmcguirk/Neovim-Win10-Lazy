local util = require("docgen.util")
local md_to_vimdoc = util.md_to_vimdoc

local str_fmt = string.format

local TEXT_WIDTH = 78
local INDENT = 4

-- This module handles two concerns. The first is unpacking the parsed objects into what will be
-- rendered. The second is the actual rendering into vimdoc.
--
-- To help distinguish these concerns, functions that return unpacked data should return string[],
-- and functions that return rendered text should return strings.
--
-- Additionally, rendering should be delayed as much down the pipeline as possible.
-- Conceptually, if text is rendered upstream, it might be harder to reason about what the
-- rendered text is and how it fits into the current procedure.
-- Technically, it hurts flexibility if a function creates or relies on rendering in different
-- parts of the callstack.

-------------------------------------------
-- MARK: Other helper data and functions --
-------------------------------------------

--- @param fun docgen.DocItem|docgen.ParserObj
--- @return string
local function fmt_fun_as_helptag(fun)
    if fun.classvar then
        return str_fmt("%s:%s%s", fun.classvar, fun.name, "()")
    end

    if fun.module then
        return str_fmt("%s.%s", fun.module, fun.name)
    end

    return fun.name .. "()"
end
-- TODO: Does the module name need to pipe through here?

--- @param typ string
--- @param generics table<string,string>
--- @return string
local function replace_generics(typ, generics)
    if typ:sub(-2) == "[]" then
        local list_type = typ:sub(1, -3)
        if generics[list_type] then
            return generics[list_type] .. "[]"
        end
    elseif typ:sub(-1) == "?" then
        local typ_prefix = typ:sub(1, -2)
        if generics[typ_prefix] then
            return generics[typ_prefix] .. "?"
        end
    end

    return generics[typ] or typ
end

--- @param name string
--- @return string
local function _fmt_field_name(name)
    local name0, opt = name:match("^([^?]*)(%??)$")
    return str_fmt("{%s}%s", name0, opt)
end

--- @param p nvim.luacats.parser.param|nvim.luacats.parser.field
local function _should_render_field_or_param(p)
    return not p.nodoc
        and not p.access
        and not util.list_find({ "_", "self" }, p.name)
        and not vim.startswith(p.name, "_")
end
-- TODO: I'm not sure if you keep this:
-- - Self might be useful for class fields with self functions, so maybe that's fine
-- underscore fields/params do... exist I'm not sure why you'd get rid of them
-- - Underscore fields should be marked private/protected/package, which should also cause them
-- to fail to show up. Otherwise, Lua_Ls will display them so they should also be in the docgen.

-----------------------------
-- MARK: Section Rendering --
-----------------------------

--- @param section nvim.gen_vimdoc.Section
--- @param add_header? boolean
local function _render_section(section, add_header)
    local ret = {} --- @type string[]

    if not section.title then
        local fmt_str = "section.title is nil, check section_fmt(). section: %s"
        error(string.format(fmt_str, vim.inspect(section)))
    end

    if add_header ~= false then
        local border = string.rep("=", TEXT_WIDTH) .. "\n"
        ret[#ret + 1] = border
        local rem_whitespace = TEXT_WIDTH - section.title:len()
        local help_tag = str_fmt("%" .. rem_whitespace .. "s", section.help_tag)
        vim.list_extend(ret, { section.title, help_tag })
    end

    if next(section.briefs) then
        local briefs_txt = {} --- @type string[]
        for _, b in ipairs(section.briefs) do
            briefs_txt[#briefs_txt + 1] = md_to_vimdoc(b, 0, 0, TEXT_WIDTH)
        end

        local sdoc = "\n\n" .. table.concat(briefs_txt, "\n")
        if sdoc:find("[^%s]") then
            ret[#ret + 1] = sdoc
        end
    end

    if section.classes_txt ~= "" then
        table.insert(ret, "\n\n")
        table.insert(ret, (section.classes_txt:gsub("\n+$", "\n")))
    end

    if section.funs_txt ~= "" then
        table.insert(ret, "\n\n")
        table.insert(ret, section.funs_txt)
    end

    return table.concat(ret)
end

--- @param x string
local function _mktitle(x)
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
local function _make_section(filename, briefs, funs_txt, classes_txt)
    if funs_txt == "" and classes_txt == "" and #briefs == 0 then
        return
    end

    -- filename: e.g., 'autocmd.c'
    -- name: e.g. 'autocmd'
    local name = filename:match("(.*)%.[a-z]+")

    -- Formatted (this is what's going to be written in the vimdoc)
    -- e.g., "Autocmd Functions"
    local sectname = _mktitle(name)

    -- TODO: Unsure how to address without config
    -- Probably use @mod tags
    local help_labels = "demo-help-" .. sectname
    if type(help_labels) == "table" then
        help_labels = table.concat(help_labels, "* *")
    end

    local help_tags = "*" .. help_labels .. "*"

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

--- @param typ string
--- @param generics? table<string,string>
--- @param default? string
--- @param fmt_nil? boolean (default: `true`)
local function render_type(typ, generics, default, fmt_nil)
    if generics then
        typ = replace_generics(typ, generics)
    end

    typ = typ:gsub("%s*|%s*", "|")
    if fmt_nil ~= false then
        typ = typ:gsub("|nil", "?")
        typ = typ:gsub("nil|(.*)", "%1?")
    end

    if not default then
        return str_fmt("(`%s`)", typ)
    end

    return str_fmt("(`%s`, default: %s)", typ, default)
end

--- Gets a field's description and its "(default: …)" value, if any (see `lsp/client.lua` for
--- examples).
---
--- @param desc? string
--- @return string?, string?
local function _get_default(desc)
    if not desc then
        return
    end

    local default = desc:match("\n%s*%([dD]efault: ([^)]+)%)")
    if default then
        desc = desc:gsub("\n%s*%([dD]efault: [^)]+%)", "")
    end

    return desc, default
end
-- TODO: Does this just not work if default is on the same line as the declaration?

--- @param ty string
--- @param classes? table<string,docgen.ParserObj>
--- @return docgen.ParserObj?
local function _get_class(ty, classes)
    if not classes then
        return
    end

    local cty = ty:gsub("%s*|%s*nil", "?"):gsub("?$", ""):gsub("%[%]$", "")

    return classes[cty]
end

--- @param obj docgen.DocItem
--- @param classes? table<string,docgen.ParserObj>
local function _inline_type(obj, classes)
    local typ = obj.type
    if not typ then
        return
    end

    local cls = _get_class(typ, classes)

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

        obj.desc = obj.desc or ""
        local period = (obj.desc == "" or vim.endswith(obj.desc, ".")) and "" or "."
        obj.desc = obj.desc .. str_fmt("%s See %s.", period, tag)
        return
    end

    local typ_isopt = (typ:match("%?$") or typ:match("%s*|%s*nil")) ~= nil
    local typ_islist = (typ:match("%[%]$")) ~= nil
    typ = typ_isopt and "table?" or typ_islist and "table[]" or "table"

    local desc = obj.desc or ""
    if cls.desc then
        desc = desc .. cls.desc
    elseif desc == "" then
        if typ_islist then
            desc = desc .. "A list of objects with the following fields:"
        elseif cls.parent then
            desc = desc .. str_fmt("Extends |%s| with the additional fields:", cls.parent)
        else
            desc = desc .. "A table with the following fields:"
        end
    end

    local desc_append = {}
    for _, field in ipairs(cls.fields) do
        if not field.access then
            local fdesc, default = _get_default(field.desc)
            local fty = render_type(field.type, nil, default)
            local fnm = _fmt_field_name(field.name)
            table.insert(desc_append, table.concat({ "-", fnm, fty, fdesc }, " "))
        end
    end

    desc = desc .. "\n" .. table.concat(desc_append, "\n")
    obj.type = typ
    obj.desc = desc
end

--- @param xs docgen.DocItem[]
--- @param generics? table<string,string>
--- @param classes? table<string,docgen.ParserObj>
local function _render_fields_or_params(xs, generics, classes)
    local ret = {} --- @type string[]

    xs = vim.tbl_filter(_should_render_field_or_param, xs)

    local indent = 0
    for _, p in ipairs(xs) do
        if p.type or p.desc then
            indent = math.max(indent, #p.name + 3)
        end
    end

    for _, p in ipairs(xs) do
        local pdesc, default = _get_default(p.desc)
        p.desc = pdesc

        _inline_type(p, classes)
        -- TODO: Hacky assert
        local nm, typ = assert(p.name), p.type

        local desc = p.classvar and str_fmt("See |%s|.", fmt_fun_as_helptag(p)) or p.desc

        local field_name = p.kind == "operator" and str_fmt("op(%s)", nm) or _fmt_field_name(nm)
        local fname_bullet = str_fmt("      • %-" .. indent .. "s", field_name)

        if typ then
            local pty = render_type(typ, generics, default)

            if desc then
                table.insert(ret, fname_bullet)
                if #pty > TEXT_WIDTH - indent then
                    vim.list_extend(ret, { " ", pty, "\n" })
                    table.insert(ret, md_to_vimdoc(desc, 9 + indent, 9 + indent, TEXT_WIDTH, true))
                else
                    desc = str_fmt("%s %s", pty, desc)
                    table.insert(ret, md_to_vimdoc(desc, 1, 9 + indent, TEXT_WIDTH, true))
                end
            else
                table.insert(ret, str_fmt("%s %s\n", fname_bullet, pty))
            end
        else
            if desc then
                table.insert(ret, fname_bullet)
                table.insert(ret, md_to_vimdoc(desc, 1, 9 + indent, TEXT_WIDTH, true))
            end
        end
    end

    return table.concat(ret)
end
-- TODO: This is used for functions and classes, which means we want render_type to perform
-- the question mark replacement only on functions. This function needs to be able to handle that,
-- either as a param or some kind of logical check.

---------------------------
-- MARK: Class Rendering --
---------------------------

--- @param class docgen.ParserObj
--- @param classes table<string,docgen.ParserObj>
--- @return string|nil
local function _render_class(class, classes)
    if class.access or class.nodoc or class.inlinedoc then
        return
    end

    local ret = {} --- @type string[]

    table.insert(ret, str_fmt("*%s*\n", class.name))

    if class.parent then
        local txt = str_fmt("Extends: |%s|", class.parent)
        table.insert(ret, md_to_vimdoc(txt, INDENT, INDENT, TEXT_WIDTH))
        table.insert(ret, "\n")
    end

    if class.desc then
        table.insert(ret, md_to_vimdoc(class.desc, INDENT, INDENT, TEXT_WIDTH))
    end

    local fields_txt = _render_fields_or_params(class.fields, nil, classes)
    if not fields_txt:match("^%s*$") then
        table.insert(ret, "\n    Fields: ~\n")
        table.insert(ret, fields_txt)
    end

    table.insert(ret, "\n")
    return table.concat(ret)
end

--- @param classes table<string,docgen.ParserObj>
local function _render_classes(classes)
    local ret = {} --- @type string[]

    for _, class in vim.spairs(classes) do
        ret[#ret + 1] = _render_class(class, classes)
    end

    return table.concat(ret)
end

------------------------------
-- MARK: Function Rendering --
------------------------------

--- @param fun docgen.ParserObj
--- @return boolean
local function should_render_fun(fun)
    if fun.access or fun.deprecated or fun.nodoc then
        return false
    end

    local name = fun.name
    if not name then
        local fmt_str = "fun.name is nil, check fn_xform(). fun: %s"
        error(string.format(fmt_str, vim.inspect(fun)))
    end

    if string.byte(name, 1) == 95 or string.find(name, "[:.]_") then
        return false
    end

    return true
end
-- TODO: Access should just always be present no? If you're not familiar with the code, the nil
-- check here is awkward. The parser obj should have an is_public() function or is_restricted()
-- function

--- @param fun docgen.ParserObj
--- @return string[]|nil
local function get_params(fun)
    local params = fun.params
    if not params then
        return nil
    end

    local args = {} ---@type string[]
    local len_params = #params
    for i = 1, len_params do
        local param = params[i]
        if param.name ~= "self" then
            args[#args + 1] = _fmt_field_name(param.name)
        end
    end

    return args
end

--- Builds the function header as lines.
--- Constructs from semantic parts (name + param list) instead of building a full string then
--- re-parsing it with match/sub. This eliminates the ugly wrapping case you noted
--- (`function(\n{param}, {param})`).
--- @param fun docgen.ParserObj
--- @return string[]
local function create_fun_header(fun)
    local name = fun.classvar and string.format("%s:%s", fun.classvar, fun.name) or fun.name
    local param_list = get_params(fun)
    local param_str = param_list and table.concat(param_list, ", ") or ""
    local proto_len = #name + #param_str + 2 -- Add two for parens

    local tag = "*" .. fmt_fun_as_helptag(fun) .. "*"
    local len_tag = #tag
    if proto_len + len_tag <= TEXT_WIDTH - 8 then
        local full_proto = string.format("%s(%s)", name, param_str)
        local pad = TEXT_WIDTH - #full_proto - len_tag
        return { full_proto .. string.rep(" ", pad) .. tag }
    end

    local lines = { string.format("%78s", tag) }
    if param_list and #param_list > 0 then
        local wrapped = util.wrap(param_str, 0, #name + 1, TEXT_WIDTH)
        lines[#lines + 1] = name .. "(" .. wrapped .. ")"
    else
        lines[#lines + 1] = name .. "()"
    end

    return lines
end

--- @param returns docgen.DocItem[]
--- @param generics? table<string,string>
--- @param classes? table<string,docgen.ParserObj>
--- @return string[]?
local function _render_returns(returns, generics, classes)
    if (not returns) or (#returns == 1 and returns[1].type == "nil") then
        return nil
    end

    local ret = {} --- @type string[]
    ret[#ret + 1] = #returns > 1 and " Returns (multiple): ~" or " Returns: ~"

    for _, p in ipairs(returns) do
        _inline_type(p, classes)
        local val = {}
        if p.type then
            val[#val + 1] = render_type(p.type, generics)
        end

        if p.name then
            val[#val + 1] = p.name
        end

        if p.desc then
            val[#val + 1] = p.desc
        end

        local line = md_to_vimdoc(table.concat(val, " "), 8, 8, TEXT_WIDTH, true)
        ret[#ret + 1] = line
    end

    return ret
end

---@param fun docgen.ParserObj
---@param ret string[]
local function _add_notes(fun, ret)
    if not fun.notes then
        return
    end
    ret[#ret + 1] = "\n Note: ~"
    for _, note in ipairs(fun.notes) do
        local vimdoc = md_to_vimdoc(note.desc, 0, 8, TEXT_WIDTH, true)
        ret[#ret + 1] = " • " .. vimdoc
    end
end

--- @param fun docgen.ParserObj
--- @param classes table<string,docgen.ParserObj>
--- @return string[]?
local function _render_fun(fun, classes)
    if not should_render_fun(fun) then
        return nil
    end

    local ret = {} ---@type string[]

    vim.list_extend(ret, create_fun_header(fun))
    ret[#ret + 1] = ""

    if fun.since then
        fun.attrs = fun.attrs or {}
        fun.attrs[#fun.attrs + 1] = string.format("Since: %s", fun.since)
    end

    if fun.desc then
        local desc = md_to_vimdoc(fun.desc, INDENT, INDENT, TEXT_WIDTH)
        ret[#ret + 1] = desc
    end

    _add_notes(fun, ret)

    if fun.params and #fun.params > 0 then
        local param_txt = _render_fields_or_params(fun.params, fun.generics, classes)
        if not param_txt:match("^%s*$") then
            ret[#ret + 1] = string.rep(" ", INDENT) .. "Parameters: ~"
            ret[#ret + 1] = param_txt
        end
    end

    if fun.overloads then
        ret[#ret + 1] = "\n Overloads: ~"
        for _, p in ipairs(fun.overloads) do
            ret[#ret + 1] = string.format(" • `%s`", p)
        end
    end

    if fun.returns then
        local returns_lines = _render_returns(fun.returns, fun.generics, classes)
        if returns_lines and #returns_lines > 0 then
            ret[#ret + 1] = ""
            vim.list_extend(ret, returns_lines)
        end
    end

    if fun.see then
        ret[#ret + 1] = "\n See also: ~"
        for _, p in ipairs(fun.see) do
            local see_line = md_to_vimdoc(p.desc, 0, 8, TEXT_WIDTH, true)
            ret[#ret + 1] = " • " .. see_line
        end
    end

    ret[#ret + 1] = ""
    return ret
end

--- @param funs docgen.ParserObj[]
--- @param classes table<string,docgen.ParserObj>
--- @return string
local function _render_funs(funs, classes)
    table.sort(funs, function(a, b)
        local key_a = a.classvar and (a.classvar .. ":" .. a.name) or a.name
        local key_b = b.classvar and (b.classvar .. ":" .. b.name) or b.name
        return key_a:lower() < key_b:lower()
    end)

    local all_lines = {} --- @type string[]
    local len_funs = #funs
    for i = 1, len_funs do
        local fun = funs[i]
        local fun_lines = _render_fun(fun, classes)
        if fun_lines then
            vim.list_extend(all_lines, fun_lines)
        end
    end

    return table.concat(all_lines, "\n")
end

-----------------------------------
-- MARK: Main rendering function --
-----------------------------------

--- @param classes table<string,docgen.ParserObj>
--- @return string?
local function _find_module_class(classes, modvar)
    for nm, cls in pairs(classes) do
        local _, field = next(cls.fields or {})
        if cls.desc and field and field.classvar == modvar then
            return nm
        end
    end
end

local M = {}

---@param inputs string[]
---@param output_path string
function M._render_docs(inputs, output_path)
    local sections = {} --- @type table<string,nvim.gen_vimdoc.Section>

    --- @type table<string,[table<string,docgen.ParserObj>, docgen.ParserObj[], string[]]>
    local file_results = {}

    --- @type table<string,docgen.ParserObj>
    local all_classes = {}

    local parse = require("docgen.luacats_parser").parse
    for _, input in vim.spairs(inputs) do
        local classes, funs, briefs = parse(input)
        file_results[input] = { classes, funs, briefs }
        all_classes = vim.tbl_extend("error", all_classes, classes)
    end

    for file, result in vim.spairs(file_results) do
        local classes, funs, briefs = result[1], result[2], result[3]

        -- TODO: Does the luacats parser convert everything to M? This is fine but need to confirm.
        local mod_cls_nm = _find_module_class(classes, "M")
        if mod_cls_nm then
            local mod_cls = classes[mod_cls_nm]
            classes[mod_cls_nm] = nil
            -- If the module documentation is present, add it to the briefs
            -- so it appears at the top of the section.
            briefs[#briefs + 1] = mod_cls.desc
        end

        print("    Processing file:" .. file, 0)

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
        local basename = vim.fs.basename(file)
        -- TODO: Dont' use this structure. In part because we want to do ordered docs, but also
        -- because we aren't building the data in steps.
        -- TODO: Briefs should be turned into strings maybe here for consistency. But since we
        -- do kinda want them to be lines[] maybe that's fine.
        -- Or are they already concated in obj?

        local funs_txt = _render_funs(funs, all_classes)
        local classes_txt = _render_classes(classes)
        sections[basename] = _make_section(basename, briefs, funs_txt, classes_txt)
    end

    local docs = {} --- @type string[]
    for _, section in pairs(sections) do
        print(str_fmt("    Rendering section: '%s'", section.title))
        docs[#docs + 1] = _render_section(section, true)
    end

    local ml = str_fmt(" vim:tw=78:ts=8:sw=%d:sts=%d:et:ft=help:norl:\n", INDENT, INDENT)
    table.insert(docs, ml)

    print("Writing output")
    local fp = assert(io.open(output_path, "w"))
    fp:write(table.concat(docs, "\n"))
    fp:close()
end

return M

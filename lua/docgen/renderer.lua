local util = require("docgen.util")
local md_to_vimdoc = util.md_to_vimdoc

local str_fmt = string.format

local TEXT_WIDTH = 78
local INDENT = 4

-------------------------------------------
-- MARK: Other helper data and functions --
-------------------------------------------

--- @param fun docgen.DocItem|docgen.ParserObj
--- @return string
local function fn_helptag_fmt_common(fun)
    local fn_sfx = "()"
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
--- @return string
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
local function render_section(section, add_header)
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
    if funs_txt == "" and classes_txt == "" and #briefs == 0 then
        return
    end

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
--- @param classes? table<string,docgen.ParserObj>
--- @return docgen.ParserObj?
local function get_class(ty, classes)
    if not classes then
        return
    end

    local cty = ty:gsub("%s*|%s*nil", "?"):gsub("?$", ""):gsub("%[%]$", "")

    return classes[cty]
end

--- @param obj docgen.DocItem
--- @param classes? table<string,docgen.ParserObj>
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

--- @param xs docgen.DocItem[]
--- @param generics? table<string,string>
--- @param classes? table<string,docgen.ParserObj>
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

--- @param class docgen.ParserObj
--- @param classes table<string,docgen.ParserObj>
--- @return string|nil
local function render_class(class, classes)
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

    local fields_txt = render_fields_or_params(class.fields, nil, classes)
    if not fields_txt:match("^%s*$") then
        table.insert(ret, "\n    Fields: ~\n")
        table.insert(ret, fields_txt)
    end

    table.insert(ret, "\n")
    return table.concat(ret)
end

--- @param classes table<string,docgen.ParserObj>
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

--- @param returns docgen.DocItem[]
--- @param generics? table<string,string>
--- @param classes? table<string,docgen.ParserObj>
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

---@param ret string[]
---@param fun docgen.ParserObj
local function add_notes(fun, ret)
    if not fun.notes then
        return
    end

    ret[#ret + 1] = "\n    Note: ~\n"
    local notes = assert(fun.notes)
    local len_notes = #notes
    for i = 1, len_notes do
        local vimdoc = md_to_vimdoc(notes[i].desc, 0, 8, TEXT_WIDTH, true)
        ret[#ret + 1] = "      • " .. vimdoc
    end
end

--- @param fun docgen.ParserObj
--- @return boolean
local function should_render_fun(fun)
    if fun.access or fun.deprecated or fun.nodoc then
        return false
    end

    if not fun.name then
        error(("fun.name is nil, check fn_xform(). fun: %s"):format(vim.inspect(fun)))
    end

    if vim.startswith(fun.name, "_") or fun.name:find("[:.]_") then
        return false
    end

    return true
end

--- @param fun docgen.ParserObj
--- @return string
local function get_params(fun)
    local params = fun.params
    if not params then
        return ""
    end

    local args = {} ---@type string[]
    local len_params = #params
    for i = 1, len_params do
        local param = params[i]
        if param.name ~= "self" then
            args[#args + 1] = fmt_field_name(param.name)
        end
    end

    return table.concat(args, ", ")
end
-- TODO: This is not great because, as we see below, if the params need to be wrapped, they are
-- then re-extracted from the header in order to be formatted. So what this should be doing is
-- returning a list of params that can then be put together into the header later.

--- @param fun docgen.ParserObj
--- @return string
local function render_fun_header(fun)
    local ret = {} ---@type string[]

    local params = get_params(fun)
    local nm = fun.name
    if fun.classvar then
        nm = str_fmt("%s:%s", fun.classvar, nm)
    end

    local proto = nm .. "(" .. params .. ")"
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

--- @param fun docgen.ParserObj
--- @param classes table<string,docgen.ParserObj>
--- @return string|nil
local function render_fun(fun, classes)
    if not should_render_fun(fun) then
        return nil
    end

    local ret = {} ---@type string[]
    ret[#ret + 1] = render_fun_header(fun)
    ret[#ret + 1] = "\n"

    if fun.since then
        fun.attrs = fun.attrs or {}
        fun.attrs[#fun.attrs + 1] = str_fmt("Since: %s", fun.since)
    end

    if fun.desc then
        local desc = md_to_vimdoc(fun.desc, INDENT, INDENT, TEXT_WIDTH)
        table.insert(ret, desc)
    end

    add_notes(fun, ret)

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
    return table.concat(ret, "\n")
end

--- @param funs docgen.ParserObj[]
--- @param classes table<string,docgen.ParserObj>
--- @return string
local function render_funs(funs, classes)
    local ret = {} --- @type string[]
    for _, f in ipairs(funs) do
        ret[#ret + 1] = render_fun(f, classes)
    end

    table.sort(ret, function(a, b)
        local a1 = ("\n" .. a):match("\n[a-zA-Z_][^\n]+\n")
        local b1 = ("\n" .. b):match("\n[a-zA-Z_][^\n]+\n")
        return a1:lower() < b1:lower()
    end)
    -- TODO: yeet this when we have lnum based rendering

    return table.concat(ret)
end
-- TODO: Vaguely, I feel like what I want to be doing is putting together the lines throughout the
-- generation, and only do one concat at the end. It avoids a lot of the sub-level confusion
-- I've experienced trying to parse through what's doing what at what point.
-- At the moment though I guess we do want to do it by string just for consistency with the old
-- code.
-- TODO: There's some tweaking the cfg does with the functions using the fn_xform key. I'm not
-- sure what the generalized usecase here is

-----------------------------------
-- MARK: Main rendering function --
-----------------------------------

--- @param classes table<string,docgen.ParserObj>
--- @return string?
local function find_module_class(classes, modvar)
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
function M.render_docs(inputs, output_path)
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
        local mod_cls_nm = find_module_class(classes, "M")
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
        sections[basename] =
            make_section(basename, briefs, render_funs(funs, all_classes), render_classes(classes))
    end

    local docs = {} --- @type string[]
    for _, section in pairs(sections) do
        print(str_fmt("    Rendering section: '%s'", section.title))
        docs[#docs + 1] = render_section(section, true)
    end

    local ml = str_fmt(" vim:tw=78:ts=8:sw=%d:sts=%d:et:ft=help:norl:\n", INDENT, INDENT)
    table.insert(docs, ml)

    print("Writing output")
    local fp = assert(io.open(output_path, "w"))
    fp:write(table.concat(docs, "\n"))
    fp:close()
end

return M

local md_to_vimdoc = require("docgen.ts_parsing").luacats_md_to_vimdoc
local util = require("docgen.util")
local list_filter = util.list_filter
local wrap = util.wrap
local table_new = require("docgen.util").table_new

-- TODO: Get rid of this
local str_fmt = string.format

local TEXT_WIDTH = 78

-- TODO: Use these throughout the whole docgen
local INDENT = 4
local DBL_INDENT = INDENT * 2
local TPL_INDENT = INDENT * 3
local INDENT_STR = string.rep(" ", INDENT)
local DBL_INDENT_STR = string.rep(" ", DBL_INDENT)

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

--- True if the `.` class member should render like a module function.
--- @param fun docgen.DocItem|docgen.ParserObj
--- @return boolean
local function is_module_fun(fun)
    return fun.classvar ~= nil
        and fun.member_sep == "."
        and fun.modvar ~= nil
        and fun.module ~= nil
        and fun.classvar == fun.modvar
end

--- @param fun docgen.DocItem|docgen.ParserObj
--- @return string
local function fmt_fun_as_helptag(fun)
    if is_module_fun(fun) then
        return string.format("%s.%s%s", fun.module, fun.name)
    end

    if fun.classvar then
        return string.format("%s:%s%s", fun.classvar, fun.name, "()")
    end

    if fun.module then
        return string.format("%s.%s", fun.module, fun.name)
    end

    return fun.name .. "()"
end
-- TODO: Does the module name need to pipe through here? Maybe because it looks like this is used
-- for class rendering.
-- TODO: This is also awkward because this function is used in the field/param rendering combo
-- function, so you're basically just hoping that a class never has the classvar value
-- set. When the classvar bit is eventually added to the metatable, that needs to be clocked if
-- the obj kind is class. Same with aliases as well I'd guess.

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
--- @param width integer
--- @return string name
local function fmt_field_or_param_name(name, width)
    local name_iso, opt = name:match("^([^?]*)(%??)$")
    local raw_width = #name_iso + #opt
    local remain = math.max(width - raw_width - 2, 0)

    return "{" .. name_iso .. "}" .. opt .. string.rep(" ", remain)
end
-- MID: I don't love the math.max, but an assert feels heavy-handed.

--- @param xs docgen.DocItem[]
--- @return integer
local function get_max_field_or_name_width(xs)
    local width = 0
    local len_xs = #xs
    for i = 1, len_xs do
        local x = xs[i]
        if x.type or x.desc then
            -- Add one for each curly brace
            width = math.max(width, #x.name + 2)
        end
    end

    return width
end

---@param param nvim.luacats.parser.param
---@return boolean
local function should_render_param(param)
    return not (util.list_find({ "_", "self" }, param.name) or vim.startswith(param.name, "_"))
end

---@param field nvim.luacats.parser.field
---@return boolean
local function should_render_field(field)
    return not (field.nodoc or field.access)
end

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
        -- TODO: No formatting for help tags feels weird man
        local help_tag = str_fmt("%" .. rem_whitespace .. "s", section.help_tag)
        vim.list_extend(ret, { section.title, help_tag })
    end

    local briefs = section.briefs
    -- TODO: Do we need to check nil here?
    local len_briefs = briefs and #section.briefs or 0
    if len_briefs > 0 then
        local briefs_txt = {} --- @type string[]
        for i = 1, len_briefs do
            briefs_txt[#briefs_txt + 1] = md_to_vimdoc(briefs[i], 0, 0)
        end

        local sdoc = "\n\n" .. table.concat(briefs_txt, "\n")
        if sdoc:find("[^%s]") then
            ret[#ret + 1] = sdoc
        end
    end

    local classes_txt = section.classes_txt
    if classes_txt ~= "" then
        ret[#ret + 1] = "\n\n"
        ret[#ret + 1] = (classes_txt:gsub("\n+$", "\n"))
    end

    local funs_txt = section.funs_txt
    if funs_txt ~= "" then
        ret[#ret + 1] = "\n\n"
        ret[#ret + 1] = funs_txt
    end

    return table.concat(ret)
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

    local name = filename:match("(.*)%.[a-z]+")
    local sectname = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)

    -- TODO: Prefix for helptags. Unsure how to address without config
    -- Probably use @mod tags
    local help_labels = "demo-help-" .. sectname
    if type(help_labels) == "table" then
        help_labels = table.concat(help_labels, "* *")
    end

    local help_tags = "*" .. help_labels .. "*"

    return {
        name = sectname,
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

    typ = vim.trim(typ)
    typ = typ:gsub("%s*|%s*", "|")
    if fmt_nil ~= false then
        typ = typ:gsub("|nil", "?")
        typ = typ:gsub("nil|(.*)", "%1?")
    end

    if not default then
        return string.format("(`%s`)", typ)
    end

    return string.format("(`%s`, default: %s)", typ, default)
end

--- @param desc? string
--- @return string?, string?
local function get_and_rm_default(desc)
    if not desc then
        return
    end

    local default = desc:match("\n%s*%([dD]efault: ([^)]+)%)")
    if default then
        desc = desc:gsub("\n%s*%([dD]efault: [^)]+%)", "")
    end

    return desc, default
end

---@param is_list boolean
---@param is_optional boolean
---@return string
local function get_class_table_type(is_list, is_optional)
    local typ_tbl = { "table" }
    if is_list then
        typ_tbl[#typ_tbl + 1] = "[]"
    end

    if is_optional then
        typ_tbl[#typ_tbl + 1] = "?"
    end

    return table.concat(typ_tbl, "")
end

---@param is_list boolean
---@param parent string?
---@return string
local function get_class_inline_type_desc(is_list, parent)
    if is_list then
        return "A list of objects with the following fields:"
    elseif parent then
        return str_fmt("Extends |%s| with the additional fields:", parent)
    else
        return "A table with the following fields:"
    end
end

---@param old_desc string?
---@param class docgen.ParserObj
---@param is_list boolean
---@return string[] res
local function get_class_inlinedoc(old_desc, class, is_list)
    local ret = table_new(4, 0) ---@type string[]
    old_desc = old_desc or ""

    local class_desc = class.desc
    if class_desc then
        ret[1] = old_desc .. " " .. class_desc
    elseif #old_desc == 0 then
        local inline_desc = get_class_inline_type_desc(is_list, class.parent)
        ret[1] = old_desc .. " " .. inline_desc
    end

    local fields = class.fields
    if not fields then
        return ret
    end

    local len_fields = #fields
    if len_fields < 1 then
        return ret
    end

    local width = get_max_field_or_name_width(fields)
    for i = 1, len_fields do
        local field = fields[i]
        if not field.access then
            local name = fmt_field_or_param_name(field.name, width)
            local desc, default = get_and_rm_default(field.desc)
            local typ = render_type(field.type, nil, default)

            ret[#ret + 1] = table.concat({ "-", name, typ, desc }, " ")
        end
    end

    return ret
end
-- MID: The field width logic currently does nothing because wrap splits and re-assembles based
-- on space separation. Not a show-stopper since the core's docgen has the same limitation, but
-- unfortunate.

---@param desc string
---@param class docgen.ParserObj
local function append_see_class_tag(desc, class)
    local tag = string.format("|%s|", class.name)
    if string.find(desc, tag) then
        return desc
    end

    local len_desc = #desc
    local endswith_period = len_desc > 0 and string.byte(desc, len_desc) == 46
    local punctuation = (endswith_period or desc == "") and "" or "."
    return desc .. punctuation .. " See " .. tag .. "."
end

--- @param typ string
--- @return string base, boolean is_optional, boolean is_list
local function parse_clean_class_type(typ)
    if (not typ) or typ == "" then
        return "", false, false
    end

    local t = string.gsub(vim.trim(typ), "%s*|%s*", "|")

    local list_count
    t, list_count = string.gsub(t, "%[%]$", "")
    local n1
    t, n1 = string.gsub(t, "|nil", "")
    local n2
    t, n2 = string.gsub(t, "nil|", "")
    local n3
    t, n3 = string.gsub(t, "%?", "")

    return t, (n1 + n2 + n3) > 0, list_count > 0
end
-- TODO: This does not properly handle cases like `class_type|string`. Do we do a split  on `|`
-- here? Pass the types around as a list? This presumably has up and downstream effects because
-- everything else is built around the assumptions encoded here.

--- @param obj docgen.DocItem Modified in place
--- @param classes? table<string,docgen.ParserObj>
local function handle_class_types(obj, classes)
    if not classes then
        return
    end

    local typ = obj.type
    if not typ then
        return
    end

    local typ_clean, typ_isopt, typ_islist = parse_clean_class_type(typ)
    local class = classes[typ_clean]
    if (not class) or class.nodoc then
        return
    end

    if not class.inlinedoc then
        obj.desc = append_see_class_tag(obj.desc, class)
        return
    end

    local inlinedoc = get_class_inlinedoc(obj.desc, class, typ_islist)
    obj.desc = table.concat(inlinedoc, "\n")
    obj.type = get_class_table_type(typ_islist, typ_isopt)
end
-- TODO: I get what's being done here in terms of - Edit the obj to the logic can rejoin back with
-- the mainline function parsing. But in the end, we are creating "rendered" text that is not
-- actually rendered. What *should* happen is, the mainline type and desc rendering, should break
-- off into the separate logic. So this function ould take in and modify ret, and export is_list
-- and is_opt as needed

--- @param xs? docgen.DocItem[]
--- @param generics? table<string,string>
--- @param classes? table<string,docgen.ParserObj>
--- @param is_params boolean
--- @return string
local function render_fields_or_params(xs, generics, classes, is_params)
    if not xs then
        return ""
    end

    list_filter(xs, is_params and should_render_param or should_render_field)
    local len_xs = #xs
    if len_xs < 1 then
        return ""
    end

    local ret = {} --- @type string[]
    local width = get_max_field_or_name_width(xs)

    for i = 1, len_xs do
        local x = xs[i]
        local xdesc, default
        if not x.classvar then
            xdesc, default = get_and_rm_default(x.desc)
            x.desc = xdesc
        end

        handle_class_types(x, classes)
        local xname, xtyp = assert(x.name), x.type
        local is_op = x.kind == "operator"
        local name = is_op and string.format("op(%s)", xname)
            or fmt_field_or_param_name(xname, width)
        local name_bullet = "• " .. name

        local desc = x.classvar and string.format("See |%s|.", fmt_fun_as_helptag(x)) or x.desc
        local start_indent = DBL_INDENT
        if xtyp then
            local typ = render_type(xtyp, generics, default)
            if desc then
                if #typ > TEXT_WIDTH - (DBL_INDENT + #name_bullet + 1) then
                    ret[#ret + 1] = name_bullet .. " " .. typ
                    ret[#ret + 1] = "\n"
                    start_indent = TPL_INDENT
                else
                    desc = name_bullet .. " " .. typ .. " " .. desc
                end

                local parsed_md = md_to_vimdoc(desc, start_indent, TPL_INDENT)
                ret[#ret + 1] = wrap(parsed_md, start_indent, TPL_INDENT, TEXT_WIDTH)
            else
                -- TODO: Repetitious
                local to_wrap = name_bullet .. " " .. typ
                ret[#ret + 1] = wrap(to_wrap, DBL_INDENT, TPL_INDENT, TEXT_WIDTH)
                -- TODO: Why does this need a newline but not the others?
                ret[#ret + 1] = "\n"
            end
        elseif desc then
            -- TODO: Still somewhat repetitious
            local to_wrap = name_bullet .. " " .. desc
            local parsed_md = md_to_vimdoc(to_wrap, DBL_INDENT, TPL_INDENT)
            ret[#ret + 1] = wrap(parsed_md, DBL_INDENT, TPL_INDENT, TEXT_WIDTH)
        end
    end

    return table.concat(ret)
end
-- TODO: This is used for functions and classes, hich means we want render_type to perform
-- the question mark replacement only on functions. This function needs to be able to handle that,
-- either as a param or some kind of logical check.
-- LOW: The cache locality in this function feels not so good.

---------------------------
-- MARK: Class Rendering --
---------------------------

--- @param class docgen.ParserObj
--- @param classes table<string,docgen.ParserObj>
--- @param hidden_fields? table<string,table<string,true>>
--- @return string|nil
local function render_class(class, classes, hidden_fields)
    if class.access or class.nodoc or class.inlinedoc then
        return
    end

    local ret = {} --- @type string[]

    ret[#ret + 1] = str_fmt("*%s*\n", class.name)

    if class.parent then
        local txt = str_fmt("Extends: |%s|", class.parent)
        ret[#ret + 1] = md_to_vimdoc(txt, INDENT, INDENT)
        ret[#ret + 1] = "\n"
    end

    if class.desc then
        ret[#ret + 1] = md_to_vimdoc(class.desc, INDENT, INDENT)
    end

    local class_hidden = hidden_fields and hidden_fields[class.name]
    local fields = class.fields
    if class_hidden and fields then
        list_filter(fields, function(field)
            return not class_hidden[field.name]
        end)
    end

    local fields_txt = render_fields_or_params(fields, nil, classes, false)
    if not fields_txt:match("^%s*$") then
        ret[#ret + 1] = "\n    Fields: ~\n"
        ret[#ret + 1] = fields_txt
    end

    ret[#ret + 1] = "\n"
    return table.concat(ret)
end
-- TODO: Unsure where this should be addressed, but when class descriptions are rendered for
-- inline doc, if there is description after the field definition, it overrides anything above the
-- definition.

--- @param classes table<string,docgen.ParserObj>
--- @param funs docgen.ParserObj[]
local function render_classes(classes, funs)
    local ret = {} --- @type string[]
    local hidden_fields = {} --- @type table<string,table<string,true>>
    for _, fun in ipairs(funs) do
        if is_module_fun(fun) and fun.class then
            hidden_fields[fun.class] = hidden_fields[fun.class] or {}
            hidden_fields[fun.class][fun.name] = true
        end
    end

    for _, class in vim.spairs(classes) do
        ret[#ret + 1] = render_class(class, classes, hidden_fields)
    end

    return table.concat(ret)
end
-- TODO: Keep spairs for now but I'm not sure it survives the module based re-organization

------------------------------
-- MARK: Function Rendering --
------------------------------

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
        local name = param.name
        if name ~= "self" then
            args[#args + 1] = fmt_field_or_param_name(name, 0)
        end
    end

    return args
end
-- TODO: Why don't the params come in with question marks?

--- @param fun docgen.ParserObj
--- @param ret string[]
local function add_fun_header(fun, ret)
    local name = (fun.classvar and not is_module_fun(fun))
            and string.format("%s:%s", fun.classvar, fun.name)
        or fun.name

    local param_list = get_params(fun)
    local param_str = param_list and table.concat(param_list, ", ") or ""
    local proto_len = #name + #param_str + 2 -- Add two for parens

    local tag = "*" .. fmt_fun_as_helptag(fun) .. "*"
    local len_tag = #tag
    if proto_len + len_tag <= TEXT_WIDTH - 8 then
        local full_proto = string.format("%s(%s)", name, param_str)
        local padding = TEXT_WIDTH - #full_proto - len_tag
        ret[#ret + 1] = full_proto .. string.rep(" ", padding) .. tag
        return
    end

    ret[#ret + 1] = string.format("%78s", tag)
    if param_list and #param_list > 0 then
        local wrapped = util.wrap(param_str, 0, #name, TEXT_WIDTH)
        ret[#ret + 1] = name .. "(" .. wrapped .. ")"
    else
        ret[#ret + 1] = name .. "()"
    end

    return ret
end
-- MAYBE: The core's docgen has logic to re-check the name and add the proto to ret if name does
-- not pass a string.match for the proper format. I'm not sure if I need that here due to how I
-- have name/param generation divided.
-- Note that this pertains to https://github.com/neovim/neovim/pull/39078, which handles rendering
-- module classes with dot syntax.

---@param fun docgen.ParserObj
---@param ret string[]
local function add_see(fun, ret)
    local see = fun.see
    if not see then
        return
    end

    local len_see = #see
    if len_see < 1 then
        return
    end

    ret[#ret + 1] = "\n See also: ~"
    for i = 1, len_see do
        ret[#ret + 1] = "• " .. md_to_vimdoc(see[i].desc, 0, 8)
    end
end

---@param fun docgen.ParserObj
---@param classes table<string,docgen.ParserObj>
---@param ret string[]
local function add_returns(fun, classes, ret)
    local returns = fun.returns
    if not returns then
        return
    end

    local len_returns = #returns
    if len_returns < 1 then
        return
    end

    local lines = {} --- @type string[]
    local indent = INDENT_STR
    local text = len_returns > 1 and "Returns (multiple): ~" or "Returns: ~"
    lines[#lines + 1] = indent .. text

    for i = 1, len_returns do
        local r = returns[i]

        handle_class_types(r, classes)
        local line_tbl = {}
        if r.type then
            line_tbl[#line_tbl + 1] = render_type(r.type, fun.generics)
        end

        if r.name then
            line_tbl[#line_tbl + 1] = r.name
        end

        if r.desc then
            line_tbl[#line_tbl + 1] = r.desc
        end

        if #line_tbl > 0 then
            local line = table.concat(line_tbl, " ")
            lines[#lines + 1] = md_to_vimdoc(line, 8, 8)
        end
    end

    if lines and #lines > 0 then
        ret[#ret + 1] = ""
        vim.list_extend(ret, lines)
    end
end

---@param fun docgen.ParserObj
---@param ret string[]
local function add_overloads(fun, ret)
    local overloads = fun.overloads
    if not overloads then
        return
    end

    ret[#ret + 1] = "\n Overloads: ~"
    local len_overloads = #overloads
    for i = 1, len_overloads do
        ret[#ret + 1] = "• `" .. overloads[i] .. "`"
    end
end

---@param fun docgen.ParserObj
---@param ret string[]
local function add_notes(fun, ret)
    local notes = fun.notes
    if not notes then
        return
    end

    local len_notes = #notes
    if len_notes < 1 then
        return
    end

    ret[#ret + 1] = "\n Note: ~"
    for i = 1, len_notes do
        local vimdoc = md_to_vimdoc(notes[i].desc, 0, 8)
        ret[#ret + 1] = "• " .. vimdoc
    end
end

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
--- @param classes table<string,docgen.ParserObj>
--- @return string[]?
local function render_fun(fun, classes)
    if not should_render_fun(fun) then
        return nil
    end

    local ret = {} ---@type string[]
    add_fun_header(fun, ret)
    ret[#ret + 1] = ""

    if fun.desc then
        ret[#ret + 1] = md_to_vimdoc(fun.desc, INDENT, INDENT)
    end

    add_notes(fun, ret)
    if fun.since then
        ret[#ret + 1] = "\n" .. INDENT_STR .. "Attributes: ~\n"
        ret[#ret + 1] = DBL_INDENT_STR .. "Since: " .. fun.since
    end

    if fun.params and #fun.params > 0 then
        local param_txt = render_fields_or_params(fun.params, fun.generics, classes, true)
        if not param_txt:match("^%s*$") then
            ret[#ret + 1] = INDENT_STR .. "Parameters: ~"
            ret[#ret + 1] = param_txt
        end
    end

    add_overloads(fun, ret)
    add_returns(fun, classes, ret)
    add_see(fun, ret)

    ret[#ret + 1] = ""
    return ret
end

--- @param funs docgen.ParserObj[]
--- @param classes table<string,docgen.ParserObj>
--- @return string
local function render_funs(funs, classes)
    table.sort(funs, function(a, b)
        local key_a = a.classvar and (a.classvar .. ":" .. a.name) or a.name or ""
        local key_b = b.classvar and (b.classvar .. ":" .. b.name) or b.name or ""
        return key_a:lower() < key_b:lower()
    end)

    local all_lines = {} --- @type string[]
    local len_funs = #funs
    for i = 1, len_funs do
        local fun = funs[i]
        local fun_lines = render_fun(fun, classes)
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
        -- TODO: the fields are LuaCATs grammars, which don't have classvar
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

        local funs_txt = render_funs(funs, all_classes)
        local classes_txt = render_classes(classes, funs)
        sections[basename] = make_section(basename, briefs, funs_txt, classes_txt)
    end

    local docs = {} --- @type string[]
    for _, section in pairs(sections) do
        print(string.format("    Rendering section: '%s'", section.title))
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

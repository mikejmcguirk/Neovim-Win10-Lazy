local ts_parsing = require("docgen.ts_parsing")
local md_to_vimdoc = ts_parsing.luacats_md_to_vimdoc

local util = require("docgen.util")
local cbraces_add = util.add_cbraces
local table_clear = util.table_clear
local type_fmt_get_with_default = util.type_fmt_get_with_default
local wrap = util.wrap

local const = require("docgen.const")
local INDENT = const.INDENT
local DBL_INDENT = const.DBL_INDENT
local DBL_INDENT_STR = const.DBL_INDENT_STR
local TPL_INDENT = const.TPL_INDENT
local INDENT_STR = const.INDENT_STR
local TEXT_WIDTH = const.TEXT_WIDTH

-----------------------------
-- MARK: Section Rendering --
-----------------------------

---@param source_name string
---@param rendered string[]
---@return docgen.Section?
local function section_create(source_name, rendered)
    -- TODO: I think this is the right baseline behavior. Since the names should be filename
    -- based, they should be lowercase. And then we have a camel/snake case title that looks
    -- more appealing.
    -- TODO: Have to be able to handle non-filename sources though
    local name = source_name:match("(.*)%.[a-z]+")
    local help_labels = Nvim_Tools_Docgen_Help_Prefix .. "-" .. name
    if type(help_labels) == "table" then
        help_labels = table.concat(help_labels, "* *")
    end

    local help_tags = "*" .. help_labels .. "*"
    local sectname = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)

    return {
        name = sectname,
        title = sectname,
        help_tag = help_tags,
        rendered = rendered,
    }
end

---@class docgen.Section
---@field name string
---@field title string
---@field help_tag string
---@field rendered string[]

--- @param section docgen.Section
--- @param add_header? boolean
local function section_render(section, add_header)
    local ret = {} --- @type string[]

    if add_header ~= false then
        local border = string.rep("=", TEXT_WIDTH) .. "\n"
        ret[#ret + 1] = border
        local rem_whitespace = TEXT_WIDTH - #section.title
        local help_tag = string.format("%" .. rem_whitespace .. "s", section.help_tag)
        vim.list_extend(ret, { section.title, help_tag })
    end

    ret[#ret + 1] = "\n\n"
    ret[#ret + 1] = table.concat(section.rendered, "\n\n")

    return table.concat(ret)
end

------------------
-- MARK: Obj Utils
------------------

---@param name string
---@param typ string
---@param desc string
---@return string
local function fmt_arg(name, typ, desc)
    local lines = {}
    local start_indent = DBL_INDENT
    local to_wrap
    local bullet = "• "

    if typ and #typ > 0 then
        if desc and #desc > 0 then
            if #typ > TEXT_WIDTH - (DBL_INDENT + #name + 1) then
                lines[#lines + 1] = bullet .. name .. " " .. typ .. "\n"
                start_indent = TPL_INDENT

                to_wrap = desc
            else
                to_wrap = bullet .. name .. " " .. typ .. " " .. desc
            end
        else
            to_wrap = bullet .. name .. " " .. typ
        end
    elseif desc and #desc > 0 then
        to_wrap = bullet .. name .. " " .. desc
    else
        return ""
    end

    local md_text = md_to_vimdoc(to_wrap)
    lines[#lines + 1] = wrap(md_text, start_indent, TPL_INDENT, TEXT_WIDTH)
    return table.concat(lines, "\n")
end
-- TODO: Where does the colon go in here?

---@param title string
---@param tag string
---@param title_wrap_indent integer
---@return string
local function header_assemble(title, tag, title_wrap_indent)
    local len_title = #title
    local len_tag = #tag

    if len_title + len_tag <= TEXT_WIDTH - DBL_INDENT then
        local padding = TEXT_WIDTH - len_title - len_tag
        return title .. string.rep(" ", padding) .. tag
    end

    title = wrap(title, 0, title_wrap_indent, TEXT_WIDTH)
    return string.format("%" .. TEXT_WIDTH .. "s", tag) .. "\n" .. title
end

--- @param obj docgen.ParserObj
--- @return string?
local function post_header_get(obj)
    local is_deprecated = obj:is_deprecated()
    local desc = obj:desc_get()
    local parent = obj:parent_get()
    if not (is_deprecated or desc or parent) then
        return
    end

    local ret = {}
    if is_deprecated then
        local deprecated_tbl = {}
        deprecated_tbl[#deprecated_tbl + 1] = INDENT_STR
        deprecated_tbl[#deprecated_tbl + 1] = "DEPRECATED: "
        local doc_flag_desc = obj:doc_flag_desc_get()
        if doc_flag_desc then
            -- TODO: Tag injection was originally handled here. The tag needs to be resolved
            -- during the holistic step when we have a view into everything.
            deprecated_tbl[#deprecated_tbl + 1] = md_to_vimdoc(doc_flag_desc)
        end

        ret[#ret + 1] = table.concat(deprecated_tbl)
    end

    if parent then
        ret[#ret + 1] = INDENT_STR .. "Extends: " .. parent
    end

    if desc then
        ret[#ret + 1] = wrap(md_to_vimdoc(desc), INDENT, INDENT, TEXT_WIDTH)
    end

    return table.concat(ret, "\n\n")
end
-- TODO: Will keep repeating this because it's important - If the underlying data here is wrong,
-- it needs to be fixed in parser_obj, because the interfaces here are what's expected to
-- work.

---------------------------
-- MARK: Brief Rendering --
---------------------------

---@param brief docgen.ParserObj
---@return string
local function render_brief(brief)
    return wrap(md_to_vimdoc(brief:desc_get() or ""), 0, 0, TEXT_WIDTH)
end

---------------------------
-- MARK: Class Rendering --
---------------------------

---@param class docgen.ParserObj
--- @return string
local function header_class_get(class)
    local class_name = class:name_get() --[[@as string]]
    local display_name = cbraces_add(class_name, 0)
    local tag = "*" .. class:tag_get() .. "*" --[[@as string]]

    return header_assemble(display_name, tag, INDENT)
end

--- @param class docgen.ParserObj
--- @return string?
local function fields_get(class)
    local max_name_width = class:field_names_max_width()
    if max_name_width == 0 then
        return
    end

    local ret = {}
    ret[#ret + 1] = INDENT_STR .. "Fields: ~"
    class:fields_sort(function(a, b)
        return a.name < b.name
    end)

    local max_cbrace_name_width = max_name_width + 3
    class:fields_iter(function(field)
        -- TODO: Does this get pushed down into fmt_arg?
        local cbrace_name = cbraces_add(field.name, max_cbrace_name_width)
        -- TODO: Does this get pushed down into fmt_arg?
        local typ = type_fmt_get_with_default(field.type, field.default)
        local desc = field.desc or ""
        ret[#ret + 1] = fmt_arg(cbrace_name, typ, desc)
    end)

    return table.concat(ret, "\n")
end

--- @param class docgen.ParserObj
--- @return string|nil
local function class_render(class)
    local ret = {} --- @type string[]

    local header = header_class_get(class)
    local post_header = post_header_get(class)
    if post_header then
        ret[#ret + 1] = header .. "\n" .. post_header
    else
        ret[#ret + 1] = header
    end

    ret[#ret + 1] = fields_get(class)
    return table.concat(ret, "\n\n")
end

------------------------------
-- MARK: Function Rendering --
------------------------------

--- @param fun docgen.ParserObj
--- @return string
local function header_fun_get(fun)
    local header_title = fun:namevar_get()

    local params
    if fun:params_count() > 0 then
        local params_tbl = {}
        fun:params_iter(function(param)
            -- TODO: This previously included a check for if the param did not equal self. The
            -- self param should be handled when building the function data. dot functions should
            -- keep the self var, colon functions should discard.
            params_tbl[#params_tbl + 1] = cbraces_add(param.name, 0)
        end)

        params = table.concat(params_tbl, ", ")
    else
        params = ""
    end

    local full_proto = string.format("%s(%s)", header_title, params)
    local tag = "*" .. fun:tag_get() .. "*" --[[@as string]]
    return header_assemble(full_proto, tag, #header_title)
end
-- TODO: If there are problems with the data in this function, the parser_obj needs to be fixed.
-- The interfaces here should produce the expected output.

---@param fun docgen.ParserObj
---@return string?
local function see_get(fun)
    if fun:see_count() == 0 then
        return
    end

    local ret = {}
    ret[#ret + 1] = INDENT_STR
    ret[#ret + 1] = "See also: ~"
    fun:see_iter(function(see)
        ret[#ret + 1] = "\n"
        ret[#ret + 1] = DBL_INDENT_STR
        ret[#ret + 1] = "• "
        -- TODO: The old see_fmt_get() injected the tags into here. This needs to be pre-handled
        -- by the parser_obj
        ret[#ret + 1] = md_to_vimdoc(see)
    end)

    return table.concat(ret)
end
-- TODO: If there are problems with the data in this function, the parser_obj needs to be fixed.
-- The interfaces here should produce the expected output.

---@param fun docgen.ParserObj
---@return string?
local function returns_get(fun)
    local returns_count = fun:returns_count()
    if fun:returns_count() == 0 then
        return
    end

    local ret = {} --- @type string[]
    local sub_header = returns_count > 1 and "Returns (multiple): ~" or "Returns: ~"
    ret[#ret + 1] = INDENT_STR .. sub_header

    local ret_inner = {} ---@type string[]
    fun:returns_iter(function(r)
        for _, inner_r in ipairs(r) do
            local typ = type_fmt_get_with_default(inner_r.type)
            local name = inner_r.name
            if name then
                ret_inner[#ret_inner + 1] = typ .. " " .. cbraces_add(name, 0)
            else
                ret_inner[#ret_inner + 1] = typ
            end
        end

        local desc = r.desc
        local sep
        if #r > 1 then
            sep = "\n"
            if desc then
                ret_inner[#ret_inner + 1] = desc
            end
        else
            sep = ""
            if desc then
                ret_inner[#ret_inner + 1] = ": "
                ret_inner[#ret_inner + 1] = desc
            end
        end

        local r_fmt = md_to_vimdoc(table.concat(ret_inner, sep))
        ret[#ret + 1] = wrap(r_fmt, DBL_INDENT, TPL_INDENT, TEXT_WIDTH)
        table_clear(ret_inner)
    end)

    return table.concat(ret, "\n")
end
-- MID: Smarter rendering for multiple returns:
-- - Should not matter if the user uses multiple annotations or puts them all on one line.
-- - Desc should only be on its own line if the types/names are too long.
-- - Like params/fields, multiple returns should align based on type + name width.
-- LOW: It would be better to not have to assemble the ret_inner table.

---@param fun docgen.ParserObj
---@return string?
local function overloads_get(fun)
    if fun:overloads_count() == 0 then
        return
    end

    local ret = {}
    ret[#ret + 1] = INDENT_STR
    ret[#ret + 1] = "Overloads: ~"
    fun:overloads_iter(function(overload)
        ret[#ret + 1] = "\n"
        ret[#ret + 1] = DBL_INDENT_STR
        ret[#ret + 1] = "• "
        ret[#ret + 1] = md_to_vimdoc(overload)
    end)

    return table.concat(ret)
end

--- @param fun docgen.ParserObj
--- @return string?
local function attributes_get(fun)
    if not fun:async_get() then
        return
    end

    local ret = {}
    ret[#ret + 1] = INDENT_STR
    ret[#ret + 1] = "Attributes: ~\n"
    ret[#ret + 1] = DBL_INDENT_STR
    ret[#ret + 1] = "• {async}"

    return table.concat(ret)
end

--- @param fun docgen.ParserObj
--- @return string?
local function params_get(fun)
    local max_name_width = fun:param_names_max_width()
    if max_name_width == 0 then
        return
    end

    local ret = {}
    ret[#ret + 1] = INDENT_STR .. "Parameters: ~"

    local max_cbrace_name_width = max_name_width + 3
    fun:params_iter(function(param)
        -- TODO: Does this get pushed down into fmt_arg?
        local cbrace_name = cbraces_add(param.name, max_cbrace_name_width)
        -- TODO: Does this get pushed down into fmt_arg?
        local typ = type_fmt_get_with_default(param.type, param.default)
        local desc = param.desc or ""
        ret[#ret + 1] = fmt_arg(cbrace_name, typ, desc)
    end)

    return table.concat(ret, "\n")
end
-- TODO: Re-iterating again - The interfaces here should not change. Bad data means the
-- parser_obj is wrong.

--- @param fun docgen.ParserObj
--- @return string
local function render_fun(fun)
    local ret = {} ---@type string[]

    local header = header_fun_get(fun)
    local post_header = post_header_get(fun)
    if post_header then
        ret[#ret + 1] = header .. "\n" .. post_header
    else
        ret[#ret + 1] = header
    end

    local attributes = attributes_get(fun)
    if attributes then
        ret[#ret + 1] = attributes
    end

    local params = params_get(fun)
    if params then
        ret[#ret + 1] = params
    end

    local overloads = overloads_get(fun)
    if overloads then
        ret[#ret + 1] = overloads
    end

    local returns = returns_get(fun)
    if returns then
        ret[#ret + 1] = returns
    end

    local see = see_get(fun)
    if see then
        ret[#ret + 1] = see
    end

    return table.concat(ret, "\n\n")
end

----------------
-- MARK: Main --
----------------

local M = {}

---@param parsed_sources docgen.ParsedSource[]
---@param output_path string
function M.render_docs(parsed_sources, output_path)
    local sections = {} --- @type table<string,docgen.Section>

    for _, source in ipairs(parsed_sources) do
        local source_name = source[1]
        print("    Rendering source:" .. source_name, 0)
        -- TODO: Not relevant if the source is not a filename
        local basename = vim.fs.basename(source_name)

        local source_objs = source[2]
        local rendered = {} ---@type string[]
        for _, obj in ipairs(source_objs) do
            if obj:kind_get() == "fun" then
                rendered[#rendered + 1] = render_fun(obj)
            elseif obj:kind_get() == "class" then
                rendered[#rendered + 1] = class_render(obj)
            elseif obj:kind_get() == "brief" then
                rendered[#rendered + 1] = render_brief(obj)
            end
        end

        sections[#sections + 1] = section_create(basename, rendered)
    end

    local docs = {} --- @type string[]
    for _, section in ipairs(sections) do
        print(string.format("    Rendering section: '%s'", section.title))
        docs[#docs + 1] = section_render(section, true)
    end

    -- The trailing newline is required by the vimdoc spec.
    local ml = string.format("\n vim:tw=78:ts=8:sw=%d:sts=%d:et:ft=help:norl:\n", INDENT, INDENT)
    table.insert(docs, ml)

    print("Writing output")
    -- TODO: This should be handled by the caller.
    -- Do fancy uv things to validate the file before generating and to do the writing.
    local fp = assert(io.open(output_path, "w"))
    fp:write(table.concat(docs, "\n"))
    fp:close()
end

return M

local ts_parsing = require("docgen.ts_parsing")
local md_to_vimdoc = ts_parsing.luacats_md_to_vimdoc

local util = require("docgen.util")
local cbraces_add = util.cbraces_add
local help_tag_from_name = util.help_tag_from_name
local wrap = util.wrap

local const = require("docgen.const")
local INDENT = const.INDENT
local DBL_INDENT = const.DBL_INDENT
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
local function fmt_arg_mapper(name, typ, desc)
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

---@param tag string
---@return string
local function tag_header_get(tag)
    return string.format("%" .. TEXT_WIDTH .. "s", tag)
end
-- FUTURE: This works for multi-tagging. Each object would have a list of tags associated with it.
-- The tags would display, right-justified, in alphabetical order. Most would just use
-- `get_fmt_lone_tag()` to display, and the last would use `get_fmt_header()`.

---@param header string
---@param tag string
---@param wrap_indent integer
---@return string
local function header_get(header, tag, wrap_indent)
    local len_header = #header
    local len_tag = #tag

    if len_header + len_tag <= TEXT_WIDTH - DBL_INDENT then
        local padding = TEXT_WIDTH - len_header - len_tag
        return header .. string.rep(" ", padding) .. tag
    end

    header = wrap(header, 0, wrap_indent, TEXT_WIDTH)
    return tag_header_get(tag) .. "\n" .. header
end

--- @param obj docgen.ParserObj
--- @return string?
local function post_header_get(obj)
    local deprecated = obj:deprecated()
    local fmt_desc = obj:get_fmt_desc()
    local parent = obj:parent_get()
    if not (deprecated or fmt_desc or parent) then
        return
    end

    local ret = {}
    if deprecated then
        ret[#ret + 1] = INDENT_STR .. obj:fmt_doc_desc_get()
    end

    if parent then
        ret[#ret + 1] = INDENT_STR .. "Extends: " .. parent
    end

    if fmt_desc then
        ret[#ret + 1] = wrap(fmt_desc, INDENT, INDENT, TEXT_WIDTH)
    end

    return table.concat(ret, "\n\n")
end

---------------------------
-- MARK: Brief Rendering --
---------------------------

local function render_brief(brief)
    return wrap(brief:get_fmt_brief(), 0, 0, TEXT_WIDTH)
end

---------------------------
-- MARK: Class Rendering --
---------------------------

---@param class docgen.ParserObj
--- @return string
local function get_class_header(class)
    local class_fmt_name = class:fmt_name_get() --[[@as string]]
    local display_name = cbraces_add(class_fmt_name, 0)
    local tag = help_tag_from_name(class_fmt_name, "*")

    return header_get(display_name, tag, INDENT)
end
-- MAYBE: The literal class name might be fine since that's how it shows up when you dot-complete
-- the annotation.

--- @param class docgen.ParserObj
--- @return string?
local function get_fields(class)
    local fmt_fields = class:map_fmt_fields(fmt_arg_mapper)
    if not fmt_fields then
        return
    end

    local header = INDENT_STR .. "Fields: ~\n"
    return header .. table.concat(fmt_fields, "\n")
end

--- @param class docgen.ParserObj
--- @return string|nil
local function render_class(class)
    local ret = {} --- @type string[]

    local header = get_class_header(class)
    local post_header = post_header_get(class)
    if post_header then
        ret[#ret + 1] = header .. "\n" .. post_header
    else
        ret[#ret + 1] = header
    end

    ret[#ret + 1] = get_fields(class)
    return table.concat(ret, "\n\n")
end

------------------------------
-- MARK: Function Rendering --
------------------------------

--- @param fun docgen.ParserObj
--- @return string
local function fun_header_get(fun)
    local name = fun:fmt_name_get() --[[@as string]]
    local param_list = fun:params_fmt_get(0)
    local param_str = param_list and table.concat(param_list, ", ") or ""
    local full_proto = string.format("%s(%s)", name, param_str)

    local name_parens = fun:fmt_name_get(true) --[[@as string]]
    local tag = help_tag_from_name(name_parens, "*")
    return header_get(full_proto, tag, #name)
end

---@param fun docgen.ParserObj
---@return string?
local function get_see(fun)
    local fmt_see = fun:see_fmt_get()
    if not fmt_see then
        return
    end

    local header = "See also: ~\n"
    return INDENT_STR .. header .. wrap(fmt_see, DBL_INDENT, DBL_INDENT, TEXT_WIDTH)
end

---@param fun docgen.ParserObj
---@return string?
local function get_returns(fun)
    local len_returns = fun:returns_count()
    if len_returns < 1 then
        return
    end

    local lines = {} --- @type string[]
    local header = len_returns > 1 and "Returns (multiple): ~" or "Returns: ~"
    lines[#lines + 1] = INDENT_STR .. header

    local fmt_returns = fun:returns_fmt_get()
    local len_fmt_returns = #fmt_returns
    for i = 1, len_fmt_returns do
        fmt_returns[i] = wrap(fmt_returns[i], DBL_INDENT, TPL_INDENT, TEXT_WIDTH)
    end

    vim.list_extend(lines, fmt_returns)
    return table.concat(lines, "\n")
end

---@param fun docgen.ParserObj
---@return string?
local function get_overloads(fun)
    local fmt_overloads = fun:overloads_fmt_get()
    if not fmt_overloads then
        return
    end

    local header = "Overloads: ~\n"
    return header .. wrap(fmt_overloads, 0, 0, TEXT_WIDTH)
end

--- @param fun docgen.ParserObj
--- @return string?
local function get_attributes(fun)
    local fmt_attributes = fun:get_fmt_attributes()
    if not fmt_attributes then
        return
    end

    local header = INDENT_STR .. "Attributes: ~\n"
    return header .. wrap(fmt_attributes, DBL_INDENT, DBL_INDENT, TEXT_WIDTH)
end

--- @param fun docgen.ParserObj
--- @return string?
local function get_params(fun)
    local fmt_params = fun:params_fmt_map(fmt_arg_mapper)
    if not fmt_params then
        return
    end

    local header = INDENT_STR .. "Parameters: ~\n"
    return header .. table.concat(fmt_params, "\n")
end

--- @param fun docgen.ParserObj
--- @return string
local function render_fun(fun)
    local ret = {} ---@type string[]

    local header = fun_header_get(fun)
    local post_header = post_header_get(fun)
    if post_header then
        ret[#ret + 1] = header .. "\n" .. post_header
    else
        ret[#ret + 1] = header
    end

    ret[#ret + 1] = get_attributes(fun)
    ret[#ret + 1] = get_params(fun)
    ret[#ret + 1] = get_overloads(fun)
    ret[#ret + 1] = get_returns(fun)
    ret[#ret + 1] = get_see(fun)

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
            print(vim.inspect(obj))
            if obj:kind_get() == "fun" then
                rendered[#rendered + 1] = render_fun(obj)
            elseif obj:kind_get() == "class" then
                rendered[#rendered + 1] = render_class(obj)
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
    local fp = assert(io.open(output_path, "w"))
    fp:write(table.concat(docs, "\n"))
    fp:close()
end

return M

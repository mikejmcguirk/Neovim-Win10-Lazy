-- Forked version of the Neovim core docgen.

local logger = require("docgen.logger")
local log = logger.log

local ts_parsing = require("docgen.ts_parsing")
local md_to_vimdoc = ts_parsing.luacats_md_to_vimdoc
-- TODO: Replace with the updated parser

local util = require("docgen.util")
local list_copy = util.list_copy
local list_fold = util.list_fold
local list_map = util.list_map
local str_lpad = util.str_rpad
local rpad = util.str_rpad
local str_surround = util.str_surround
local str_op_by_sep = util.str_op_by_sep
local table_clear = util.table_clear
local type_fmt_get_with_default = util.type_fmt_get_with_default
local wrap = util.wrap

local const = require("docgen.const")
local INDENT = const.INDENT
local INDENT_STR = const.INDENT_STR
local DBL_INDENT = const.DBL_INDENT
local DBL_INDENT_STR = const.DBL_INDENT_STR
local TPL_INDENT = const.TPL_INDENT
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
    local help_labels = source_name
    if type(help_labels) == "table" then
        help_labels = table.concat(help_labels, "* *")
    end

    local help_tags = "*" .. help_labels .. "*"
    local sectname = string.upper(string.sub(source_name, 1, 1)) .. string.sub(source_name, 2)

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

---@param arg docgen.DocItem
---@param max_name_width integer
---@return string
local function arg_fmt(arg, max_name_width)
    local name_cbraced = rpad(str_surround(arg.name, "{", "}"), " ", max_name_width)
    local typ = type_fmt_get_with_default(arg.type, arg.default)
    local desc = arg.desc or ""

    local lines = {}
    local start_indent = DBL_INDENT
    local to_wrap
    local bullet = "• "

    if typ and #typ > 0 then
        if desc and #desc > 0 then
            if #typ > TEXT_WIDTH - (DBL_INDENT + #name_cbraced + 1) then
                lines[#lines + 1] = bullet .. name_cbraced .. " " .. typ .. "\n"
                start_indent = TPL_INDENT

                to_wrap = desc
            else
                to_wrap = bullet .. name_cbraced .. " " .. typ .. " " .. desc
            end
        else
            to_wrap = bullet .. name_cbraced .. " " .. typ
        end
    elseif desc and #desc > 0 then
        to_wrap = bullet .. name_cbraced .. " " .. desc
    else
        return ""
    end

    local md_text = md_to_vimdoc(to_wrap)
    lines[#lines + 1] = wrap(md_text, start_indent, TPL_INDENT, TEXT_WIDTH)
    return table.concat(lines, "\n")
end
-- TODO: This is too complicated still.
-- TODO: Where does the colon go in here?

---@param title string
---@param tag string?
---@param title_wrap_indent integer
---@return string
local function header_title_assemble(title, tag, title_wrap_indent)
    local title_len = #title
    tag = tag or ""
    local tag_len = #tag
    local content_width = title_len + tag_len
    if content_width <= TEXT_WIDTH - DBL_INDENT then
        return title .. string.rep(" ", TEXT_WIDTH - content_width) .. tag
    end

    title = wrap(title, 0, title_wrap_indent, TEXT_WIDTH)
    return string.rep(" ", TEXT_WIDTH - tag_len) .. tag .. "\n" .. title
end
-- TODO: Swap tag and title_wrap_indent

---@param title string Title Cased based on `-` separators
---@param title_wrap integer If the title spans multiple lines, what indentation should the
---     additional lines have?
---     Example:
---         foo({bar}, {bazz},
---            {buzz})
---@param tags string[]|nil `*` surrounds are added.
---@param sep "="|"-"|nil
local function header_create(title, title_wrap, tags, sep)
    local ret = {}
    if sep then
        ret[#ret + 1] = string.rep(sep, TEXT_WIDTH)
    end

    if tags then
        local tags_len_minus_one = #tags
        for i = 1, tags_len_minus_one do
            ret[#ret + 1] = str_lpad(str_surround(tags[i], "*"), " ", TEXT_WIDTH)
        end
    end

    local tag_fmt = (tags and #tags > 0) and str_surround(tags[#tags], "*") or nil
    local title_fmt = str_op_by_sep(title, "-", function(part)
        return string.upper(string.sub(part, 1, 1)) .. string.sub(part, 2)
    end)

    ret[#ret + 1] = header_title_assemble(title_fmt, tag_fmt, title_wrap)

    return table.concat(ret, "\n")
end

--- @param obj docgen.ParserObj
--- @return string?
local function post_header_get(obj)
    local is_deprecated = obj.doc_flag == "deprecated"
    local desc = obj.desc
    local parent = obj.parent
    if not (is_deprecated or desc or parent) then
        return
    end

    local ret = {}
    if is_deprecated then
        local doc_flag_desc = obj.doc_flag_desc
        if doc_flag_desc then
            local df_desc_fmt = md_to_vimdoc(doc_flag_desc)
            local df_desc_wrapped = wrap(df_desc_fmt, DBL_INDENT, DBL_INDENT, TEXT_WIDTH)
            ret[#ret + 1] = INDENT_STR .. "DEPRECATED:\n" .. df_desc_wrapped
        else
            ret[#ret + 1] = INDENT_STR .. "DEPRECATED:"
        end
    end

    if parent then
        ret[#ret + 1] = INDENT_STR .. "Extends: " .. parent
    end

    if desc then
        ret[#ret + 1] = wrap(md_to_vimdoc(desc), INDENT, INDENT, TEXT_WIDTH)
    end

    return table.concat(ret, "\n\n")
end

---------------------------
-- MARK: Brief Rendering --
---------------------------

---@param brief docgen.ParserObj
---@return string
local function render_brief(brief)
    return wrap(md_to_vimdoc(brief.desc or ""), 0, 0, TEXT_WIDTH)
end

---------------------------
-- MARK: Class Rendering --
---------------------------

---@param class docgen.ParserObj
--- @return string
local function class_header_get(class)
    return header_create(str_surround(class.name, "{", "}"), INDENT, { class.tag })
end

--- @param class docgen.ParserObj
--- @return string?
local function fields_get(class)
    local ret = {}
    ret[#ret + 1] = INDENT_STR .. "Fields: ~"

    local fields = class.fields --[[@as (docgen.DocItem[])]]
    table.sort(fields, function(a, b)
        return a.name < b.name
    end)

    local max_name_width = list_fold(fields, 0, function(field, acc)
        return math.max(#field.name, acc)
    end) + 2 -- Since cbraces will be added.

    for _, field in ipairs(class.fields) do
        ret[#ret + 1] = arg_fmt(field, max_name_width)
    end

    return table.concat(ret, "\n")
end

--- @param class docgen.ParserObj
--- @return string|nil
local function class_render(class)
    local ret = {} --- @type string[]

    local header = class_header_get(class)
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

---@param fun docgen.ParserObj
---@return string
local function proto_params_get(fun)
    local params = fun.params
    if not params then
        return ""
    end

    local cbraced_params = list_map(list_copy(params), function(param)
        return str_surround(param.name, "{", "}")
    end)

    return table.concat(cbraced_params, ", ")
end

--- @param fun docgen.ParserObj
--- @return string
local function fun_header_get(fun)
    local namevar = fun.namevar
    local title_params = proto_params_get(fun)
    local title = string.format("%s(%s)", namevar, title_params)
    return header_create(title, #namevar, { fun.tag })
end

---@param fun docgen.ParserObj
---@return string?
local function see_get(fun)
    local see = fun.see
    if not (see and #see > 0) then
        return
    end

    local see_bullets = list_map(list_copy(see), function(s)
        return DBL_INDENT_STR .. "• " .. md_to_vimdoc(s)
    end)

    return INDENT_STR .. "See also: ~\n" .. table.concat(see_bullets, "\n")
end

---@param fun docgen.ParserObj
---@return string?
local function returns_get(fun)
    local returns = fun.returns
    local returns_count = returns and #returns or 0
    if returns_count == 0 then
        return
    end

    local ret = {} --- @type string[]
    local sub_header = returns_count > 1 and "Returns (multiple): ~" or "Returns: ~"
    ret[#ret + 1] = INDENT_STR .. sub_header

    local ret_inner = {} ---@type string[]
    for _, r in ipairs(fun.returns) do
        for _, inner_r in ipairs(r) do
            local typ = type_fmt_get_with_default(inner_r.type)
            local name = inner_r.name
            if name then
                ret_inner[#ret_inner + 1] = typ .. " " .. str_surround(name, "{", "}")
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
    end

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
    local overloads = fun.overloads
    if not (overloads and #overloads > 0) then
        return
    end

    local overload_bullets = list_copy(overloads)
    list_map(overload_bullets, function(overload)
        return DBL_INDENT_STR .. "• " .. md_to_vimdoc(overload)
    end)

    return INDENT_STR .. "Overloads: ~\n" .. table.concat(overload_bullets, "\n")
end

--- @param fun docgen.ParserObj
--- @return string?
local function attributes_get(fun)
    if fun.async_flag ~= true then
        return
    end

    return INDENT_STR .. "Attributes: ~\n" .. DBL_INDENT_STR .. "• {async}"
end

--- @param fun docgen.ParserObj
--- @return string?
local function params_get(fun)
    local params = fun.params
    if not (params and #params > 0) then
        return
    end

    local max_name_width = list_fold(params, 0, function(param, acc)
        return math.max(#param.name, acc)
    end) + 2 -- To account for cbraces

    local ret = {}
    ret[#ret + 1] = INDENT_STR .. "Parameters: ~"

    for _, param in ipairs(fun.params) do
        ret[#ret + 1] = arg_fmt(param, max_name_width)
    end

    return table.concat(ret, "\n")
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
function M.render_docs(parsed_sources)
    local sections = {} --- @type table<string,docgen.Section>

    for _, source in ipairs(parsed_sources) do
        local source_name = source[1]
        log("    Rendering source:" .. source_name)
        -- TODO: Not relevant if the source is not a filename
        local basename = vim.fs.basename(source_name)

        local source_objs = source[2]
        local rendered = {} ---@type string[]
        for _, obj in ipairs(source_objs) do
            if obj.kind == "fun" then
                rendered[#rendered + 1] = render_fun(obj)
            elseif obj.kind == "class" then
                rendered[#rendered + 1] = class_render(obj)
            elseif obj.kind == "brief" then
                rendered[#rendered + 1] = render_brief(obj)
            end
        end

        sections[#sections + 1] = section_create(basename, rendered)
    end

    local docs = {} --- @type string[]
    for _, section in ipairs(sections) do
        log(string.format("    Rendering section: '%s'", section.title))
        docs[#docs + 1] = section_render(section, true)
    end

    -- The trailing newline is required by the vimdoc spec.
    local ml = string.format("\n vim:tw=78:ts=8:sw=%d:sts=%d:et:ft=help:norl:\n", INDENT, INDENT)
    table.insert(docs, ml)

    return table.concat(docs, "\n\n")
end

return M

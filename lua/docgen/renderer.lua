-- Forked version of the Neovim core docgen.

local fs = vim.fs

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
local type_fmt_get_with_default = util.type_fmt_get_with_default
local wrap = util.wrap

local const = require("docgen.const")
local INDENT = const.INDENT
local INDENT_STR = const.INDENT_STR
local DBL_INDENT = const.DBL_INDENT
local DBL_INDENT_STR = const.DBL_INDENT_STR
local TPL_INDENT = const.TPL_INDENT
local TEXT_WIDTH = const.TEXT_WIDTH

---------------
-- MARK: Common
---------------

---@param title string If `sep` is present, Title Cased based on `-` separators
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
        local tags_len_minus_one = #tags - 1
        for i = 1, tags_len_minus_one do
            ret[#ret + 1] = str_lpad(str_surround(tags[i], "*"), " ", TEXT_WIDTH)
        end
    end

    local tag_fmt = (tags and #tags > 0) and str_surround(tags[#tags], "*") or ""
    local title_fmt = title
    if sep then
        title_fmt = str_op_by_sep(title, "-", function(part)
            return string.upper(string.sub(part, 1, 1)) .. string.sub(part, 2)
        end)
    end

    local title_len = #title_fmt
    local tag_len = #tag_fmt
    local content_width = title_len + tag_len
    if content_width <= TEXT_WIDTH - DBL_INDENT then
        ret[#ret + 1] = title_fmt .. string.rep(" ", TEXT_WIDTH - content_width) .. tag_fmt
    else
        ret[#ret + 1] = str_lpad(tag_fmt, " ", TEXT_WIDTH)
        ret[#ret + 1] = wrap(title, 0, title_wrap, TEXT_WIDTH)
    end

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

---@param arg docgen.DocItem
---@param max_name_width integer
---@return string
local function arg_mapper(arg, max_name_width)
    local ret = {}
    ret[#ret + 1] = "• "

    local name_cbraced = rpad(str_surround(arg.name, "{", "}"), " ", max_name_width)
    ret[#ret + 1] = name_cbraced
    ret[#ret + 1] = " "

    local typ = type_fmt_get_with_default(arg.type, arg.default)
    ret[#ret + 1] = typ

    if arg.desc then
        if TEXT_WIDTH - #name_cbraced - #typ - DBL_INDENT > 0 then
            ret[#ret + 1] = "\n"
        else
            ret[#ret + 1] = ": "
        end

        ret[#ret + 1] = arg.desc
    end

    local arg_fmt = md_to_vimdoc(table.concat(ret))
    return wrap(arg_fmt, DBL_INDENT, TPL_INDENT, TEXT_WIDTH)
end

---------------
-- MARK: Briefs
---------------

---@param brief docgen.ParserObj
---@return string
local function render_brief(brief)
    return wrap(md_to_vimdoc(brief.desc or ""), 0, 0, TEXT_WIDTH)
end

----------------
-- MARK: Classes
----------------

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
        ret[#ret + 1] = arg_mapper(field, max_name_width)
    end

    return table.concat(ret, "\n")
end

--- @param class docgen.ParserObj
--- @return string|nil
local function class_render(class)
    local ret = {} --- @type string[]

    local name_cbraced = str_surround(class.name, "{", "}")
    local header = header_create(name_cbraced, INDENT, { class.tag })
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
    local title = string.format("%s(%s)", namevar, proto_params_get(fun))
    return header_create(title, #namevar, { fun.tag })
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
        ret[#ret + 1] = arg_mapper(param, max_name_width)
    end

    return table.concat(ret, "\n")
end

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

---@param fun docgen.ParserObj
---@return string?
local function returns_get(fun)
    local returns = fun.returns
    if not returns then
        return
    end

    local ret = {} --- @type string[]
    local sub_header = #returns > 1 and "Returns (multiple): ~" or "Returns: ~"
    ret[#ret + 1] = INDENT_STR .. sub_header

    for _, r in ipairs(fun.returns) do
        local typs_tbl = {}
        local typs_len = 0
        local typ_sep = ", "

        for _, inner_r in ipairs(r) do
            local typ = type_fmt_get_with_default(inner_r.type)
            local name = inner_r.name
            if name then
                local typ_name = typ .. " " .. str_surround(name, "{", "}")
                typs_len = typs_len + #typ_name
                typs_tbl[#typs_tbl + 1] = typ_name
            else
                typs_len = typs_len + #typ
                typs_tbl[#typs_tbl + 1] = typ
            end
        end

        if #typs_tbl > 1 then
            typs_len = typs_len + ((#typs_tbl - 1) * #typ_sep)
        end

        -- TODO: multiple issues

        local typ_str
        local desc_sep
        if TEXT_WIDTH - typs_len - TPL_INDENT - TPL_INDENT >= 0 then
            desc_sep = ": "
        else
            typ_sep = "\n"
            desc_sep = "\n"
            list_map(typs_tbl, function(typ)
                return DBL_INDENT_STR .. typ
            end)
        end

        typ_str = table.concat(typs_tbl, typ_sep)
        local desc = r.desc
        if desc then
            local desc_indent = desc_sep == ": " and 0 or DBL_INDENT
            local desc_prepended = (desc_sep == "\n" and "• " or "") .. desc
            local desc_wrapped =
                wrap(md_to_vimdoc(desc_prepended), desc_indent, TPL_INDENT, TEXT_WIDTH)
            ret[#ret + 1] = typ_str .. desc_sep .. desc_wrapped
        end
    end

    return table.concat(ret, "\n")
end

---@param fun docgen.ParserObj
---@return string?
local function see_get(fun)
    local see = fun.see
    if not (see and #see > 0) then
        return
    end

    local see_bullets = list_map(list_copy(see), function(s)
        local s_wrapped = wrap(md_to_vimdoc(s), 0, INDENT, TEXT_WIDTH)
        return DBL_INDENT_STR .. "• " .. s_wrapped
    end)

    return INDENT_STR .. "See also: ~\n" .. table.concat(see_bullets, "\n")
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
    local sections = {} --- @type string[]
    for _, source in ipairs(parsed_sources) do
        local source_name = source[1]
        log("    Rendering source:" .. source_name)

        -- TODO: Not relevant if the source is not a filename
        local basename = fs.basename(source_name)
        local rendered = {} ---@type string[]
        rendered[#rendered + 1] = header_create(basename, 0, { basename }, "=")

        for _, obj in ipairs(source[2]) do
            if obj.kind == "fun" then
                rendered[#rendered + 1] = render_fun(obj)
            elseif obj.kind == "class" then
                rendered[#rendered + 1] = class_render(obj)
            elseif obj.kind == "brief" then
                rendered[#rendered + 1] = render_brief(obj)
            end
        end

        sections[#sections + 1] = table.concat(rendered, "\n\n")
    end

    -- The trailing newline is required by the vimdoc spec.
    local ml = string.format("\n vim:tw=78:ts=8:sw=%d:sts=%d:et:ft=help:norl:\n", INDENT, INDENT)
    sections[#sections + 1] = ml
    return table.concat(sections, "\n\n")
end

return M

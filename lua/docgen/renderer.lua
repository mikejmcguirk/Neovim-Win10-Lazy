local ts_parsing = require("docgen.ts_parsing")
local md_to_vimdoc = ts_parsing.luacats_md_to_vimdoc

local util = require("docgen.util")
local table_filter = util.table_filter
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

--- @param section nvim.gen_vimdoc.Section
--- @param add_header? boolean
local function render_section(section, add_header)
    if not section.title then
        local fmt_str = "section.title is nil, check section_fmt(). section: %s"
        error(string.format(fmt_str, vim.inspect(section)))
    end

    local ret = {} --- @type string[]

    if add_header ~= false then
        local border = string.rep("=", TEXT_WIDTH) .. "\n"
        ret[#ret + 1] = border
        local rem_whitespace = TEXT_WIDTH - #section.title
        local help_tag = string.format("%" .. rem_whitespace .. "s", section.help_tag)
        vim.list_extend(ret, { section.title, help_tag })
    end

    local briefs = section.briefs
    local len_briefs = briefs and #section.briefs or 0
    if len_briefs > 0 then
        local briefs_txt = {} --- @type string[]
        for i = 1, len_briefs do
            local pretty_brief = briefs[i]:get_fmt_brief()
            briefs_txt[#briefs_txt + 1] = wrap(pretty_brief, 0, 0, TEXT_WIDTH)
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

---@param tag string
---@return string
local function get_fmt_lone_tag(tag)
    return string.format("%" .. TEXT_WIDTH .. "s", tag)
end
-- FUTURE: This works for multi-tagging. Each object would have a list of tags associated with it.
-- The tags would display, right-justified, in alphabetical order. Most would just use
-- `get_fmt_lone_tag()` to display, and the last would use `get_fmt_header()`.

---@param header string
---@param tag string
---@param wrap_indent integer
---@return string
local function get_fmt_header(header, tag, wrap_indent)
    local len_header = #header
    local len_tag = #tag

    if len_header + len_tag <= TEXT_WIDTH - DBL_INDENT then
        local padding = TEXT_WIDTH - len_header - len_tag
        return header .. string.rep(" ", padding) .. tag
    end

    header = wrap(header, 0, wrap_indent, TEXT_WIDTH)
    return get_fmt_lone_tag(tag) .. "\n" .. header
end

--- @class nvim.gen_vimdoc.Section
--- @field name string
--- @field title string
--- @field help_tag string
--- @field funs_txt string
--- @field classes_txt string
--- @field briefs docgen.ParserObj[]

--- @param filename string
--- @param briefs string[]
--- @param funs_txt string
--- @param classes_txt string
--- @param help_prefix string
--- @return nvim.gen_vimdoc.Section?
local function make_section(filename, briefs, funs_txt, classes_txt, help_prefix)
    if funs_txt == "" and classes_txt == "" and #briefs == 0 then
        return
    end

    -- TODO: I think this is the right baseline behavior. Since the names should be filename
    -- based, they should be lowercase. And then we have a camel/snake case title that looks
    -- more appealing.
    local name = filename:match("(.*)%.[a-z]+")

    local help_labels = help_prefix .. "-" .. name
    if type(help_labels) == "table" then
        help_labels = table.concat(help_labels, "* *")
    end

    local help_tags = "*" .. help_labels .. "*"
    local sectname = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)

    return {
        name = sectname,
        title = sectname,
        help_tag = help_tags,
        funs_txt = funs_txt,
        classes_txt = classes_txt,
        briefs = briefs,
    }
end

---@param name string
---@param typ string
---@param desc string
---@return string
local function fmt_fp_mapper(name, typ, desc)
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
-- LOW: It would be better if this function did not emphasize readability so heavily to the
-- detriment of performance.

---------------------------
-- MARK: Class Rendering --
---------------------------

---@param class docgen.ParserObj
---@param help_prefix string
--- @return string
local function get_class_header(class, help_prefix)
    local display_name = "{" .. class:get_name() .. "}"
    local tag = "*" .. class:get_name_as_helptag(help_prefix) .. "*"

    return get_fmt_header(display_name, tag, INDENT)
end
-- MAYBE: The literal class name might be fine since that's how it shows up when you dot-complete
-- the annotation.

--- @param class docgen.ParserObj
--- @param help_prefix string
--- @return string?
local function get_fields(class, help_prefix)
    if not class:has_fields() then
        return
    end

    local header = INDENT_STR .. "Fields: ~\n"
    local fmt_fields = class:map_fmt_fields(help_prefix, fmt_fp_mapper)
    return header .. table.concat(fmt_fields, "\n")
end

--- @param class docgen.ParserObj
---@param help_prefix string
--- @return string|nil
local function render_class(class, help_prefix)
    local ret = {} --- @type string[]

    -- TODO: Hacky
    local heading = {}
    heading[#heading + 1] = get_class_header(class, help_prefix)
    local parent = class:get_parent()
    if parent then
        local txt = "Extends: |" .. parent .. "|"
        heading[#heading + 1] = wrap(md_to_vimdoc(txt), INDENT, INDENT, TEXT_WIDTH)
        heading[#heading + 1] = "\n"
    end

    local fmt_desc = class:get_fmt_desc()
    if fmt_desc then
        heading[#heading + 1] = wrap(fmt_desc, INDENT, INDENT, TEXT_WIDTH)
    end

    ret[#ret + 1] = table.concat(heading, "\n")
    ret[#ret + 1] = get_fields(class, help_prefix)
    return table.concat(ret, "\n\n")
end

--- @param classes table<string,docgen.ParserObj>
--- @return string
local function render_classes(classes, help_prefix)
    local ret = {} --- @type string[]
    for _, class in vim.spairs(classes) do
        ret[#ret + 1] = render_class(class, help_prefix)
    end

    return table.concat(ret, "\n\n")
end
-- TODO: Keep spairs for now but I'm not sure it survives the module based re-organization

------------------------------
-- MARK: Function Rendering --
------------------------------

--- @param fun docgen.ParserObj
--- @param help_prefix string
--- @return string
local function get_fun_header(fun, help_prefix)
    local name = assert(fun:get_fmt_fun_name())
    local param_list = fun:get_fmt_params(0)
    local param_str = param_list and table.concat(param_list, ", ") or ""
    local full_proto = string.format("%s(%s)", name, param_str)

    local tag = "*" .. fun:get_name_as_helptag(help_prefix) .. "*"
    return get_fmt_header(full_proto, tag, #name)
end

---@param fun docgen.ParserObj
---@return string?
local function get_see(fun)
    local fmt_see = fun:get_fmt_see()
    if not fmt_see then
        return
    end

    local header = "See also: ~\n"
    return header .. wrap(fmt_see, 0, 0, TEXT_WIDTH)
end

---@param fun docgen.ParserObj
---@return string?
local function get_returns(fun)
    local len_returns = fun:get_count_returns()
    if len_returns < 1 then
        return
    end

    local lines = {} --- @type string[]
    local header = len_returns > 1 and "Returns (multiple): ~" or "Returns: ~"
    lines[#lines + 1] = INDENT_STR .. header

    local fmt_returns = fun:get_fmt_returns()
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
    local fmt_overloads = fun:get_fmt_overloads()
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
    if not fun:has_params() then
        return
    end

    local header = INDENT_STR .. "Parameters: ~\n"
    return header .. table.concat(fun:map_fmt_params(fmt_fp_mapper), "\n")
end

--- @param fun docgen.ParserObj
--- @param help_prefix string
--- @return string
local function render_fun(fun, help_prefix)
    local ret = {} ---@type string[]

    -- TODO: Hacky
    local header = get_fun_header(fun, help_prefix)
    local fmt_desc = fun:get_fmt_desc()
    if fmt_desc then
        ret[#ret + 1] = header .. "\n" .. wrap(fmt_desc, INDENT, INDENT, TEXT_WIDTH)
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

--- @param funs docgen.ParserObj[]
--- @param help_prefix string
--- @return string
local function render_funs(funs, help_prefix)
    -- NON: Don't fix this, it will be gone
    table.sort(funs, function(a, b)
        ---@diagnostic disable-next-line: invisible
        local key_a = a.classvar and (a.classvar .. ":" .. a.name) or a.name or ""
        ---@diagnostic disable-next-line: invisible
        local key_b = b.classvar and (b.classvar .. ":" .. b.name) or b.name or ""
        return key_a:lower() < key_b:lower()
    end)

    local all_lines = {} --- @type string[]
    local len_funs = #funs
    for i = 1, len_funs do
        all_lines[#all_lines + 1] = render_fun(funs[i], help_prefix)
    end

    return table.concat(all_lines, "\n\n")
end

---@param file_results table<string,[table<string,docgen.ParserObj>, docgen.ParserObj[], docgen.ParserObj[]]>
---@return table<string,docgen.ParserObj>
local function create_all_classes(file_results)
    local all_classes = {}
    for _, result in pairs(file_results) do
        local classes = result[1]
        for name, class in pairs(classes) do
            local has_class = all_classes[name] ~= nil
            if has_class then
                error("Duplicate class definition " .. name)
            end

            all_classes[name] = class
        end
    end

    return all_classes
end

---@param file_results table<string,[table<string,docgen.ParserObj>, docgen.ParserObj[], docgen.ParserObj[]]>
---@param all_classes table<string,docgen.ParserObj>
local function apply_all_classes(file_results, all_classes)
    -- TODO: I am unclear what this code is doing. In general, it seems like it's looking for
    -- @field definitions that are already existing functions, and removing the field definitions,
    -- since the function definition will render later. But why does that only apply to module
    -- functions?
    local hidden_fields = {} --- @type table<string,table<string,true>>
    for _, result in pairs(file_results) do
        local funs = result[2]
        local len_funs = #funs
        for i = 1, len_funs do
            local fun = funs[i]
            local fun_class = fun:get_class()
            if fun:is_module_fun() and fun_class then
                hidden_fields[fun_class] = hidden_fields[fun_class] or {}
                hidden_fields[fun_class][fun:get_name()] = true
            end
        end
    end

    for _, class in pairs(all_classes) do
        local class_hidden = hidden_fields[class]
        if class_hidden then
            class:filter_fields(function(field)
                return not class_hidden[field.name]
            end)
        end
    end

    for _, result in pairs(file_results) do
        local classes = result[1]
        for _, class in pairs(classes) do
            class:update_fps_with_class_info(all_classes)
        end
    end

    for _, result in pairs(file_results) do
        local funs = result[2]
        local len_funs = #funs
        for i = 1, len_funs do
            funs[i]:update_fps_with_class_info(all_classes)
        end
    end

    for _, file_res in pairs(file_results) do
        table_filter(file_res[1], function(_, class_obj)
            return class_obj:has_fields() and class_obj:is_visible()
        end)
    end

    table_filter(all_classes, function(_, class_obj)
        return class_obj:has_fields() and class_obj:is_visible()
    end)
end
-- TODO: Broadly, this group filtering is fine. But the overall method will change when
-- sequential rendering is introduced. When architecting that, I would like to make this
-- process less clunky.
-- TODO: This violates the function contract by editing the parser objects at the rendering step.
-- Needs to be refactored somewhere else.

-----------------------------------
-- MARK: Main rendering function --
-----------------------------------

local M = {}

---@param inputs string[]
---@param output_path string
function M.render_docs(inputs, output_path)
    --- @type table<string,[table<string,docgen.ParserObj>, docgen.ParserObj[], docgen.ParserObj[]]>
    local file_results = {}
    local parse = require("docgen.luacats_parser").parse
    for _, input in vim.spairs(inputs) do
        local classes, funs, briefs = parse(input)
        file_results[input] = { classes, funs, briefs }
    end

    -- TODO: This needs to come in somehow through input. Definitely through CLI, and I'm still
    -- debating on how sophisticated the public function should be.
    -- TODO: Try to keep this free of requiring a separator character at the end. The hope is
    -- that you can do something smarter with it. In theory, your help prefix would match
    -- the require name, so if you pulled docs on the init file, it would see that the name
    -- matches the helptag prefix, and you just get nice looking dot function names. But then
    -- for topics, it would append a dash.
    -- TODO: When @tag is introduced, the docgen needs to be able to use vim.startswith to see
    -- if the tag starts with the prefix. Or maybe a bespoke function since startswith doesn't
    -- let you specify the starting index if the doc's tag starts with a * character
    --
    -- TODO: In preparation for @tag, we will go ahead now and prepare the data structures for it.
    -- We want to then have a list of tags in the function itself. We should pull them in as is,
    -- then have a separate looping step that only addresses removing bad ones.
    -- TODO: Could also get a default form the file/dir info
    local help_prefix = "demo-help"

    local all_classes = create_all_classes(file_results)
    apply_all_classes(file_results, all_classes)
    -- TODO: I think you generate helptags here. We want to winnow out the stuff we don't need
    -- first, and we need a global view of helptags to verify no duplicates.
    -- Basically we pass prefix inside, build and store internally.
    -- We also want to create building logic that is default useful.
    -- - Prefix: First init.lua or first file. Also establishes root?
    -- - File: The file being pulled from (probably not modvar)
    -- - Item: function/class
    -- We want to make the default process as logical as possible so that we aren't creating
    -- duplicates due to sloppiness, but we also aren't trying to save the user from illogical
    -- setups. After the defaults are added, will think about adding overrides.
    -- Should the seen map be passed by reference? Feels right since we can check before adding.
    -- We might consider saving intermediate data as well if it is useful
    -- Might just be a note for now, but this is also when we'd do fixup/validation on @tag items.

    local sections = {} --- @type table<string,nvim.gen_vimdoc.Section>
    for file, result in vim.spairs(file_results) do
        local classes, funs, briefs = result[1], result[2], result[3]

        for _, class in pairs(classes) do
            class:update_fps_with_class_info(all_classes)
        end

        for i = 1, #funs do
            funs[i]:update_fps_with_class_info(all_classes)
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

        local funs_txt = render_funs(funs, help_prefix)
        local classes_txt = render_classes(classes, help_prefix)
        sections[basename] = make_section(basename, briefs, funs_txt, classes_txt, help_prefix)
    end

    local docs = {} --- @type string[]
    for _, section in pairs(sections) do
        print(string.format("    Rendering section: '%s'", section.title))
        docs[#docs + 1] = render_section(section, true)
    end

    local ml = string.format("\n vim:tw=78:ts=8:sw=%d:sts=%d:et:ft=help:norl:\n", INDENT, INDENT)
    table.insert(docs, ml)

    print("Writing output")
    local fp = assert(io.open(output_path, "w"))
    fp:write(table.concat(docs, "\n"))
    fp:close()
end

return M

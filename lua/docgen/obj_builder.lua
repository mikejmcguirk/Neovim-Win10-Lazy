local table_new = require("docgen.util").table_new
local new_parser_obj = require("docgen.parser_obj").new

--- @class (exact) docgen.Builder
--- @field cur_obj? docgen.ParserObj
--- @field doc_lines? string[]
--- @field last_doc_item? docgen.DocItem
--- @field last_doc_item_indent? integer
---
---@field __index fun(self: docgen.ParserObj, key: any): val:any
---@field new fun(): parser_obj:docgen.Builder
local M = {}

---@generic T
---@param self docgen.Builder
---@param key T
---@return any
function M.__index(self, key)
    local val = rawget(self, key)
    return val or rawget(M, key)
end

---@return docgen.Builder
function M.new()
    return setmetatable(table_new(0, 4), M)
end

------------------------------
-- MARK: Add Parsed Results --
------------------------------

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_alias(self, parsed)
    self.cur_obj:alias_set(parsed)
end

---@param self docgen.Builder
local function add_parsed_async(self)
    self.cur_obj:async_set()
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_brief(self, parsed)
    self.cur_obj:brief_set(parsed)
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_class(self, parsed)
    self.cur_obj:class_set(parsed, self.doc_lines)
    self.doc_lines = nil
end

---@param self docgen.Builder
local function add_parsed_deprecate(self)
    self.cur_obj:deprecate_set()
end

---@param self docgen.Builder
local function add_parsed_enum(self)
    self.doc_lines = nil
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_field(self, parsed)
    self.cur_obj:class_add_field(parsed, self.doc_lines)
    self.doc_lines = nil
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_generic(self, parsed)
    self.cur_obj:generic_add(parsed)
end

---@param self docgen.Builder
local function add_parsed_inlinedoc(self)
    self.cur_obj:inlinedoc_set()
end

---@param self docgen.Builder
local function add_parsed_nodoc(self)
    self.cur_obj:nodoc_set()
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_note(self, parsed)
    self.last_doc_item_indent = nil
    self.last_doc_item = { desc = parsed.desc }

    self.cur_obj:note_add(self.last_doc_item)
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_operator(self, parsed)
    self.cur_obj:class_add_operator(parsed, self.doc_lines)
    self.doc_lines = nil
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_overload(self, parsed)
    self.cur_obj:overload_add(parsed)
end

---@param self docgen.Builder
local function add_parsed_package(self)
    self.cur_obj:package_set()
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_param(self, parsed)
    self.last_doc_item_indent = nil
    if vim.endswith(parsed.name, "?") then
        parsed.name = parsed.name:sub(1, -2)
        parsed.type = parsed.type .. "?"
    end

    self.last_doc_item = {
        name = parsed.name,
        type = parsed.type,
        desc = parsed.desc,
    }

    self.cur_obj = self.cur_obj or new_parser_obj()
    self.cur_obj:param_add(self.last_doc_item)
end
---@param self docgen.Builder
local function add_parsed_private(self)
    self.cur_obj = self.cur_obj or new_parser_obj()
    self.cur_obj:private_set()
end

---@param self docgen.Builder
local function add_parsed_protected(self)
    self.cur_obj = self.cur_obj or new_parser_obj()
    self.cur_obj:protected_set()
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_return(self, parsed)
    self.last_doc_item_indent = nil

    self.cur_obj = self.cur_obj or new_parser_obj()
    local cur_obj = self.cur_obj --[[@as docgen.ParserObj]]
    cur_obj:return_add(parsed)
    self.last_doc_item = cur_obj.returns[#cur_obj.returns]
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_see(self, parsed)
    self.cur_obj = self.cur_obj or new_parser_obj()
    self.cur_obj:see_add(parsed)
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_since(self, parsed)
    self.cur_obj = self.cur_obj or new_parser_obj()
    self.cur_obj:since_set(parsed)
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_type(self, parsed)
    self.cur_obj = self.cur_obj or new_parser_obj()
    self.cur_obj:type_set(parsed)
end

local transform = {
    ["alias"] = add_parsed_alias,
    ["async"] = add_parsed_async,
    ["brief"] = add_parsed_brief,
    ["class"] = add_parsed_class,
    ["deprecate"] = add_parsed_deprecate,
    ["enum"] = add_parsed_enum,
    ["field"] = add_parsed_field,
    ["generic"] = add_parsed_generic,
    ["inlinedoc"] = add_parsed_inlinedoc,
    ["nodoc"] = add_parsed_nodoc,
    ["note"] = add_parsed_note,
    ["operator"] = add_parsed_operator,
    ["overload"] = add_parsed_overload,
    ["package"] = add_parsed_package,
    ["param"] = add_parsed_param,
    ["private"] = add_parsed_private,
    ["protected"] = add_parsed_protected,
    ["return"] = add_parsed_return,
    ["see"] = add_parsed_see,
    ["since"] = add_parsed_since,
    ["type"] = add_parsed_type,
}

---@param parsed nvim.luacats.grammar.Result
function M:add_parsed_result(parsed)
    self.cur_obj = self.cur_obj or new_parser_obj()
    self.last_doc_item_indent = nil
    self.last_doc_item = nil

    local transform_fn = transform[parsed.kind]
    if transform_fn then
        transform_fn(self, parsed)
    end
end

---------------------------
-- MARK: Other Functions --
---------------------------

function M:reset()
    self.cur_obj = nil
    self.doc_lines = nil
    self.last_doc_item = nil
    self.last_doc_item_indent = nil
end

---@param line string
function M:handle_unparsed_line(line)
    if line:match("^ ") then
        line = line:sub(2)
    end

    if self.last_doc_item then
        if not self.last_doc_item_indent then
            self.last_doc_item_indent = #line:match("^%s*") + 1
        end
        self.last_doc_item.desc = (self.last_doc_item.desc or "")
            .. "\n"
            .. line:sub(self.last_doc_item_indent or 1)
    else
        self.doc_lines = self.doc_lines or {}
        local doc_lines = self.doc_lines
        doc_lines[#doc_lines + 1] = line
    end
end
-- TODO: Overly complicated indent handling.

------------------------
-- MARK: Finalization --
------------------------

function M:add_doc_lines_to_obj()
    if not self.doc_lines then
        return
    end

    self.cur_obj = self.cur_obj or new_parser_obj()
    local cur_obj = assert(self.cur_obj)
    local txt = table.concat(self.doc_lines, "\n")
    if cur_obj.desc then
        cur_obj.desc = cur_obj.desc .. "\n" .. txt
    else
        cur_obj.desc = txt
    end

    self.doc_lines = nil
end
-- TODO: dumb assert

--- @param fun docgen.ParserObj
--- @return nvim.luacats.parser.field
local function fun2field(fun)
    local parts = { "fun(" }

    local params = {} ---@type string[]
    for _, p in ipairs(fun.params or {}) do
        params[#params + 1] = string.format("%s: %s", p.name, p.type)
    end

    parts[#parts + 1] = table.concat(params, ", ")
    parts[#parts + 1] = ")"
    if fun.returns then
        parts[#parts + 1] = ": "
        local tys = {} --- @type string[]
        for _, p in ipairs(fun.returns) do
            tys[#tys + 1] = p.type
        end

        parts[#parts + 1] = table.concat(tys, ", ")
    end

    return {
        kind = "field",
        name = fun.name,
        type = table.concat(parts, ""),
        access = fun.access,
        desc = fun.desc,
        nodoc = fun.nodoc,
        classvar = fun.classvar,
    }
end

--- Function to normalize known form for declaring functions and normalize into a more standard
--- form.
--- @param line string
--- @return string
local function filter_decl(line)
    -- M.fun = vim._memoize(function(...)
    --   ->
    -- function M.fun(...)
    line = line:gsub("^local (.+) = memoize%([^,]+, function%((.*)%)$", "local function %1(%2)")
    line = line:gsub("^(.+) = memoize%([^,]+, function%((.*)%)$", "function %1(%2)")
    return line
end

--- @param line? string
--- @param classes table<string,docgen.ParserObj>
--- @param classvars table<string,string>
--- @return docgen.ParserObj?
function M:get_finalized_obj(line, classes, classvars)
    if not line then
        return self.cur_obj
    end

    line = filter_decl(line)

    if self.cur_obj and self.cur_obj.kind == "class" then
        local nm = line:match("^local%s+([a-zA-Z0-9_]+)%s*=")
        if nm then
            classvars[nm] = self.cur_obj.name
        end

        return self.cur_obj
    end

    do
        local parent_tbl, sep, fun_or_meth_nm =
            line:match("^function%s+([a-zA-Z0-9_]+)([.:])([a-zA-Z0-9_]+)%s*%(")
        if parent_tbl then
            -- Have a decl. Ensure cur_obj
            self.cur_obj = self.cur_obj or new_parser_obj()
            local cur_obj = assert(self.cur_obj)

            -- Match `Class:foo` methods for defined classes
            local class = classvars[parent_tbl]
            if class then
                cur_obj.name = fun_or_meth_nm
                cur_obj.class = class
                cur_obj.classvar = parent_tbl
                cur_obj.member_sep = sep
                -- Add self param to methods
                if sep == ":" then
                    cur_obj.params = cur_obj.params or {}
                    table.insert(cur_obj.params, 1, {
                        name = "self",
                        type = class,
                    })
                end

                table.insert(classes[class].fields, fun2field(cur_obj))
                return self.cur_obj
            end

            -- Match `M.foo`
            if cur_obj and parent_tbl == cur_obj.modvar then
                cur_obj.name = fun_or_meth_nm
                return self.cur_obj
            end
        end
    end

    do
        -- Handle: `function A.B.C.foo(...)`
        local fn_nm = line:match("^function%s+([.a-zA-Z0-9_]+)%s*%(")
        if fn_nm then
            self.cur_obj = self.cur_obj or new_parser_obj()
            self.cur_obj.name = fn_nm
            return self.cur_obj
        end
    end

    if self.cur_obj then
        if line:find("^%s*%-%- luacheck:") then
            self.cur_obj = nil
        elseif line:find("^%s*local%s+") then
            self.cur_obj = nil
        elseif line:find("^%s*return%s+") then
            self.cur_obj = nil
        elseif line:find("^%s*[a-zA-Z_.]+%(%s+") then
            self.cur_obj = nil
        end
    end

    return self.cur_obj
end
-- Should parse Lua Line be its own thing again, then just get the obj somehow else.

---@param modvar string?
---@param input string
function M:set_module_info(modvar, input)
    if not self.cur_obj then
        return self.cur_obj
    end

    self.cur_obj:set_module_info(modvar, input)
end

return M

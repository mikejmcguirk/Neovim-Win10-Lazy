local table_new = require("docgen.util").table_new
local new_parser_obj = require("docgen.parser_obj").new

--- @class (exact) docgen.Builder
--- @field cur_obj? docgen.ParserObj
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
    self.cur_obj:class_set(parsed)
end

---@param self docgen.Builder
local function add_parsed_deprecate(self)
    self.cur_obj:deprecate_set()
end

---@param self docgen.Builder
local function add_parsed_enum(self)
    self.cur_obj:doc_lines_clear()
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_field(self, parsed)
    self.cur_obj:class_add_field(parsed)
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
    self.cur_obj:note_add({ desc = parsed.desc })
end

---@param self docgen.Builder
---@param parsed nvim.luacats.grammar.Result
local function add_parsed_operator(self, parsed)
    self.cur_obj:class_add_operator(parsed)
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
    if string.byte(parsed.name, #parsed.name) == 63 then
        parsed.name = string.sub(parsed.name, 1, -2)
        parsed.type = parsed.type .. "?"
    end

    self.cur_obj = self.cur_obj or new_parser_obj()
    self.cur_obj:param_add({
        name = parsed.name,
        type = parsed.type,
        desc = parsed.desc,
    })
end
-- TODO: Why can't parser_obj just handle the Luacats result

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
    self.cur_obj = self.cur_obj or new_parser_obj()
    local cur_obj = self.cur_obj --[[@as docgen.ParserObj]]
    cur_obj:return_add(parsed)
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
end

---@param line string
function M:handle_unparsed_line(line)
    self.cur_obj = self.cur_obj or new_parser_obj()
    self.cur_obj:doc_lines_add(line)
end

------------------------
-- MARK: Finalization --
------------------------

--- @param line? string
--- @param classes table<string,docgen.ParserObj>
--- @param classvars table<string,string>
--- @return docgen.ParserObj?
function M:get_finalized_obj(line, classes, classvars)
    if
        line
        and (
            string.find(line, "^%s*local%s+")
            or string.find(line, "^%s*return%s+")
            or string.find(line, "^%s*%-%- luacheck:")
            or string.find(line, "^%s*[a-zA-Z_.]+%(%s+")
        )
    then
        self.cur_obj = nil
        return
    end

    local cur_obj = self.cur_obj
    if cur_obj then
        cur_obj:doc_lines_commit()
    end

    if not line then
        return cur_obj
    end

    if self.cur_obj then
        if self.cur_obj.kind == "class" then
            local name = line:match("^local%s+([a-zA-Z0-9_]+)%s*=")
            if name then
                classvars[name] = self.cur_obj.name
            end

            return self.cur_obj
        end
    end

    local parent_tbl, sep, fun_name =
        line:match("^function%s+([a-zA-Z0-9_]+)([.:])([a-zA-Z0-9_]+)%s*%(")
    if parent_tbl then
        self.cur_obj = self.cur_obj or new_parser_obj()
        cur_obj = assert(self.cur_obj)

        local class = classvars[parent_tbl]
        if class then
            cur_obj:class_fun_set(fun_name, class, parent_tbl, sep)
            classes[class]:class_add_field_from_fun(cur_obj)
            return self.cur_obj
        end

        if cur_obj and parent_tbl == cur_obj.modvar then
            cur_obj:fun_set_from_name(fun_name)
            return self.cur_obj
        end
    end

    local dot_fun_name = line:match("^function%s+([.a-zA-Z0-9_]+)%s*%(")
    if dot_fun_name then
        self.cur_obj = self.cur_obj or new_parser_obj()
        cur_obj = assert(self.cur_obj)
        cur_obj:fun_set_from_name(dot_fun_name)
        return cur_obj
    end

    return self.cur_obj
end
-- TODO: Doc lines should work such that, when you add one, the parser_obj checks its kind
-- and handles the doc line accordingly. So briefs and such would immediately commit the doc line,
-- whereas non-kinds would hold them. And then functions would consume the doc lines when the
-- type is set. This avoids the manual commit step and makes their purpose/usage more clear.

---@param modvar string?
---@param input string
function M:set_module_info(modvar, input)
    if not self.cur_obj then
        return self.cur_obj
    end

    self.cur_obj:set_module_info(modvar, input)
end

return M

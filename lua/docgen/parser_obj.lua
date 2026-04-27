--- @class docgen.DocItem
--- @field classvar? string
--- @field desc? string
--- @field name? string
--- @field type? string

---@class (exact) docgen.ParserObj
---@field attrs? string[]
---@field async? boolean
---@field access? 'private'|'protected'|'package'
---@field class? string
---@field classvar? string
---@field deprecated? boolean
---@field desc? string
---@field fields? nvim.luacats.grammar.Result[]
---@field generics? string[]
---@field inlinedoc? boolean
---@field kind? "alias"|"brief"|"class"
---@field member_sep? '.'|':'
---@field module? string
---@field modvar? string
---@field name? string
---@field nodoc? boolean
---@field notes? docgen.DocItem[]
---@field overloads? string[]
---@field params? docgen.DocItem[]
---@field parent? string
---@field returns? docgen.DocItem[]
---@field see? docgen.DocItem[]
---@field since? string
---@field is_table? boolean
---@field type? nvim.luacats.grammar.Result
---
---@field __index fun(self: docgen.ParserObj, key: any): val:any
---@field new fun(): parser_obj:docgen.ParserObj
local M = {}

---@generic T
---@param self docgen.ParserObj
---@param key T
---@return any
function M.__index(self, key)
    local val = rawget(self, key)
    return val or rawget(M, key)
end

local table_new = require("table.new")

---@return docgen.ParserObj
function M.new()
    return setmetatable(table_new(0, 22), M)
end

function M:clear()
    self.async = nil
    self.access = nil
    self.class = nil
    self.classvar = nil
    self.deprecated = nil
    self.desc = nil
    self.fields = nil
    self.generics = nil
    self.inlinedoc = nil
    self.kind = nil
    self.member_sep = nil
    self.name = nil
    self.nodoc = nil
    self.notes = nil
    self.overloads = nil
    self.params = nil
    self.parent = nil
    self.returns = nil
    self.see = nil
    self.since = nil
    self["is_table"] = nil
    self.type = nil
end

----------------------
-- MARK: Alias Info --
----------------------

function M:alias_set(parsed)
    self:clear()
    self.kind = "alias"
    self.desc = parsed.desc
end

----------------------
-- MARK: Brief Info --
----------------------

---@param parsed nvim.luacats.grammar.Result
function M:brief_set(parsed)
    self:clear()
    self.kind = "brief"
    self.desc = parsed.desc
end

----------------------
-- MARK: Class Info --
----------------------

---@param parsed nvim.luacats.grammar.Result
---@param doc_lines? string[]
function M:class_set(parsed, doc_lines)
    self:clear()

    self.kind = "class"
    self.name = parsed.name
    self.parent = parsed.parent
    self.access = parsed.access

    self.desc = doc_lines and table.concat(doc_lines, "\n") or nil
    self.fields = {}
end

---@param parsed nvim.luacats.grammar.Result
---@param doc_lines? string[]
function M:class_add_field(parsed, doc_lines)
    if self.kind ~= "class" then
        -- TODO: Improve
        error("Cannot add a field to a non-class object")
    end

    parsed.desc = (parsed.desc and parsed.desc ~= "") and parsed.desc or nil
    parsed.desc = parsed.desc or doc_lines and table.concat(doc_lines, "\n") or nil
    parsed.desc = parsed.desc and vim.trim(parsed.desc) or nil

    local fields = self.fields
    fields[#fields + 1] = parsed
end

---@param parsed nvim.luacats.grammar.Result
---@param doc_lines? string[]
function M:class_add_operator(parsed, doc_lines)
    if self.kind ~= "class" then
        -- TODO: Improve
        error("Cannot add an operator to a non-class object")
    end

    -- MID: Why isn't desc == "" checked here like in field?
    parsed.desc = parsed.desc or doc_lines and table.concat(doc_lines, "\n") or nil
    parsed.desc = parsed.desc and vim.trim(parsed.desc) or nil

    local fields = self.fields
    fields[#fields + 1] = parsed
end

-------------------------
-- MARK: Function Info --
-------------------------

function M:async_set()
    self.async = true
end

function M:generic_add(parsed)
    self.generics = self.generics or {}
    local generics = self.generics
    generics[#generics + 1] = parsed.type or "any"
end

---@param parsed nvim.luacats.grammar.Result
function M:overload_add(parsed)
    self.overloads = self.overloads or {}
    local overloads = self.overloads
    overloads[#overloads + 1] = parsed.type
end

---@param doc_item docgen.DocItem
function M:param_add(doc_item)
    self.params = self.params or {}
    local params = self.params
    params[#params + 1] = doc_item
end

---@param parsed nvim.luacats.grammar.Result
function M:return_add(parsed)
    self.returns = self.returns or {}
    local returns = self.returns
    for _, t in ipairs(parsed) do
        returns[#returns + 1] = {
            name = t.name,
            type = t.type,
            desc = parsed.desc,
        }
    end
end

----------------------------
-- MARK: Access Modifiers --
----------------------------

function M:private_set()
    self.access = "private"
end

function M:package_set()
    self.access = "package"
end

function M:protected_set()
    self.access = "protected"
end

---------------------
-- MARK: Doc Style --
---------------------

function M:deprecate_set()
    self.deprecated = true
end

function M:inlinedoc_set()
    self.inlinedoc = true
end

function M:nodoc_set()
    self.nodoc = true
end

----------------
-- MARK: Misc --
----------------

---@param doc_item docgen.DocItem
function M:note_add(doc_item)
    self.notes = self.notes or {}
    local notes = self.notes
    notes[#notes + 1] = doc_item
end
-- TODO: State also does bookkeeping here

---@param parsed nvim.luacats.grammar.Result
function M:since_set(parsed)
    self.since = parsed.desc
end

---@param parsed nvim.luacats.grammar.Result
function M:see_add(parsed)
    self.see = self.see or {}
    local see = self.see
    see[#see + 1] = { desc = parsed.desc }
end

---@param parsed nvim.luacats.grammar.Result
function M:type_set(parsed)
    self.desc = parsed.desc
    self.type = parsed
end

---@param modvar string?
---@param input string
function M:set_module_info(modvar, input)
    self.modvar = modvar

    --- @type string
    local module = input:match(".*/lua/([a-z_][a-z0-9_/]+)%.lua") or input
    module = module:gsub("/", ".")
    self.module = module
end

return M

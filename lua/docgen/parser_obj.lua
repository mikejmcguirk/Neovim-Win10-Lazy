local table_new = require("docgen.util").table_new

--- @class docgen.DocItem : nvim.luacats.grammar.Result
--- @field classvar? string

---@class (exact) docgen.ParserObj
---@field attrs? string[]
---@field async? boolean
---@field access? 'private'|'protected'|'package'
---@field class? string
---@field classvar? string
---@field deprecated? boolean
---@field doc_lines? string[] Uncommitted doc lines
---@field desc? string
---@field fields? docgen.DocItem[]
---@field generics? string[]
---@field inlinedoc? boolean
---@field kind? "alias"|"brief"|"class"|"fun"
---@field member_sep? '.'|':'
---@field module? string
---@field modvar? string
---@field name? string
---@field nodoc? boolean
---@field notes? string[]
---@field overloads? string[]
---@field params? docgen.DocItem[]
---@field parent? string
---@field returns? docgen.DocItem[]
---@field see? string[]
---@field since? string
---@field type? docgen.DocItem
---
---@field __index fun(self:docgen.ParserObj, key:any): val:any
---@field new fun(modvar:string, fname:string): parser_obj:docgen.ParserObj
local M = {}

---@generic T
---@param self docgen.ParserObj
---@param key T
---@return any
function M.__index(self, key)
    local val = rawget(self, key)
    return val or rawget(M, key)
end

---@param modvar string
---@param fname string
---@return docgen.ParserObj
function M.new(modvar, fname)
    local obj = setmetatable(table_new(0, 22), M)
    rawset(obj, "modvar", modvar)

    --- @type string
    local module = fname:match(".*/lua/([a-z_][a-z0-9_/]+)%.lua") or fname
    module = module:gsub("/", ".")
    rawset(obj, "module", module)

    return obj
end
-- TODO: Unsure what to do here. If the obj is invalid, we don't need this. But there's not really
-- a better place to put it. It's hard to delay without making the finalization logic contrived.

---@param self docgen.ParserObj
local function clear_for_alias_class(self)
    self.async = nil
    self.class = nil
    self.classvar = nil
    self.desc = nil
    self.fields = nil
    self.kind = nil
    self.member_sep = nil
    self.name = nil
    self.notes = nil
    self.overloads = nil
    self.params = nil
    self.parent = nil
    self.returns = nil
    self.see = nil
    self.since = nil
    self.type = nil
end
-- TODO: localize this. Don't leave a public version because I'm not sure there's a reason why
-- external collers should be manually clearing

function M:clear_for_alias()
    clear_for_alias_class(self)
end

function M:clear_for_class()
    clear_for_alias_class(self)
    self.access = nil
end
-- TODO: localize this. Don't leave a public version because I'm not sure there's a reason why
-- external collers should be manually clearing

function M:clear_all()
    clear_for_alias_class(self)
    self:clear_for_class()

    self.deprecated = nil
    self.doc_lines = nil
    self.generics = nil
    self.nodoc = nil
    self.inlinedoc = nil
end
-- TODO: localize this. Don't leave a public version because I'm not sure there's a reason why
-- external collers should be manually clearing

---@param self docgen.ParserObj
---@param kind string
local function assert_no_kind(self, kind)
    local msg = "Cannot set " .. kind .. ". Kind is already " .. tostring(self.kind)
    assert(not self.kind, msg)
end

----------------------
-- MARK: Alias Info --
----------------------

---@param parsed nvim.luacats.grammar.Result
function M:alias_set(parsed)
    local kind = "alias"
    assert_no_kind(self, kind)
    self:clear_for_alias()

    self.kind = kind
    self.desc = parsed.desc
end
-- TODO: Make these render
-- Blocker: Ordered rendering is not done
-- Lua_Ls only shows what appears above the alias, we should do the same. I think parsed.desc
-- contains the actual alias name/type but need to confirm.
-- Doclines after should reject and emit warnings
-- Should support inlinedoc
-- Unsure about generics
-- Unsure about deprecation
-- Should obviously support nodoc

----------------------
-- MARK: Brief Info --
----------------------

---@param parsed nvim.luacats.grammar.Result
function M:brief_set(parsed)
    local kind = "brief"
    assert_no_kind(self, kind)
    self:clear_all()

    self.kind = kind
    self.desc = parsed.desc
end
-- TODO: Should emit a warning if doc_lines already has data.

----------------------
-- MARK: Class Info --
----------------------

---@param parsed nvim.luacats.grammar.Result
function M:class_set(parsed)
    local kind = "class"
    assert_no_kind(self, kind)
    self:clear_for_class()

    self.kind = kind
    self.name = parsed.name
    self.parent = parsed.parent
    self.access = parsed.access

    local doc_lines = self.doc_lines
    self.desc = doc_lines and table.concat(doc_lines, "\n") or nil
    self.fields = {}
end
-- MAYBE: Lua_Ls does not show any description on the class definition line. I'm not sure if
-- the LuaCATs grammar pulls it. If emmylua_ls shows it, perhaps could add to here. Same
-- possibility applies to @alias as well.

---@param parsed nvim.luacats.grammar.Result
function M:class_add_field(parsed)
    if self.kind ~= "class" then
        -- TODO: Improve
        error("Cannot add a field to a non-class object")
    end

    parsed.desc = (parsed.desc and parsed.desc ~= "") and parsed.desc or nil
    local doc_lines = self.doc_lines
    parsed.desc = parsed.desc or doc_lines and table.concat(doc_lines, "\n") or nil
    parsed.desc = parsed.desc and vim.trim(parsed.desc) or nil

    local fields = self.fields
    fields[#fields + 1] = parsed --[[@as docgen.DocItem]]
    self.doc_lines = nil
end
-- TODO: Having parsed.desc override doc_lines is unnecessary and confusing. Show both. It is up
-- to the user to document appropriately.

--- @param fun docgen.ParserObj
function M:class_add_field_from_fun(fun)
    assert(fun.kind == "fun", "fun.kind is not 'fun' " .. fun.kind)

    local type_tbl = { "fun(" }

    local fun_params = fun.params
    if fun_params then
        local params = {} ---@type string[]
        local len_fun_params = #fun_params
        for i = 1, len_fun_params do
            local p = fun_params[i]
            params[#params + 1] = string.format("%s: %s", p.name, p.type)
        end

        type_tbl[#type_tbl + 1] = table.concat(params, ", ")
    end

    type_tbl[#type_tbl + 1] = ")"

    local fun_returns = fun.returns
    if fun_returns then
        type_tbl[#type_tbl + 1] = ": "
        local fun_ret_types = {} --- @type string[]
        local len_fun_returns = #fun_returns
        for i = 1, len_fun_returns do
            fun_ret_types[#fun_ret_types + 1] = fun_returns[i].type
            type_tbl[#type_tbl + 1] = table.concat(fun_ret_types, ", ")
        end
    end

    local fields = self.fields
    fields[#fields + 1] = {
        kind = "field",
        name = fun.name,
        type = table.concat(type_tbl, ""),
        access = fun.access,
        desc = fun.desc,
        nodoc = fun.nodoc,
        classvar = fun.classvar,
    }
end

---@param parsed nvim.luacats.grammar.Result
function M:class_add_operator(parsed)
    if self.kind ~= "class" then
        -- TODO: Improve
        error("Cannot add an operator to a non-class object")
    end

    -- MID: Why isn't desc == "" checked here like in field?
    local doc_lines = self.doc_lines
    parsed.desc = parsed.desc or doc_lines and table.concat(doc_lines, "\n") or nil
    parsed.desc = parsed.desc and vim.trim(parsed.desc) or nil

    local fields = self.fields
    fields[#fields + 1] = parsed --[[@as docgen.DocItem]]
    self.doc_lines = nil
end

-------------------------
-- MARK: Function Info --
-------------------------

function M:async_set()
    self.async = true
end

---@param self docgen.ParserObj
local function commit_doc_lines(self)
    local doc_lines = self.doc_lines
    if not doc_lines then
        return
    end

    local doc_lines_str = table.concat(doc_lines, "\n")
    if self.desc then
        self.desc = self.desc .. "\n" .. doc_lines_str
    else
        self.desc = doc_lines_str
    end

    self.doc_lines = nil
end

---@param fun_name string
---@param class string
---@param parent string
---@param sep string
function M:class_fun_set(fun_name, class, parent, sep)
    assert_no_kind(self, "class function")

    commit_doc_lines(self)

    self.name = fun_name
    self.class = class
    self.classvar = parent
    self.member_sep = sep

    self.params = self.params or {}
    table.insert(self.params, 1, {
        name = "self",
        type = class,
    })

    self.kind = "fun"
    if not self.name then
        local fmt_str = "fun.name is nil, check fn_xform(). fun: %s"
        error(string.format(fmt_str, vim.inspect(self)))
    end
end
-- TODO: Use list.insert_at instead of table.insert

---@param name string
function M:fun_set_from_name(name)
    assert_no_kind(self, "function")

    commit_doc_lines(self)
    self.kind = "fun"
    self.name = name
    if not self.name then
        local fmt_str = "fun.name is nil, check fn_xform(). fun: %s"
        error(string.format(fmt_str, vim.inspect(self)))
    end
end

--- True if the `.` class member should render like a module function.
--- @return boolean
function M:is_module_fun()
    return self.kind == "fun"
        and self.classvar ~= nil
        and self.member_sep == "."
        and self.modvar ~= nil
        and self.module ~= nil
        and self.classvar == self.modvar
end

---@param parsed nvim.luacats.grammar.Result
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

---@param parsed nvim.luacats.grammar.Result
function M:param_add(parsed)
    assert_no_kind(self, "param")

    if string.byte(parsed.name, #parsed.name) == 63 then
        parsed.name = string.sub(parsed.name, 1, -2)
        parsed.type = parsed.type .. "?"
    end

    self.params = self.params or {}
    local params = self.params
    params[#params + 1] = {
        name = parsed.name,
        type = parsed.type,
        desc = parsed.desc,
    }
end

function M:has_params()
    return self.params and #self.params > 0
end

---@param f fun(param:docgen.DocItem)
function M:param_iter(f)
    if not self:has_params() then
        return
    end

    local params = self.params ---@type docgen.DocItem[]
    local len_params = #params
    for i = 1, len_params do
        f(params[i])
    end
end

---@param parsed nvim.luacats.grammar.Result
function M:return_add(parsed)
    assert_no_kind(self, "return")
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

---@param line string
function M:doc_lines_add(line)
    -- TODO: This should just be string.byte
    if line:match("^ ") then
        line = line:sub(2)
    end

    local kind = self.kind
    -- TODO: Bad because we're re-concatenating on every line. Doclines should be allowed to
    -- accumulate in the string list, then be concatenated once at the end.
    -- Blocker: builder removal
    if kind == "brief" then
        local old_desc = self.desc or ""
        local newline = #old_desc > 0 and "\n" or ""
        self.desc = old_desc .. newline .. line
        return
    end

    -- TODO: Similar to the above, we should not be doing the concatenating in here.
    -- If a param is added and it's the first param, the doc lines should be left alone.
    -- This is the issue the "last_doc_item" field was taking care of in the original docgen. And,
    -- to its credit, it was only a reference
    local returns = self.returns
    -- TODO: Unsure if this is totally right because returns can be formatted so many ways
    if returns then
        if #returns > 0 then
            local old_desc = returns[#returns].desc or ""
            local newline = #old_desc > 0 and "\n" or ""
            returns[#returns].desc = old_desc .. newline .. line
        else
            -- Emit warning
        end
    end

    local params = self.params
    if params then
        if #params > 0 then
            local old_desc = params[#params].desc or ""
            local newline = #old_desc > 0 and "\n" or ""
            params[#params].desc = old_desc .. newline .. line
        else
            --
        end
    end

    -- TODO: Too late in the function for the common case
    if kind == nil or kind == "class" then
        self.doc_lines = self.doc_lines or {}
        local doc_lines = self.doc_lines
        doc_lines[#doc_lines + 1] = line
    end
end
-- TODO: This should probably be localized
-- TODO: Because param and return documentation, especially param documentation, can be indented
-- purposefully, this might be the place to remove leading whitespace, because it's fairly
-- isolated and puts less pressure on downstream formatting. On the other hand, even if we do do
-- that, the renderer might be the better place to run a fixup on the newlines.
-- MAYBE: Indent handling removed from here. Re-add if needed.

function M:doc_lines_clear()
    self.doc_lines = nil
end
-- TODO: Should get rid of this if handling internally

---@param parsed nvim.luacats.grammar.Result
function M:note_add(parsed)
    self.notes = self.notes or {}
    local notes = self.notes
    notes[#notes + 1] = parsed.desc
end
-- TODO: Why are notes tables that then hold a key to a string. Shouldn't this just be a string[]?

function M:has_notes()
    return self.notes ~= nil and #self.notes > 0
end

---@param f fun(note:string)
function M:notes_iter(f)
    if not self:has_notes() then
        return
    end

    local notes = self.notes ---@type string[]
    local len_notes = #notes
    for i = 1, len_notes do
        f(notes[i])
    end
end

---@param parsed nvim.luacats.grammar.Result
function M:see_add(parsed)
    self.see = self.see or {}
    local see = self.see
    see[#see + 1] = parsed.desc
end

function M:has_see()
    return self.see ~= nil and #self.see > 0
end

---@param f fun(see:string)
function M:see_iter(f)
    if not self:has_see() then
        return
    end

    local see = self.see ---@type string[]
    local len_see = #see
    for i = 1, len_see do
        f(see[i])
    end
end

---@param parsed nvim.luacats.grammar.Result
function M:since_set(parsed)
    self.since = parsed.desc
end

---@param parsed nvim.luacats.grammar.Result
function M:type_set(parsed)
    self.desc = parsed.desc
    self.type = parsed --[[@as docgen.DocItem]]
end

local transform = {
    ["alias"] = M.alias_set,
    ["async"] = M.async_set,
    ["brief"] = M.brief_set,
    ["class"] = M.class_set,
    ["deprecate"] = M.deprecate_set,
    ["enum"] = M.doc_lines_clear,
    ["field"] = M.class_add_field,
    ["generic"] = M.generic_add,
    ["inlinedoc"] = M.inlinedoc_set,
    ["nodoc"] = M.nodoc_set,
    ["note"] = M.note_add,
    ["operator"] = M.class_add_operator,
    ["overload"] = M.overload_add,
    ["package"] = M.package_set,
    ["param"] = M.param_add,
    ["private"] = M.private_set,
    ["protected"] = M.protected_set,
    ["return"] = M.return_add,
    ["see"] = M.see_add,
    ["since"] = M.since_set,
    ["type"] = M.type_set,
}
-- TODO: Naming could be a bit better. "set" functions should be for something that sets kind.

---@param parsed nvim.luacats.grammar.Result
function M:add_parsed(parsed)
    local transform_fn = transform[parsed.kind]
    if transform_fn then
        transform_fn(self, parsed)
    else
        -- Emit warning
    end
end
-- TODO: We are saying here that we will accept "---@" or "--- @" as annotation leads. This is
-- the right decision, but it comes with the caveat that you can't do the "--- " hack like in
-- Luacats to make things not render. This is not an issue in theory, but @nodoc needs to work
-- properly and the rules about what are rendered need to be clear.
-- TODO: Add a finalized boolean and set it so the object cannot be accidently edited afterward
-- TODO: For exterior callers, kind should be checked to see the object status. Need to be
-- guaranteed that a "good" object will be finalized = true and kind = not nil or not "". You can
-- have a self method to either return kind/finalized or a self method to return nil if not
-- finalized or no kind and the kind if there is one and finalized. "get_finalized_kind"
-- TODO: Need to set module info somewhere. I think what you do is always take modvar as an input
-- to create the obj, and then only parse it down when finalizing successfully. At least that's
-- the simple answer that doesnt nuke perf very much.
-- TODO: This renders most/all of the other functions private.
-- MAYBE: Trying to avoid ltrim and instead handling that on a case-by-case basis. Can re-add here
-- if needed.

--- @param line? string
--- @param classes table<string,docgen.ParserObj>
--- @param classvars table<string,string>
---@return boolean
function M:finalize(line, classes, classvars)
    if not line then
        return true
    end

    if
        string.match(line, "^%s+") ~= nil
        or string.find(line, "^%s*local%s+")
        or string.find(line, "^%s*return%s+")
        or string.find(line, "^%s*%-%- luacheck:")
        or string.find(line, "^%s*[a-zA-Z_.]+%(%s+")
    then
        return false
    end

    if self.kind == "class" then
        local name = line:match("^local%s+([a-zA-Z0-9_]+)%s*=")
        if name then
            classvars[name] = self.name
        end

        return true
    end

    local parent_tbl, sep, fun_name =
        line:match("^function%s+([a-zA-Z0-9_]+)([.:])([a-zA-Z0-9_]+)%s*%(")
    if parent_tbl then
        local class = classvars[parent_tbl]
        if class then
            self:class_fun_set(fun_name, class, parent_tbl, sep)
            classes[class]:class_add_field_from_fun(self)
            return true
        end
    end

    if self.access or self.deprecated or self.nodoc then
        return false
    end

    if parent_tbl == self.modvar then
        self:fun_set_from_name(fun_name)
        local name = assert(self.name)
        if string.byte(name, 1) == 95 or string.find(name, "[:.]_") then
            return false
        end

        return true
    end

    local dot_fun_name = line:match("^function%s+([.a-zA-Z0-9_]+)%s*%(")
    if dot_fun_name then
        self:fun_set_from_name(dot_fun_name)
        local name = assert(self.name)
        if string.byte(name, 1) == 95 or string.find(name, "[:.]_") then
            return false
        end

        return true
    end

    return true
end
-- TODO: The function name failures I think should be in the actual setter functions. Maybe do
-- some kind of outline thing.

return M

local luacats_grammar = require("docgen.luacats_grammar")

--- @class nvim.luacats.parser.param : nvim.luacats.grammar.Result

--- @class nvim.luacats.parser.return
--- @field name string
--- @field type string
--- @field desc string

--- @class nvim.luacats.parser.note
--- @field desc string

--- @class nvim.luacats.parser.field : nvim.luacats.grammar.Result
--- @field classvar? string
--- @field nodoc? true

--- @class nvim.luacats.parser.State
--- @field doc_lines? string[]
--- @field cur_obj? nvim.luacats.parser.obj
--- @field last_doc_item? nvim.luacats.parser.param|nvim.luacats.parser.return|nvim.luacats.parser.note
--- @field last_doc_item_indent? integer

--- @class nvim.luacats.parser.obj
--- @field access? 'private'|'protected'|'package'
--- @field async? boolean
--- @field attrs? string[]
--- @field class? string
--- @field classvar? string
--- @field deprecated? boolean
--- @field desc? string
--- @field fields? nvim.luacats.parser.field[]
--- @field generics? table<string, string>
--- @field inlinedoc? boolean
--- @field kind? 'class'|'fun'|'brief'|'alias'|'field'|'param'|'return'|'note'|'operator'
--- @field line? string
--- @field module? string
--- @field modvar? string
--- @field name? string
--- @field nodoc? boolean
--- @field notes? nvim.luacats.parser.note[]
--- @field overloads? string[]
--- @field params? nvim.luacats.parser.param[]
--- @field parent? string
--- @field returns? nvim.luacats.parser.return[]
--- @field see? nvim.luacats.parser.note[]
--- @field since? string
--- @field table? boolean
--- @field type? string|table

--- @param obj nvim.luacats.parser.obj
--- @param funs nvim.luacats.parser.obj[]
--- @param classes table<string,nvim.luacats.parser.obj>
--- @param briefs string[]
--- @param uncommitted nvim.luacats.parser.obj[]
local function commit_obj(obj, classes, funs, briefs, uncommitted)
    if obj.kind == "class" then
        if not classes[obj.name] then
            classes[obj.name] = obj
            return true
        end
    elseif obj.kind == "alias" then
        return true
    elseif obj.kind == "brief" then
        briefs[#briefs + 1] = obj.desc
        return true
    else
        if obj.name then
            funs[#funs + 1] = obj
            return true
        end
    end

    table.insert(uncommitted, obj)
    return false
end
-- MID: "Document aliases" feels like a semi-useful option.

--- @param fun nvim.luacats.parser.obj
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
--- M.fun = vim._memoize(function(...)
---   ->
--- function M.fun(...)
--- @param line string
--- @return string
local function filter_decl(line)
    line = line:gsub("^local (.+) = memoize%([^,]+, function%((.*)%)$", "local function %1(%2)")
    line = line:gsub("^(.+) = memoize%([^,]+, function%((.*)%)$", "function %1(%2)")
    return line
end

--- @param line string
--- @param state nvim.luacats.parser.State
--- @param classes table<string,nvim.luacats.parser.obj>
--- @param classvars table<string,string>
--- @param has_indent boolean
local function process_lua_line(line, state, classes, classvars, has_indent)
    line = filter_decl(line)

    if state.cur_obj and state.cur_obj.kind == "class" then
        local nm = line:match("^local%s+([a-zA-Z0-9_]+)%s*=")
        if nm then
            classvars[nm] = state.cur_obj.name
        end

        return
    end

    do
        local parent_tbl, sep, fun_or_meth_nm =
            line:match("^function%s+([a-zA-Z0-9_]+)([.:])([a-zA-Z0-9_]+)%s*%(")
        if parent_tbl then
            -- Have a decl. Ensure cur_obj
            state.cur_obj = state.cur_obj or {}
            local cur_obj = assert(state.cur_obj)

            -- Match `Class:foo` methods for defined classes
            local class = classvars[parent_tbl]
            if class then
                --- @cast cur_obj nvim.luacats.parser.obj
                cur_obj.name = fun_or_meth_nm
                cur_obj.class = class
                cur_obj.classvar = parent_tbl
                -- Add self param to methods
                if sep == ":" then
                    cur_obj.params = cur_obj.params or {}
                    table.insert(cur_obj.params, 1, {
                        name = "self",
                        type = class,
                    })
                end

                -- Add method as the field to the class
                table.insert(classes[class].fields, fun2field(cur_obj))
                return
            end

            -- Match `M.foo`
            if cur_obj and parent_tbl == cur_obj.modvar then
                cur_obj.name = fun_or_meth_nm
                return
            end
        end
    end

    do
        -- Handle: `function A.B.C.foo(...)`
        local fn_nm = line:match("^function%s+([.a-zA-Z0-9_]+)%s*%(")
        if fn_nm then
            state.cur_obj = state.cur_obj or {}
            state.cur_obj.name = fn_nm
            return
        end
    end

    do
        -- Handle: `M.foo = {...}` where `M` is the modvar
        local parent_tbl, tbl_nm = line:match("([a-zA-Z_]+)%.([a-zA-Z0-9_]+)%s*=")
        if state.cur_obj and parent_tbl and parent_tbl == state.cur_obj.modvar then
            state.cur_obj.name = tbl_nm
            state.cur_obj.table = true
            return
        end
    end

    do
        -- Handle: `foo = {...}`
        local tbl_nm = line:match("^([a-zA-Z0-9_]+)%s*=")
        if tbl_nm and not has_indent then
            state.cur_obj = state.cur_obj or {}
            state.cur_obj.name = tbl_nm
            state.cur_obj.table = true
            return
        end
    end

    do
        -- Handle: `vim.foo = {...}`
        local tbl_nm = line:match("^(vim%.[a-zA-Z0-9_]+)%s*=")
        if state.cur_obj and tbl_nm and not has_indent then
            state.cur_obj.name = tbl_nm
            state.cur_obj.table = true
            return
        end
    end

    if state.cur_obj then
        if line:find("^%s*%-%- luacheck:") then
            state.cur_obj = nil
        elseif line:find("^%s*local%s+") then
            state.cur_obj = nil
        elseif line:find("^%s*return%s+") then
            state.cur_obj = nil
        elseif line:find("^%s*[a-zA-Z_.]+%(%s+") then
            state.cur_obj = nil
        end
    end
end

--- @param state nvim.luacats.parser.State
local function add_doc_lines_to_obj(state)
    if state.doc_lines then
        state.cur_obj = state.cur_obj or {}
        local cur_obj = assert(state.cur_obj)
        local txt = table.concat(state.doc_lines, "\n")
        if cur_obj.desc then
            cur_obj.desc = cur_obj.desc .. "\n" .. txt
        else
            cur_obj.desc = txt
        end

        state.doc_lines = nil
    end
end

--- @param line string
--- @param state nvim.luacats.parser.State
local function process_doc_line(line, state)
    line = line:sub(4):gsub("^%s+@", "@")

    local parsed = luacats_grammar:match(line)
    if not parsed then
        if line:match("^ ") then
            line = line:sub(2)
        end

        if state.last_doc_item then
            if not state.last_doc_item_indent then
                state.last_doc_item_indent = #line:match("^%s*") + 1
            end

            state.last_doc_item.desc = (state.last_doc_item.desc or "")
                .. "\n"
                .. line:sub(state.last_doc_item_indent or 1)
        else
            state.doc_lines = state.doc_lines or {}
            table.insert(state.doc_lines, line)
        end

        return
    end

    state.last_doc_item_indent = nil
    state.last_doc_item = nil
    state.cur_obj = state.cur_obj or {}
    local cur_obj = assert(state.cur_obj)

    local kind = parsed.kind
    if kind == "brief" then
        state.cur_obj = {
            kind = "brief",
            desc = parsed.desc,
        }
    elseif kind == "class" then
        cur_obj.kind = "class"
        cur_obj.name = parsed.name
        cur_obj.parent = parsed.parent
        cur_obj.access = parsed.access
        cur_obj.desc = state.doc_lines and table.concat(state.doc_lines, "\n") or nil
        state.doc_lines = nil
        cur_obj.fields = {}
    elseif kind == "field" then
        if parsed.desc == "" then
            parsed.desc = nil
        end
        parsed.desc = parsed.desc or state.doc_lines and table.concat(state.doc_lines, "\n") or nil
        if parsed.desc then
            parsed.desc = vim.trim(parsed.desc)
        end
        table.insert(cur_obj.fields, parsed)
        state.doc_lines = nil
    elseif kind == "operator" then
        parsed.desc = parsed.desc or state.doc_lines and table.concat(state.doc_lines, "\n") or nil
        if parsed.desc then
            parsed.desc = vim.trim(parsed.desc)
        end
        table.insert(cur_obj.fields, parsed)
        state.doc_lines = nil
    elseif kind == "param" then
        state.last_doc_item_indent = nil
        cur_obj.params = cur_obj.params or {}
        if vim.endswith(parsed.name, "?") then
            parsed.name = parsed.name:sub(1, -2)
            parsed.type = parsed.type .. "?"
        end
        state.last_doc_item = {
            name = parsed.name,
            type = parsed.type,
            desc = parsed.desc,
        }
        table.insert(cur_obj.params, state.last_doc_item)
    elseif kind == "return" then
        cur_obj.returns = cur_obj.returns or {}
        for _, t in ipairs(parsed) do
            table.insert(cur_obj.returns, {
                name = t.name,
                type = t.type,
                desc = parsed.desc,
            })
        end
        state.last_doc_item_indent = nil
        state.last_doc_item = cur_obj.returns[#cur_obj.returns]
    elseif kind == "private" then
        cur_obj.access = "private"
    elseif kind == "package" then
        cur_obj.access = "package"
    elseif kind == "protected" then
        cur_obj.access = "protected"
    elseif kind == "deprecated" then
        cur_obj.deprecated = true
    elseif kind == "inlinedoc" then
        cur_obj.inlinedoc = true
    elseif kind == "nodoc" then
        cur_obj.nodoc = true
    elseif kind == "since" then
        cur_obj.since = parsed.desc
    elseif kind == "see" then
        cur_obj.see = cur_obj.see or {}
        table.insert(cur_obj.see, { desc = parsed.desc })
    elseif kind == "note" then
        state.last_doc_item_indent = nil
        state.last_doc_item = {
            desc = parsed.desc,
        }
        cur_obj.notes = cur_obj.notes or {}
        table.insert(cur_obj.notes, state.last_doc_item)
    elseif kind == "type" then
        cur_obj.desc = parsed.desc
        parsed.desc = nil
        parsed.kind = nil
        cur_obj.type = parsed
    elseif kind == "alias" then
        state.cur_obj = {
            kind = "alias",
            desc = parsed.desc,
        }
    elseif kind == "enum" then
        -- TODO
        state.doc_lines = nil
    elseif kind == "async" then
        cur_obj.async = true
    elseif kind == "overload" then
        cur_obj.overloads = cur_obj.overloads or {}
        table.insert(cur_obj.overloads, parsed.type)
    elseif
        require("docgen.util").list_find({
            "diagnostic",
            "cast",
            "overload",
            "meta",
        }, kind)
    then
        -- Ignore
        return
    elseif kind == "generic" then
        cur_obj.generics = cur_obj.generics or {}
        cur_obj.generics[parsed.name] = parsed.type or "any"
    else
        error("Unhandled" .. vim.inspect(parsed))
    end
end

--- Determine the table name used to export functions of a module
--- Usually this is `M`.
--- @param lines string[]
--- @return string?
local function find_modvar(lines)
    local modvar --- @type string?
    for _, line in ipairs(lines) do
        --- @type string?
        local m = line:match("^return%s+([a-zA-Z_]+)")
        if m then
            modvar = m
        end

        --- @type string?
        local meta_m = line:match("^return%s+setmetatable%(([a-zA-Z_]+),")
        if meta_m then
            modvar = meta_m
        end
    end
    return modvar
end

local M = {}

---@param str string
---@param input string
function M.parse_str(str, input)
    local funs = {} --- @type nvim.luacats.parser.obj[]
    local classes = {} --- @type table<string,nvim.luacats.parser.obj>
    local briefs = {} --- @type string[]

    local lines = vim.split(str, "\n")

    local classvars = {} --- @type table<string,string>
    local state = {} --- @type nvim.luacats.parser.State
    local uncommitted = {} --- @type nvim.luacats.parser.obj[]

    for _, line in ipairs(lines) do
        local has_indent = line:match("^%s+") ~= nil
        line = vim.trim(line)
        if string.find(line, "^%-%-%-") then
            process_doc_line(line, state)
        else
            add_doc_lines_to_obj(state)

            if state.cur_obj then
                local modvar = find_modvar(lines)
                state.cur_obj.modvar = modvar

                --- @type string
                local module = input:match(".*/lua/([a-z_][a-z0-9_/]+)%.lua") or input
                module = module:gsub("/", ".")
                state.cur_obj.module = module
            end

            process_lua_line(line, state, classes, classvars, has_indent)

            -- Commit the object
            local cur_obj = state.cur_obj
            if cur_obj then
                if not commit_obj(cur_obj, classes, funs, briefs, uncommitted) then
                    cur_obj.line = line
                end
            end

            state = {}
        end
    end

    return classes, funs, briefs, uncommitted
end
-- TODO: Would it not be simpler to do what mini-doc does and get --- pinned to the beginning of
-- the line without doing vim.trim?
-- TODO: For the top module name, if the file is init.lua, it should be the name of the file's
-- directory. (Assuming we keep this convention)

local function foo()
    return "bar"
end

--- @param input string
function M.parse(input)
    local f = assert(io.open(input, "r"))
    local txt = f:read("*all")
    f:close()

    return M.parse_str(txt, input)
end

return M

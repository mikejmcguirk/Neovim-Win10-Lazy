## Function Object

access - boolean?
deprecated - boolean?
nodoc - boolean?

name - string
since - string?
desc - string?
-- Unsure about this one
notes - { desc - string }?

attrs - looks like table<string, boolean> but unsure

```lua
--- @class nvim.luacats.parser.fun
--- @field name string
--- @field params nvim.luacats.parser.param[]
--- @field overloads string[]
--- @field returns nvim.luacats.parser.return[]
--- @field desc string
--- @field access? 'private'|'package'|'protected'
--- @field class? string
--- @field module? string
--- @field modvar? string
--- @field classvar? string
--- @field deprecated? true
--- @field async? true
--- @field since? string
--- @field attrs? string[]
--- @field nodoc? true
--- @field generics? table<string,string>
--- @field table? true
--- @field notes? nvim.luacats.parser.note[]
--- @field see? nvim.luacats.parser.note[]
```

```lua
--- @class nvim.luacats.parser.class : nvim.luacats.Class
--- @field desc? string
--- @field nodoc? true
--- @field inlinedoc? true
--- @field fields nvim.luacats.parser.field[]
--- @field notes? string[]
```

```lua
--- @class nvim.luacats.parser.alias
--- @field kind 'alias'
--- @field type string[]
--- @field desc string
```

```lua
--- @class nvim.luacats.parser.brief
--- @field kind 'brief'
--- @field desc string
```

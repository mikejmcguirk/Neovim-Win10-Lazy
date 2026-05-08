---@diagnostic disable: unused-local

---@brief This is a brief. It allows the user to explain additional things in the documentation
---that are not necessarily relevant to any particular function or class. It's a good way to
---provide an overview and introduction to the module.

---This should be an alias description
---@alias docgen.Foo integer This is not shown by Lua_Ls

local M = {}

---@param bar integer|string|nil I'm a bar
---@param baz table? I'm a bazz
---@param bill integer   | string |  nil I'm a billy
---     bob kind of boy
function M.foo(bar, baz, bill)
    return ""
end

---@inlinedoc
---This is a class description.
---@class test.Foo Lua_Ls does not show this.
---(default: `0`)
---This is a bar
---@field bar integer
---(default: `foo`)
---This is a bazz
---@field bazz string
---(default: `{ 1, 2, 3, 4, 5 }`)
---This is a buzz
---@field buzz integer[]

---@param bar integer
---@param foo test.Foo
---@param foobar boolean It do be like that
function M.bar(bar, foo, foobar)
    return 0
end

---@param foo docgen.Foo
---@return nil
function M.buzz(foo) end

return M

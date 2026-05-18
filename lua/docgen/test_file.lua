---@diagnostic disable: unused-local

---@brief This is a brief. It allows the user to explain additional things in the documentation
---that are not necessarily relevant to any particular function or class. It's a good way to
---provide an overview and introduction to the module.

---This should be an alias description
---@alias docgen.Foo integer This is not shown by Lua_Ls

local M = {}

---@deprecated Use |bar()| instead
---Just a simple function.
---@param bar integer|string|nil I'm a bar
---@param baz table? I'm a bazz
---@param bill integer   | string |  nil I'm a billy
---     bob kind of boy
---@return string
function M.foo(bar, baz, bill)
    return ""
end

---@inlinedoc
---This is a class description.
---@class test.Foo Lua_Ls does not show this.
---(default: `foo`)
---This is a bazz
---@field bazz string
---(default: `0`)
---This is a bar
---@field bar integer
---Welp.
---(default: `{ 1, 2, 3, 4, 5 }`) Some nonsense.
---This is a buzz
---@field buzz integer[]

---A description so it doesn't look like it's not rendering.
---@param bar integer
---@param foo test.Foo
---@param foobar boolean It do be like that
---@return integer redacted
---@return string A potentially grim picture of concatenation.
---@param woah number This is valid.
function M.bar(bar, foo, foobar, woah)
    return 0, ""
end

---This function buzzes very pleasantly.
---
---Note: This should highlight nicely
---
---A list formatting correctly:
---- Like this
---- Along with this
---  - And this
---  - And this one too
---
---Then this should be on its own line.
---@param foo integer
---@return nil
function M.buzz(foo) end

---What an amazing class
---@class test.Wow
local Wow = {}

---@param jazz_hands any
function Wow:be_amazed(jazz_hands)
    --
end

return M

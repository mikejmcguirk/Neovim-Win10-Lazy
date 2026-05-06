---@diagnostic disable: unused-local

local M = {}

---@param bar integer|string|nil I'm a bar
---@param baz table? I'm a bazz
---@param bill integer   | string |  nil I'm a billy
---     bob kind of boy
function M.foo(bar, baz, bill)
    return ""
end

---@inlinedoc
---@class test.Foo
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

return M

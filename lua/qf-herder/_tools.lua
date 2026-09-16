local M = {}

---Transform the elements of `t` into a single value using an accumulator.
---@see |i_reduce()| to initialize with the first value of the list.
---@generic T, A
---@param t T[]
---@param init A First accumulator value. No-op if this is `nil`.
---@param f fun(acc:A, x:T, idx:uinteger): A? If `nil` is returned, folding stops and the
---current accumulator is returned.
---@param rev? boolean (Default: `false`) If true, iterate from the end.
---@return A `init` if `t` is length zero.
function M.i_fold(t, init, f, rev)
    return require("nvim-tools.table").i_fold(t, init, f, rev)
end

---Keep only values from |lua-list| `t` that pass predicate function `f`.
---@generic T
---@param t T[] Modified in place!
---@param f fun(x:T): boolean
---@return T[] Reference to `t`.
function M.i_keep(t, f)
    return require("nvim-tools.table").i_keep(t, f)
end

return M

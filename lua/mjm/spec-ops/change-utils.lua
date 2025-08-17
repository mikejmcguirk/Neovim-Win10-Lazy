-- TODO: A lot of this can probably be merged in with delete, but want to see the use cases
-- play out first

local set_utils = require("mjm.spec-ops.set-utils")
local op_utils = require("mjm.spec-ops.op-utils")

local M = {}

-- TODO: These are not opts
--- @return op_marks|nil, string|nil
function M.do_change(opts)
    opts = opts or {}

    if not opts.marks then
        return nil, "do_get: No marks to get from"
    end

    opts.motion = opts.motion or "char"
    opts.curswant = opts.curswant or vim.fn.winsaveview().curswant
    if opts.motion == "char" then
        return op_utils.del_chars(opts.marks)
    elseif opts.motion == "line" then
        return set_utils.op_set_lines(opts.marks, { "" })
    else
        return op_utils.op_set_block(opts.marks, opts.curswant, { is_change = true })
    end
end

return M

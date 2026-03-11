local api = vim.api

local PRIORITY_DIM = 1000
local PRIORITY_RESULT = PRIORITY_DIM + 1
local PRIORITY_CURSOR = PRIORITY_DIM + 2
local PRIORITY_JUMP_HL = PRIORITY_DIM + 3
local PRIORITY_LABEL = PRIORITY_DIM + 4

local M = {}

---@param buf integer
---@param ns integer
---@param hl_group integer
---@param targets farsight.targets.Targets
---@param ctx farsight.labeler.SetCtx
function M.set_uniq_char_jump_hl(buf, ns, hl_group, targets, ctx)
    if ctx.locations == "none" then
        return
    end

    local extmark_opts = {
        hl_group = hl_group,
        priority = PRIORITY_JUMP_HL,
        strict = false,
    }

    for row, col in targets:iter_char_pos() do
        extmark_opts.end_row = row
        extmark_opts.end_col = col + 1
        api.nvim_buf_set_extmark(buf, ns, row, col, extmark_opts)
    end
end

return M

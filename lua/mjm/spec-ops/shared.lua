local M = {}

local hl_timer = vim.uv.new_timer()
local cur_ns = nil

--- @param hl_ns integer
--- @param regtype string
--- @param hl_group string
--- @param marks op_marks
--- 2param timeout integer
--- @return nil
local function wrapped_hl_text(hl_ns, regtype, hl_group, marks, hl_timeout)
    hl_timer:stop()
    if cur_ns then
        vim.api.nvim_buf_clear_namespace(0, cur_ns, 0, -1)
    end

    cur_ns = hl_ns
    -- TODO: Don't want to build like, bespoke logic for this since this is the only case where
    -- I know this is used, but if it comes up more, should be stored in op_state

    vim.hl.range(
        0,
        cur_ns,
        hl_group,
        { marks.start.row - 1, marks.start.col },
        { marks.fin.row - 1, marks.fin.col },
        { inclusive = true, regtype = regtype }
    )

    hl_timer:start(
        hl_timeout,
        0,
        vim.schedule_wrap(function()
            vim.api.nvim_buf_clear_namespace(0, cur_ns, 0, -1)
        end)
    )
end

-- TODO: It looks like hl.range uses vim._with to get vi_curswant

--- @param  op_state op_state
--- @return nil
--- Becaus this function is scheduled, op_state might be cleared before it's run. Copy the
--- relevant values now so we know they're available later
function M.highlight_text(op_state)
    local hl_ns = op_state.hl_ns
    local regtype = vim.fn.getregtype(op_state.vreg)
    local hl_group = op_state.hl_group
    local marks_post = op_state.marks_post
    local hl_timeout = op_state.hl_timeout

    vim.schedule(function()
        wrapped_hl_text(hl_ns, regtype, hl_group, marks_post, hl_timeout)
    end)
end

return M

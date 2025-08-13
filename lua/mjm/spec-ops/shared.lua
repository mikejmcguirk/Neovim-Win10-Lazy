-- TODO: Annotate M when the project is more baked in

local M = {}

local hl_timer = vim.uv.new_timer()

-- TODO: handle nil for the timers

--- @param marks op_marks
--- @param group string
--- @param ns integer
--- @param duration integer
--- @param regtype string
local function wrapped_hl_text(marks, group, ns, duration, regtype)
    hl_timer:stop()
    vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
    vim.hl.range(
        0,
        ns,
        group,
        { marks.start.row - 1, marks.start.col },
        { marks.fin.row - 1, marks.fin.col },
        { inclusive = true, regtype = regtype }
    )

    hl_timer:start(
        duration,
        0,
        vim.schedule_wrap(function()
            vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
        end)
    )
end

--- @param marks op_marks
--- @param group string
--- @param ns integer
--- @param duration integer
--- @param regtype string
function M.highlight_text(marks, group, ns, duration, regtype)
    vim.schedule(function()
        wrapped_hl_text(marks, group, ns, duration, regtype)
    end)
end

return M

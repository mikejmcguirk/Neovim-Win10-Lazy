local stl = require("mjm.stl")
local stl_events = stl.augroup

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
    group = stl_events,
    callback = function(ev)
        stl.event_router({ event = ev.event, buf = ev.buf, new_diags = true })
    end,
})

-- vim.api.nvim_create_autocmd("WinEnter", {
--     group = stl_events,
--     callback = function(ev)
--         -- Avoid stale diags when re-entering a window
--         stl.event_router({ event = ev.event, buf = ev.buf, new_diags = true })
--     end,
-- })
--
vim.api.nvim_create_autocmd("ModeChanged", {
    group = stl_events,
    callback = function(ev)
        local stl_data = require("mjm.stl-data")
        --- @diagnostic disable: undefined-field
        local old = stl_data.modes[vim.v.event.old_mode] or "norm"
        local new = stl_data.modes[vim.v.event.new_mode] or "norm"
        if old == new then
            return
        end

        if vim.tbl_contains({ "ins", "rep" }, old) then
            -- Since we held diag changes during insert/replace
            stl.event_router({ event = ev.event, buf = ev.buf, new_diags = true })
            return
        end
        stl.event_router({ event = ev.event, buf = ev.buf })
    end,
})

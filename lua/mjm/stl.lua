local stl_render = require("mjm.stl-render")

-- Not using the default diagnostics component. Remove its autocmd
vim.api.nvim_del_augroup_by_name("nvim.diagnostic.status")
local stl_events = vim.api.nvim_create_augroup("stl-events", { clear = true })

vim.api.nvim_create_autocmd({ "UIEnter" }, {
    group = stl_events,
    once = true,
    callback = function()
        vim.schedule(stl_render.set_active_stl)
    end,
})

-- No schedule because it does not update mode properly when leaving FzfLua
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "BufWinEnter", "LspAttach", "LspDetach" }, {
    group = stl_events,
    callback = function()
        stl_render.set_active_stl()
    end,
})

-- Run immediately to avoid stl flicker
vim.api.nvim_create_autocmd("WinLeave", {
    group = stl_events,
    callback = function()
        stl_render.set_inactive_stl(vim.api.nvim_get_current_win())
    end,
})

vim.api.nvim_create_autocmd("LspProgress", {
    group = stl_events,
    callback = function(ev)
        if (not ev.data) or not ev.data.client_id then
            return
        end

        if ev.data.params.value.kind == "end" then
            vim.defer_fn(stl_render.set_active_stl, 2250)
        end

        if not stl_render.bad_mode(vim.fn.mode(1)) then
            local progress = vim.deepcopy(ev.data, true)
            stl_render.set_active_stl(progress)
        end
    end,
})

-- TODO: nil argument error on GDelete
-- Now that we aren't caching though, feels unlikely to happen again
-- Run immediately to avoid acting on bad state
vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = stl_events,
    callback = function()
        if not stl_render.bad_mode(vim.fn.mode(1)) then
            stl_render.set_active_stl()
        end
    end,
})

-- Seems to create more cursor flicker if scheduled
-- Very rough thesis is that some async event(s) are triggering spooky action at a distance that
-- cause the gcr to blink out of rhythm. So adding an additional scheduled event here adds to
-- the problem
vim.api.nvim_create_autocmd("ModeChanged", {
    group = stl_events,
    callback = function()
        --- @diagnostic disable: undefined-field
        if vim.v.event.new_mode == "r?" then
            return
        end

        stl_render.set_active_stl()
    end,
})

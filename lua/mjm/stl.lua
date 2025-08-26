local stl_render = require("mjm.stl-render")

-- Not using the default diagnostics component. Remove its autocmd
vim.api.nvim_del_augroup_by_name("nvim.diagnostic.status")
local stl_events = vim.api.nvim_create_augroup("stl-events", { clear = true })

vim.api.nvim_create_autocmd({ "UIEnter" }, {
    group = stl_events,
    once = true,
    callback = vim.schedule_wrap(function()
        stl_render.set_active_stl()
    end),
})

vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "BufWinEnter", "LspAttach", "LspDetach" }, {
    group = stl_events,
    callback = vim.schedule_wrap(function()
        stl_render.set_active_stl()
    end),
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

        local progress = vim.deepcopy(ev.data, true)
        if not stl_render.bad_mode(vim.fn.mode(1)) then
            vim.schedule(function()
                stl_render.set_active_stl(progress)
            end)
        end

        if progress.params.value.kind == "end" then
            vim.defer_fn(function()
                stl_render.set_active_stl()
            end, 2250)
        end
    end,
})

-- TODO: nil argument error on GDelete
-- Now that we aren't caching though, feels unlikely to happen again
vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = stl_events,
    callback = vim.schedule_wrap(function()
        if not stl_render.bad_mode(vim.fn.mode(1)) then
            stl_render.set_active_stl()
        end
    end),
})

-- Seems to create more cursor flicker if schedule wrapped
-- Very rough thesis is that some async event(s) are triggering spooky action at a distance that
-- cause the gcr to blink out of rhythm. So adding an additional scheduled event here adds to
-- the problem
vim.api.nvim_create_autocmd("ModeChanged", {
    group = stl_events,
    callback = function()
        stl_render.set_active_stl()
    end,
})

-- FUTURE: Use nvim_redraw when it stops being experimental

local M = {}

local stl_render = require("mjm.stl-render")

local stl_events = vim.api.nvim_create_augroup("stl-events", { clear = true })
-- Remove the default autocmd
vim.api.nvim_del_augroup_by_name("nvim.diagnostic.status")

vim.api.nvim_create_autocmd({ "UIEnter" }, {
    group = stl_events,
    callback = function()
        stl_render.set_active_stl()
    end,
})

local rebuild_list = { "WinEnter", "BufEnter", "BufWinEnter", "LspAttach", "LspDetach" }
vim.api.nvim_create_autocmd(rebuild_list, {
    group = stl_events,
    callback = function()
        stl_render.set_active_stl()
    end,
})

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
        if stl_render.good_mode(vim.fn.mode(1)) then
            stl_render.set_active_stl(progress)
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
    callback = function()
        if stl_render.good_mode(vim.fn.mode(1)) then
            stl_render.set_active_stl()
        end
    end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
    group = stl_events,
    callback = function()
        stl_render.set_active_stl()
    end,
})

return M

-- FUTURE: Use nvim_redraw when it stops being experimental

local M = {}

local stl_data = require("mjm.stl-data")
local stl_render = require("mjm.stl-render")

local stl_events = vim.api.nvim_create_augroup("stl-events", { clear = true })

vim.api.nvim_create_autocmd({ "UIEnter" }, {
    group = stl_events,
    callback = function()
        stl_render.set_active_stl()
        stl_data.setup_stl_git_dir()
    end,
})

vim.api.nvim_create_autocmd({ "DirChanged" }, {
    group = stl_events,
    callback = function()
        stl_data.setup_stl_git_dir()
    end,
})

vim.api.nvim_create_autocmd("User", {
    group = stl_events,
    pattern = "FugitiveChanged",
    callback = function()
        stl_data.setup_stl_git_dir()
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
        stl_data.progress = progress

        local buf = vim.api.nvim_get_current_buf()
        local clients = vim.lsp.get_clients({ bufnr = buf })
        local is_attached = vim.tbl_contains(clients, function(c)
            return c.id == progress.client_id
        end, { predicate = true })

        if is_attached then
            vim.cmd("redraws")
        end

        if progress.params.value.kind == "end" then
            vim.defer_fn(function()
                stl_data.progress = nil
                vim.cmd("redraws")
            end, 2250)
        end
    end,
})

-- TODO: nil argument error on GDelete
vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = stl_events,
    callback = function(ev)
        stl_data.cache_diags(ev.buf, ev.data.diagnostics)
        stl_render.set_active_stl()
    end,
})

vim.api.nvim_create_autocmd("BufUnload", {
    group = stl_events,
    callback = function(ev)
        if stl_data.diag_cache and stl_data.diag_cache[tostring(ev.buf)] then
            stl_data.diag_cache[tostring(ev.buf)] = nil
        end
    end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
    group = stl_events,
    callback = function()
        --- @diagnostic disable: undefined-field
        local old = stl_data.modes[vim.v.event.old_mode] or "norm"
        local new = stl_data.modes[vim.v.event.new_mode] or "norm"
        if old == new then
            return
        end

        stl_render.set_active_stl()
    end,
})

function M.git_updated()
    stl_render.set_active_stl()
end

return M

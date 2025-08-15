-- TODO: There should be an exposed git done function. More generalized for the git functions
-- And provides more control here over what's done when called

local M = {}

local event_map = {
    ["BufWinEnter"] = "build-active",
    ["DiagnosticChanged"] = "build-active",
    ["LspProgress"] = "build-active",
    ["mjmGitHeadFound"] = "build-active",
    ["mjmNoGit"] = "build-active",
    ["ModeChanged"] = "build-active",
    ["WinEnter"] = "build-active",

    ["WinLeave"] = "build-inactive",

    ["DirChanged"] = "get-git-dir",
    ["FugitiveChanged"] = "get-git-dir",
    ["UIEnter"] = "get-git-dir",
}

local stl_data = require("mjm.stl-data")
local stl_render = require("mjm.stl-render")

local on_event = {
    -- TODO: For WinEnter:
    -- - This should first trigger a statusline rebuild since we're setting a new active window
    -- - This should then kick off a vim.diagnostic.get + cache storage
    -- - The stl-data function should then callback to here to trigger a statusline redraw
    ["build-active"] = function(opts)
        if opts.new_diags or opts.diags then
            stl_data.process_diags(opts)
        end
        stl_render.set_active_stl(opts)
    end,
    ["build-inactive"] = function(opts)
        stl_render.set_inactive_stl(opts)
    end,
    ["get-git-dir"] = function()
        stl_data.setup_stl_git_dir()
    end,
}

M.augroup = vim.api.nvim_create_augroup("stl-events", { clear = true })

vim.api.nvim_create_autocmd({ "UIEnter", "DirChanged", "User" }, {
    group = M.augroup,
    callback = function()
        stl_data.setup_stl_git_dir()
    end,
})

vim.api.nvim_create_autocmd("User", {
    group = M.augroup,
    pattern = "FugitiveChanged",
    callback = function()
        stl_data.setup_stl_git_dir()
    end,
})

vim.api.nvim_create_autocmd("WinLeave", {
    group = M.augroup,
    callback = function()
        stl_render.set_inactive_stl({ win = vim.api.nvim_get_current_win() })
    end,
})

vim.api.nvim_create_autocmd("LspProgress", {
    group = M.augroup,
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

function M.event_router(opts)
    opts = opts or {}
    if not opts.event then
        return vim.notify("No event provided to stl event_handler", vim.log.levels.ERROR)
    end

    local stl_event = event_map[opts.event]
    if not stl_event then
        local err_msg = string.format("%s invalid in stl event_handler", opts.event)
        return vim.notify(err_msg, vim.log.levels.ERROR)
    end

    local handler = on_event[stl_event]
    if not handler then
        local err_msg = string.format("No handler present for stl event %s", stl_event)
        vim.notify(err_msg, vim.log.levels.ERROR)
    end

    handler(opts)
end

return M

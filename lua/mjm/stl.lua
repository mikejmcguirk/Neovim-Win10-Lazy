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

    if opts.event == "ModeChanged" and not opts.mode then
        local err_msg = string.format("No mode provided on event %s", opts.event)
        vim.notify(err_msg, vim.log.levels.WARN)
    end

    local handler = on_event[stl_event]
    if not handler then
        local err_msg = string.format("No handler present for stl event %s", stl_event)
        vim.notify(err_msg, vim.log.levels.ERROR)
    end

    handler(opts)
end

return M

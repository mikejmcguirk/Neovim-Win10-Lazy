local modes = {
    ["n"] = "norm",
    ["no"] = "norm",
    ["nov"] = "norm",
    ["noV"] = "norm",
    ["no\22"] = "norm",
    ["niI"] = "norm",
    ["niR"] = "norm",
    ["niV"] = "norm",
    ["nt"] = "norm",
    ["ntT"] = "norm",
    ["v"] = "vis",
    ["vs"] = "vis",
    ["V"] = "vis",
    ["Vs"] = "vis",
    ["\22"] = "vis",
    ["\22s"] = "vis",
    ["s"] = "vis",
    ["S"] = "vis",
    ["\19"] = "vis",
    ["i"] = "ins",
    ["ic"] = "ins",
    ["ix"] = "ins",
    ["R"] = "rep",
    ["Rc"] = "rep",
    ["Rx"] = "rep",
    ["Rv"] = "vis",
    ["Rvc"] = "vis",
    ["Rvx"] = "vis",
    ["c"] = "cmd",
    ["cv"] = "cmd",
    ["ce"] = "cmd",
    ["r"] = "rep",
    ["rm"] = "cmd",
    ["r?"] = "cmd",
    -- Didn't see an explicit mapping for these in lualine'
    ["!"] = "norm",
    ["t"] = "norm",
}

local stl = require("mjm.stl")
local stl_events = vim.api.nvim_create_augroup("stl-events", { clear = true })

vim.api.nvim_create_autocmd({ "UIEnter", "DirChanged" }, {
    group = stl_events,
    callback = function(ev)
        stl.event_router({ event = ev.event })
    end,
})

vim.api.nvim_create_autocmd("User", {
    group = stl_events,
    pattern = "FugitiveChanged",
    callback = function()
        stl.event_router({ event = "FugitiveChanged" })
    end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
    group = stl_events,
    callback = function(ev)
        stl.event_router({ event = ev.event, buf = ev.buf, new_diags = true })
    end,
})

vim.api.nvim_create_autocmd("WinEnter", {
    group = stl_events,
    callback = function(ev)
        -- Avoid stale diags when re-entering a window
        stl.event_router({ event = ev.event, buf = ev.buf, new_diags = true, mode = "norm" })
    end,
})

vim.api.nvim_create_autocmd("WinLeave", {
    group = stl_events,
    callback = function(ev)
        stl.event_router({ event = ev.event, win = vim.api.nvim_get_current_win() })
    end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
    group = stl_events,
    callback = function(ev)
        --- @diagnostic disable: undefined-field
        local old = modes[vim.v.event.old_mode] or "norm"
        local new = modes[vim.v.event.new_mode] or "norm"
        if old == new then
            return
        end

        if vim.tbl_contains({ "ins", "rep" }, old) then
            -- Since we held diag changes during insert/replace
            stl.event_router({ event = ev.event, mode = new, buf = ev.buf, new_diags = true })
            return
        end
        stl.event_router({ event = ev.event, mode = new, buf = ev.buf })
    end,
})

vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = stl_events,
    callback = function(ev)
        if vim.tbl_contains({ "ins", "rep" }, modes[vim.fn.mode()]) then
            return
        end

        stl.event_router({
            event = ev.event,
            buf = ev.buf,
            diags = ev.data.diagnostics,
            mode = modes[vim.fn.mode()],
        })
    end,
})

vim.api.nvim_create_autocmd("BufUnload", {
    group = stl_events,
    callback = function(ev)
        local stl_data = require("mjm.stl-data")
        if stl_data.diag_count_cache and stl_data.diag_count_cache[tostring(ev.buf)] then
            stl_data.diag_count_cache[tostring(ev.buf)] = nil
        end
    end,
})

vim.api.nvim_create_autocmd("LspProgress", {
    group = stl_events,
    callback = function(ev)
        if (not ev.data) or not ev.data.client_id then
            return
        end

        local progress = vim.deepcopy(ev.data, true)
        stl.event_router({
            event = ev.event,
            progress = progress,
            mode = modes[vim.fn.mode()],
        })

        if ev.data.params.value.kind == "end" then
            vim.defer_fn(function()
                stl.event_router({
                    event = ev.event,
                    progress = nil,
                })
            end, 2250)
        end
    end,
})

MjmStl = {}

-- LOW: Build a character index component and keep it commented out alongside the virt col one
-- MAYBE: Show diags in inactive windows

local lsp_cache = {}
local diag_cache = {}
local mode = "n" -- ModeChanged does not grab the initial set to normal mode
local progress_cache = {}

local is_bad_mode = function()
    return string.match(mode, "[csSiR]")
end

-- Because evaluating the statusline initiates textlock, perform as much of the calculation
-- outside the eval func as possible

local stl_events = vim.api.nvim_create_augroup("stl-events", { clear = true })

vim.api.nvim_create_autocmd("LspProgress", {
    group = stl_events,
    callback = function(ev)
        if (not ev.data) or not ev.data.client_id then
            return
        end

        if not vim.api.nvim_buf_is_valid(ev.buf) then
            progress_cache[ev.buf] = nil
            return
        end

        if ev.data.params.value.kind == "end" then
            vim.defer_fn(function()
                progress_cache[ev.buf] = nil
                Cmd({ cmd = "redraws" }, {})
            end, 2250)
        end

        local values = ev.data.params.value
        local pct = (function()
            if values.kind == "end" then
                return "(Complete) "
            elseif values.percentage then
                return string.format("%d%%%% ", values.percentage)
            else
                return ""
            end
        end)()

        local name = vim.lsp.get_client_by_id(ev.data.client_id).name
        local message = ev.data.msg and (" - " .. values.msg) or ""

        local str = pct .. name .. ": " .. values.title .. message
        progress_cache[ev.buf] = str

        -- Don't create more textlock in insert mode
        if not is_bad_mode() then
            Cmd({ cmd = "redraws" }, {})
        end
    end,
})

local levels = { "Error", "Warn", "Info", "Hint" }
-- local signs = Has_Nerd_Font and { "󰅚", "󰀪", "󰋽", "󰌶" } or { "E:", "W:", "I:", "H:" }
local signs = { "E:", "W:", "I:", "H:" }

-- FUTURE: Verify if this is still needed
-- Per mini.Statusline - Needs to be schedule-wrapped due to a possible crash when running
-- redraws on detach after bufwipeout - https://github.com/neovim/neovim/issues/32349
-- The issue comments say this was fixed. Perhaps the wrap is kept in the mini code for
-- compatibility
vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = stl_events,
    callback = vim.schedule_wrap(function(ev)
        if not vim.api.nvim_buf_is_valid(ev.buf) then
            diag_cache[ev.buf] = nil
            return
        end

        local counts = {}
        for _, d in pairs(ev.data.diagnostics) do
            counts[d.severity] = (counts[d.severity] or 0) + 1
        end

        local diag_str = ""
        for i = 1, 4 do
            local count = counts[i] or 0
            if count > 0 then
                diag_str = diag_str
                    .. string.format("%%#Diagnostic%s#%s%d%%* ", levels[i], signs[i], count)
            end
        end

        diag_cache[ev.buf] = diag_str or nil

        if not is_bad_mode() then
            Cmd({ cmd = "redraws" }, {})
        end
    end),
})

vim.api.nvim_create_autocmd("ModeChanged", {
    group = stl_events,
    callback = function()
        --- @diagnostic disable: undefined-field
        if vim.v.event.new_mode == mode then
            return
        end

        mode = vim.v.event.new_mode
        Cmd({ cmd = "redraws" }, {})
    end,
})

-- From mini.statusline - Schedule wrap because the server is still listed on LspDetach
vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
    group = stl_events,
    callback = vim.schedule_wrap(function(ev)
        if not vim.api.nvim_buf_is_valid(ev.buf) then
            lsp_cache[ev.buf] = nil
            return
        end

        local clients = vim.lsp.get_clients({ bufnr = ev.buf })
        lsp_cache[ev.buf] = (clients and #clients > 0) and string.format("[%d]", #clients) or nil

        Cmd({ cmd = "redraws" }, {})
    end),
})

-- local format_icons = Has_Nerd_Font and { unix = "", dos = "", mac = "" }
--     or { unix = "unix", dos = "dos", mac = "mac" }
local format_icons = { unix = "unix", dos = "dos", mac = "mac" }

function MjmStl.active()
    local stl = {}
    local buf = vim.api.nvim_get_current_buf()
    local bad_mode = is_bad_mode()

    local ok_h, head = pcall(vim.api.nvim_get_var, "gitsigns_head")
    head = ok_h and head or ""
    local ok_d, diffs = pcall(vim.api.nvim_buf_get_var, buf, "gitsigns_status")
    diffs = ok_d and diffs or ""
    table.insert(stl, "%#stl_a# " .. head .. " " .. diffs .. "%* ")

    table.insert(stl, "%#stl_b# %m %<%f [" .. mode .. "] %*")

    -- I leave update_in_insert for diags set to false. Additionally, DiagnosticChange events
    -- cannot push redraws because they create text lock randomly in the middle of insert
    -- You could just show the cached diag data, but it might be stale
    local diags = (not bad_mode) and (diag_cache[buf] or "") or ""
    local lsps = lsp_cache[buf] or ""
    -- Annoying
    local progress = (progress_cache[buf] and not bad_mode) and progress_cache[buf] or ""

    table.insert(stl, " %#stl_c#" .. lsps .. " " .. diags .. " %<" .. progress .. "%*")

    table.insert(stl, "%=%*")

    -- Running autocmds to cache buf options means parsing out the autocmd and the stl redraw on
    -- every autocomplete window. More robust to handle on the fly
    local encoding = vim.api.nvim_get_option_value("encoding", { scope = "global" })
    local format = vim.api.nvim_get_option_value("fileformat", { buf = buf })
    local fmt = format_icons[format]
    local ft = vim.api.nvim_get_option_value("ft", { buf = buf })
    -- local ft_str = ft == "" and "" or "| " .. ft
    table.insert(stl, "%#stl_c# " .. encoding .. " | " .. fmt .. " | " .. ft .. " %*")

    table.insert(stl, "%#stl_b# %p%% %*")

    table.insert(stl, "%#stl_a# %l/%L | %c %*")

    return table.concat(stl, "")
end

function MjmStl.inactive()
    return "%#stl_b# %m %t %*%= %#stl_b# %p%% %*"
end

vim.g.qf_disable_statusline = 1

-- Lifted from mini.statusline
local eval = "(nvim_get_current_win()==#g:actual_curwin || &laststatus==3)"
vim.go.statusline = "%{%" .. eval .. " ? v:lua.MjmStl.active() : v:lua.MjmStl.inactive()%}"

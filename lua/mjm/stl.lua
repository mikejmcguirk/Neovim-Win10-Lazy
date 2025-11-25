local api = vim.api

_G.Mjm_Stl = {}

local diag_cache = {} ---@type table<integer,string>
local lsp_cache = {} ---@type table<integer,string>
local mode = "n" ---@type string -- ModeChanged does not grab the initial set to normal mode
local progress_cache = {} ---@type table<integer,string>
local timers = {} ---@type table<integer,uv.uv_timer_t>

-- NOTE: Evaluating the statusline initiates textlock. As much of the calculation as possible
-- should be performed outside the eval func. The eval func should also not be triggered
-- unnecessarily in insert mode

local stl_events = vim.api.nvim_create_augroup("stl-events", {}) ---@type integer
local is_bad_mode = function()
    return string.match(mode, "[csSiR]")
end

vim.api.nvim_create_autocmd("LspProgress", {
    group = stl_events,
    callback = function(ev)
        if not (ev.data and ev.data.client_id) then return end
        local function end_timer(idx)
            if not timers[idx] then return end
            timers[idx]:stop()
            timers[idx]:close()
            timers[idx] = nil
        end

        end_timer(ev.buf)
        local name = vim.lsp.get_client_by_id(ev.data.client_id).name or "" ---@type string
        local values = ev.data.params.value
        local message = ev.data.msg and (" - " .. values.msg) or "" ---@type string
        local pct = (function()
            if values.kind == "end" then
                return "(Complete) " -- End messages might not have a % value
            elseif values.percentage then
                return string.format("%d%%%% ", values.percentage)
            else
                return ""
            end
        end)() ---@type string

        timers[ev.buf] = vim.uv.new_timer() ---@type uv.uv_timer_t|nil
        if not timers[ev.buf] then return end
        timers[ev.buf]:start(2250, 0, function()
            progress_cache[ev.buf] = nil
            vim.schedule(function()
                if not is_bad_mode() and api.nvim_win_get_buf(0) == ev.buf then
                    vim.api.nvim_cmd({ cmd = "redraws" }, {})
                end
            end)

            end_timer(ev.buf)
        end)

        -- Prepend padding since diags are built from the default
        progress_cache[ev.buf] = " " .. pct .. name .. ": " .. values.title .. message
        if not is_bad_mode() and api.nvim_win_get_buf(0) == ev.buf then
            vim.api.nvim_cmd({ cmd = "redraws" }, {})
        end
    end,
})

-- local signs = Has_Nerd_Font and { "󰅚", "󰀪", "󰋽", "󰌶" } or { "E:", "W:", "I:", "H:" }
-- LOW: Detect if a patched font is available and use symbols accordingly

-- NOTE: Diagnostics.lua contains the delete for the default diagnostic status cache augroup

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

        diag_cache[ev.buf] = vim.diagnostic.status(ev.buf)
        if not is_bad_mode() then vim.api.nvim_cmd({ cmd = "redraws" }, {}) end
    end),
})

-- LOW: This does not catch leaving cmd mode after confirming a substitution
vim.api.nvim_create_autocmd("ModeChanged", {
    group = stl_events,
    callback = function()
        ---@diagnostic disable: undefined-field
        if vim.v.event.new_mode == mode then return end

        mode = vim.v.event.new_mode
        vim.api.nvim_cmd({ cmd = "redraws" }, {})
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

        local clients = vim.lsp.get_clients({ bufnr = ev.buf }) ---@type vim.lsp.Client[]
        lsp_cache[ev.buf] = (clients and #clients > 0) and string.format("[%d]", #clients) or nil

        vim.api.nvim_cmd({ cmd = "redraws" }, {})
    end),
})

-- local format_icons = Has_Nerd_Font and { unix = "", dos = "", mac = "" }
--     or { unix = "unix", dos = "dos", mac = "mac" }
local format_icons = { unix = "unix", dos = "dos", mac = "mac" } ---@type string[]

-- LOW: This should pre-allocate the table with NILs
function Mjm_Stl.active()
    local stl = {} ---@type string[]
    local buf = vim.api.nvim_get_current_buf() ---@type integer
    local bad_mode = is_bad_mode() ---@type boolean

    local head = vim.g.gitsigns_head or "" ---@type string
    local diffs = vim.b.gitsigns_status or "" ---@type string
    stl[#stl + 1] = "%#stl_a# " .. head .. " " .. diffs .. "%* "

    stl[#stl + 1] = "%#stl_b# %m %<%f [" .. mode .. "] %*"

    -- I have update_in_insert for diags set to false, so avoid showing stale data
    local diags = (not bad_mode) and (diag_cache[buf] or "") or "" ---@type string
    local lsps = lsp_cache[buf] or "" ---@type string
    ---@type string
    local progress = (progress_cache[buf] and not bad_mode) and progress_cache[buf] or ""
    stl[#stl + 1] = " %#stl_c#" .. lsps .. " " .. diags .. "%<" .. progress .. "%*"

    stl[#stl + 1] = "%=%*"

    -- LOW: Would prefer if this info were cached, but unsure how to do so without creating more
    -- work than what's currently here. The issue is making sure we don't cache the contents of
    -- popup bufs
    ---@type string
    local encoding = vim.api.nvim_get_option_value("encoding", { scope = "global" })
    local format = vim.api.nvim_get_option_value("fileformat", { buf = buf }) ---@type string
    local fmt = format_icons[format] ---@type string
    local ft = vim.api.nvim_get_option_value("ft", { buf = buf }) ---@type string
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) ---@type string
    if buftype == "" then
        buftype = buftype
    elseif buftype == "nofile" then
        buftype = "[nf] "
    elseif buftype == "nowrite" then
        buftype = "[nw] "
    else
        buftype = "[" .. string.sub(buftype, 1, 1) .. "] "
    end

    stl[#stl + 1] = "%#stl_c# " .. encoding .. " | " .. fmt .. " | " .. buftype .. ft .. " %*"

    local winnr = api.nvim_win_get_number(0) ---@type integer
    stl[#stl + 1] = "%#stl_b# [" .. winnr .. "] %p%%" .. " %*%#stl_a# %l/%L | %c %*"
    -- Keep in reserve for rancher debugging
    -- local alt_win = vim.fn.winnr("#") ---@type integer
    -- ---@type string
    -- local alt_win_disp = (alt_win and alt_win ~= winnr) and (" | #" .. alt_win) or ""
    -- ---@type string
    -- local ba = "%#stl_b# [" .. winnr .. "] %p%%" .. alt_win_disp .. " %*%#stl_a# %l/%L | %c %*"
    -- stl[#stl + 1] = ba

    return table.concat(stl, "")
end

-- LOW: Show the stack nr in the qf stl
-- LOW: Show diagnostics in inactive windows whited out

function Mjm_Stl.inactive()
    return "%#stl_b# %m %t %*%= %#stl_b# [" .. api.nvim_win_get_number(0) .. "] %p%% %*"
end

vim.api.nvim_set_option_value("showmode", false, { scope = "global" })
vim.api.nvim_set_var("qf_disable_statusline", 1)

local eval = "(nvim_get_current_win()==#g:actual_curwin || &laststatus==3)"
local stl_str = "%{%" .. eval .. " ? v:lua.Mjm_Stl.active() : v:lua.Mjm_Stl.inactive()%}"
vim.api.nvim_set_option_value("stl", stl_str, { scope = "global" })

-- LOW: Build a character index component, even if it's only held in reserve
-- LOW: If you open a buf, detach the LSP, then re-attach it, progress messages don't show properly
-- - (in general LSP progress has been the biggest challenge here)

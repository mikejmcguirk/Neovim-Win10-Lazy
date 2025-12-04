local api = vim.api

local buf_cache = {} ---@type table<integer, string>
local diag_cache = {} ---@type table<integer,string>
local lsp_cache = {} ---@type table<integer,string>
local mode = "n" ---@type string -- ModeChanged does not grab the initial set to normal mode
local progress_cache = {} ---@type table<integer,string>
local timers = {} ---@type table<integer,uv.uv_timer_t>

-- NOTE: Evaluating the statusline initiates textlock. As much of the calculation as possible
-- should be performed outside the eval func. The eval func should also not be triggered
-- unnecessarily in insert mode, as this creates noticeable stutter

local stl_events = api.nvim_create_augroup("mjm-stl-events", {}) ---@type integer
---@return boolean
local is_bad_mode = function()
    return string.match(mode, "[csSiR]")
end

-- LOW: There's a bunch of little corner cases you could handle in here, but I haven't seen them
-- matter in practice
api.nvim_create_autocmd("LspProgress", {
    group = stl_events,
    callback = function(ev)
        if not (ev.data and ev.data.client_id) then
            return
        end
        local function end_timer(idx)
            if not timers[idx] then
                return
            end
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
        if not timers[ev.buf] then
            return
        end
        timers[ev.buf]:start(2250, 0, function()
            progress_cache[ev.buf] = nil
            vim.schedule(function()
                if not is_bad_mode() and api.nvim_win_get_buf(0) == ev.buf then
                    api.nvim_cmd({ cmd = "redraws" }, {})
                end
            end)

            end_timer(ev.buf)
        end)

        progress_cache[ev.buf] = pct .. name .. ": " .. values.title .. message
        if not is_bad_mode() and api.nvim_win_get_buf(0) == ev.buf then
            api.nvim_cmd({ cmd = "redraws" }, {})
        end
    end,
})

local levels = { "Error", "Warn", "Info", "Hint" } ---@type string[]
---@type string[]
local signs = Has_Nerd_Font and { "󰅚 ", "󰀪 ", "󰋽 ", "󰌶 " }
    or { "E:", "W:", "I:", "H:" }

-- NOTE: Diagnostics.lua contains the delete for the default diagnostic status cache augroup
-- MID: Show whited out diag counts in the inactive stl
-- MAYBE: mini.statusline schedule wraps its diagnostic update because of something to do with
-- invalid buffer data. Unsure if the underlying issue is resolved. Trying without here since we
-- check buffer validity at the top. If it breaks again, set the callback to a schedule wrap and
-- re-research the issue
api.nvim_create_autocmd("DiagnosticChanged", {
    group = stl_events,
    callback = function(ev)
        if api.nvim_buf_is_valid(ev.buf) then
            -- Cannot use the builtin because it runs get_diagnostics fresh
            local counts = {} ---@type table<integer,integer>
            for _, d in pairs(ev.data.diagnostics) do
                counts[d.severity] = (counts[d.severity] or 0) + 1
            end

            local diag_str = "" ---@type string
            for i = 1, 4 do
                local count = counts[i] or 0 ---@type integer
                if count > 0 then
                    diag_str = diag_str
                        .. string.format("%%#Diagnostic%s#%s%d%%* ", levels[i], signs[i], count)
                end
            end

            diag_cache[ev.buf] = diag_str
        else
            diag_cache[ev.buf] = nil
        end

        -- LOW: Checking based on ev.buf being the current buf produces inconsistent results. Why?
        if not is_bad_mode() then
            api.nvim_cmd({ cmd = "redraws" }, {})
        end
    end,
})

api.nvim_create_autocmd("ModeChanged", {
    group = stl_events,
    callback = function()
        ---@diagnostic disable: undefined-field
        if vim.v.event.new_mode == mode then
            return
        end
        mode = vim.v.event.new_mode
        api.nvim_cmd({ cmd = "redraws" }, {})
    end,
})

-- From mini.statusline - Schedule wrap because the server is still listed on LspDetach
api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
    group = stl_events,
    callback = vim.schedule_wrap(function(ev)
        if api.nvim_buf_is_valid(ev.buf) then
            local clients = vim.lsp.get_clients({ bufnr = ev.buf }) ---@type vim.lsp.Client[]
            local has_clients = clients and #clients > 0 ---@type boolean
            lsp_cache[ev.buf] = has_clients and string.format("[%d]", #clients) or nil
        else
            lsp_cache[ev.buf] = nil
        end

        api.nvim_cmd({ cmd = "redraws" }, {})
    end),
})

---@type string[]
local format_icons = Has_Nerd_Font and { unix = "", dos = "", mac = "" }
    or { unix = "unix", dos = "dos", mac = "mac" }

local bt_map = {
    [""] = "",
    acwrite = "[acw] ",
    help = "[h] ",
    nofile = "[nf] ",
    nowrite = "[nw] ",
    prompt = "[p] ",
    quickfix = "[qf] ",
    terminal = "[term] ",
} ---@type table<string, string>

local function create_buf_str(buf)
    local fenc = api.nvim_get_option_value("fenc", { buf = buf }) ---@type string
    ---@type string
    local encoding = #fenc > 0 and fenc or api.nvim_get_option_value("enc", { scope = "global" })

    local fmt = format_icons[api.nvim_get_option_value("ff", { buf = buf })] ---@type string
    local bt = bt_map[api.nvim_get_option_value("bt", { buf = buf })] ---@type string
    local ft = api.nvim_get_option_value("ft", { buf = buf }) ---@type string
    local bt_ft = bt .. ft ---@type string
    local fmt_bt_ft = #bt_ft > 0 and " " .. bt_ft or "" ---@type string

    return encoding .. " | " .. fmt .. " |" .. fmt_bt_ft .. " "
end

-- LOW: This does not address the case where a float is converted to a non-float. Can look at this
-- more if this case becomes more frequent
api.nvim_create_autocmd("BufWinEnter", {
    group = stl_events,
    callback = function(ev)
        local win = api.nvim_get_current_win() ---@type integer
        local config = api.nvim_win_get_config(win) ---@type vim.api.keyset.win_config_ret
        if config.relative and config.relative ~= "" then
            return
        end

        buf_cache[ev.buf] = create_buf_str(ev.buf)
        api.nvim_cmd({ cmd = "redraws" }, {})
    end,
})

-- MAYBE: Mixed feelings about this because, early exit or not, it triggers on every completion
-- popup. Still better, I suppose, than re-generating the buf options every keystroke
api.nvim_create_autocmd("OptionSet", {
    group = stl_events,
    callback = function(ev)
        local buf = ev.buf ~= 0 and ev.buf or api.nvim_get_current_buf() ---@type integer
        if not buf_cache[buf] then
            return
        end
        local watched = { "fileencoding", "encoding", "fileformat", "buftype" } ---@type string[]
        if not vim.tbl_contains(watched, ev.match) then
            return
        end

        buf_cache[buf] = create_buf_str(buf)
        api.nvim_cmd({ cmd = "redraws" }, {})
    end,
})

api.nvim_create_autocmd("BufDelete", {
    group = stl_events,
    callback = function(ev)
        require("mjm.utils").do_when_idle(function()
            buf_cache[ev.buf] = nil
        end)
    end,
})

_G.Mjm_Stl = {}
-- Module scoped because it's used on every keystroke
local stl = { nil, nil, nil, "%=%*", nil, nil } ---@type string[]

-- LOW: Now that everything is cached, worth re-exploring doing this based on real-time evals
-- rather than re-making the string each time
-- In theory, it should be possible to set certain elements to be static and only redraw when
-- needed. In practice, certain things seem to always fall through the cracks. In the interest of
-- sanity, and because the stl performs fairly cleanly as is, am willing to accept a certain level
-- of compromise on "over-rendering" the stl to avoid having to over-think every edge case
---@return string
function Mjm_Stl.active()
    local buf = api.nvim_get_current_buf() ---@type integer
    local bad_mode = is_bad_mode() ---@type boolean

    local head = vim.g.gitsigns_head or "" ---@type string
    local diffs = vim.b.gitsigns_status or "" ---@type string
    stl[1] = "%#stl_a# " .. head .. " " .. diffs .. "%* "

    stl[2] = "%#stl_b# %m %f [" .. mode .. "] %*"

    -- update_in_insert for diags set to false. Avoid showing stale data
    local diags = (not bad_mode) and (diag_cache[buf] or "") or "" ---@type string
    local lsps = lsp_cache[buf] or "" ---@type string
    local show_progress = progress_cache[buf] and not bad_mode ---@type boolean
    local progress = show_progress and progress_cache[buf] or "" ---@type string
    stl[3] = " %#stl_c#" .. lsps .. " " .. diags .. "%<" .. progress .. "%*"

    stl[5] = "%#stl_c#" .. (buf_cache[buf] or "") .. "%*"

    local winnr = api.nvim_win_get_number(0) ---@type integer
    stl[6] = "%#stl_b# [" .. winnr .. "] %p%%" .. " %*%#stl_a# %l/%L | %c %*"

    return table.concat(stl, "")
end

---@return string
function Mjm_Stl.inactive()
    return "%#stl_b# %m %t %*%= %#stl_b# [" .. api.nvim_win_get_number(0) .. "] %p%% %*"
end

-- LOW: Show the stack nr in the qf stl. This g:var controls an ftplugin that sets based on a
-- setlocal, so I could just re-apply that idea
api.nvim_set_var("qf_disable_statusline", 1)
api.nvim_set_option_value("smd", false, {})
local eval = "(nvim_get_current_win()==#g:actual_curwin || &laststatus==3)" ---@type string
---@type string
local stl_str = "%{%" .. eval .. " ? v:lua.Mjm_Stl.active() : v:lua.Mjm_Stl.inactive()%}"
api.nvim_set_option_value("stl", stl_str, { scope = "global" })

-- LOW: Build a character index component for spec-ops debugging
-- LOW: Re-check if the virtual column component is usable for spec-ops debugging or if I need to
-- build my own. That might be tough though because you have to binary search each cursor movement

local api = vim.api
local uv = vim.uv

local buf_cache = {} ---@type table<integer, string>
local diag_cache = {} ---@type table<integer,string>
local lsp_cache = {} ---@type table<integer,string>
local mode = "n" ---@type string -- ModeChanged does not grab the initial set to normal mode
local progress_cache = {} ---@type table<integer,string>
local timers = {} ---@type table<integer,uv.uv_timer_t>

---@param buf integer
local function end_timer(buf)
    if not timers[buf] then
        return
    end

    timers[buf]:stop()
    timers[buf]:close()
    timers[buf] = nil
end

-- NOTE: Evaluating the statusline initiates textlock. As much of the calculation as possible
-- should be performed outside the eval func. The eval func should also not be triggered
-- unnecessarily in insert mode, as this creates noticeable stutter

local stl_events = api.nvim_create_augroup("mjm-stl-events", {})

---@return boolean
local is_bad_mode = function()
    return string.match(mode, "[csSiR]") ~= nil
end

-- MID: How does the Nvim default do this? While I like my current method of doing the processing
-- in the autocmd, I think nvim how has a new interface to use to get this data
api.nvim_create_autocmd("LspProgress", {
    group = stl_events,
    callback = function(ev)
        local data = ev.data
        if not data then
            return
        end

        local client_id = data.client_id
        if not client_id then
            return
        end

        local client = vim.lsp.get_client_by_id(client_id)
        if not client then
            return
        end

        local buf = ev.buf
        end_timer(buf)
        timers[buf] = uv.new_timer()
        if not timers[buf] then
            return
        end

        local name = client.name
        local values = data.params.value
        local message = data.msg and (" - " .. values.msg) or "" ---@type string

        ---@type string
        local pct = (function()
            if values.kind == "end" then
                return "(Complete) " -- End messages might not have a % value
            elseif values.percentage then
                return string.format("%d%%%% ", values.percentage)
            else
                return ""
            end
        end)()

        timers[buf]:start(2250, 0, function()
            progress_cache[buf] = nil
            vim.schedule(function()
                if is_bad_mode() then
                    return
                end

                if api.nvim_win_get_buf(0) == buf then
                    api.nvim__redraw({ statusline = true, win = 0 })
                end
            end)

            end_timer(buf)
        end)

        progress_cache[buf] = pct .. name .. ": " .. values.title .. message
        -- Leave autocmd context before trying to redraw.
        vim.schedule(function()
            if is_bad_mode() then
                return
            end

            if api.nvim_win_get_buf(0) == buf then
                api.nvim__redraw({ statusline = true, win = 0 })
            end
        end)
    end,
})

local levels = { "Error", "Warn", "Info", "Hint" }
---@type string[]
local signs = mjm.v.has_nerd_font and { "󰅚 ", "󰀪 ", "󰋽 ", "󰌶 " }
    or { "E:", "W:", "I:", "H:" }

-- NOTE: My diagnostics.lua contains the delete for the default diagnostic status cache augroup
-- MID: Show whited out diag counts in the inactive stl
-- MAYBE: mini.statusline schedule wraps its diagnostic update because of something to do with
-- invalid buffer data. Unsure if the underlying issue is resolved. Trying without here since we
-- check buffer validity at the top. If it breaks again, schedule wrap again and research further
api.nvim_create_autocmd("DiagnosticChanged", {
    group = stl_events,
    callback = function(ev)
        local buf = ev.buf
        if not api.nvim_buf_is_valid(buf) then
            diag_cache[buf] = nil
            return
        end

        local ntl = require("nvim-tools.list")
        local counts = ntl.fold(ev.data.diagnostics, function(acc, d)
            local severity = d.severity
            acc[severity] = acc[severity] + 1
            return acc
        end, { 0, 0, 0, 0 })

        local diag_strs = ntl.filter_map_to(counts, function(c, i)
            if c == 0 then
                return nil
            end

            return "%#Diagnostic" .. levels[i] .. "#" .. signs[i] .. c .. "%* "
        end)

        diag_cache[buf] = table.concat(diag_strs, "")
        -- Leave autocmd context before trying to redraw.
        vim.schedule(function()
            if is_bad_mode() then
                return
            end

            if api.nvim_win_get_buf(0) == buf then
                api.nvim__redraw({ statusline = true, win = 0 })
            end
        end)
    end,
})

api.nvim_create_autocmd("ModeChanged", {
    group = stl_events,
    callback = function()
        ---@diagnostic disable: undefined-field
        local new_mode = vim.v.event.new_mode
        if new_mode == mode then
            return
        end
        -- MID: Why is this check here? Is it even possible for this to be true?

        ---@diagnostic disable-next-line: assign-type-mismatch
        mode = new_mode
        vim.schedule(function()
            -- When leaving fzf-lua, without scheduling, the redraw fires for the fzf-lua window,
            -- meaning the intended current window still shows mode `t`.
            local config = api.nvim_win_get_config(0)
            if config.hide == true or (config.relative ~= nil and config.relative ~= "") then
                return
            end

            api.nvim__redraw({ statusline = true, win = 0 })
        end)
    end,
})
-- MID: I do not love keeping a separate source of truth for mode, even though I know it will
-- incur a perf loss to unwind it.

-- From mini.statusline - Schedule wrap because the server is still listed on LspDetach
api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
    group = stl_events,
    callback = vim.schedule_wrap(function(ev)
        local buf = ev.buf
        if api.nvim_buf_is_valid(buf) then
            local clients = vim.lsp.get_clients({ bufnr = buf })
            local has_clients = clients and #clients > 0
            lsp_cache[buf] = has_clients and string.format("[%d]", #clients) or nil
        else
            lsp_cache[buf] = nil
        end

        -- Leave autocmd context before trying to redraw.
        vim.schedule(function()
            if is_bad_mode() then
                return
            end

            if api.nvim_win_get_buf(0) == buf then
                api.nvim__redraw({ statusline = true, win = 0 })
            end
        end)
    end),
})

local format_icons = mjm.v.has_nerd_font and { unix = "", dos = "", mac = "" }
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
}

---@param buf integer
---@return string
local function create_buf_str(buf)
    local fenc = api.nvim_get_option_value("fenc", { buf = buf }) ---@type string
    ---@type string
    local encoding = #fenc > 0 and fenc or api.nvim_get_option_value("enc", { scope = "global" })

    local ff = api.nvim_get_option_value("ff", { buf = buf }) ---@type string
    local mff = format_icons[ff]
    local bt = api.nvim_get_option_value("bt", { buf = buf }) ---@type string
    local mbt = bt_map[bt]
    local ft = api.nvim_get_option_value("ft", { buf = buf }) ---@type string

    local printable = #mbt + #ft > 0
    local fmt_bt_ft = printable and " " .. bt_map[bt] .. ft or ""

    return "[" .. tostring(buf) .. "] " .. encoding .. " | " .. mff .. " |" .. fmt_bt_ft .. " "
end
-- MID: It feels like the better way to do this is with caching them all and using OptionSet to
-- just update the cache, then using LuaEval to pull them.

-- LOW: This does not address the case where a float is converted to a non-float. Can look at this
-- more if this case becomes more frequent
api.nvim_create_autocmd("BufWinEnter", {
    group = stl_events,
    callback = function(ev)
        local win = api.nvim_get_current_win()
        local config = api.nvim_win_get_config(win)
        if config.hide == true or (config.relative ~= nil and config.relative ~= "") then
            return
        end

        buf_cache[ev.buf] = create_buf_str(ev.buf)
        api.nvim__redraw({ statusline = true, win = 0 })
    end,
})

-- MAYBE: Mixed feelings about this because, early exit or not, it triggers on every completion
-- popup. Still better, I suppose, than re-generating the buf options every keystroke
local watched = { "fileencoding", "encoding", "fileformat", "buftype" }
api.nvim_create_autocmd("OptionSet", {
    group = stl_events,
    callback = function(ev)
        local buf = ev.buf ~= 0 and ev.buf or api.nvim_get_current_buf()
        if not buf_cache[buf] then
            return
        end

        local match = ev.match
        if not match then
            return
        end

        if not require("nvim-tools.list").contains(watched, match) then
            return
        end

        buf_cache[buf] = create_buf_str(buf)
        -- Leave autocmd context before trying to redraw.
        vim.schedule(function()
            if api.nvim_win_get_buf(0) == buf then
                api.nvim__redraw({ statusline = true, win = 0 })
            end
        end)
    end,
})

api.nvim_create_autocmd("FileType", {
    group = stl_events,
    callback = function(ev)
        local buf = ev.buf ~= 0 and ev.buf or api.nvim_get_current_buf()
        if not buf_cache[buf] then
            return
        end

        buf_cache[buf] = create_buf_str(buf)
        -- Leave autocmd context before trying to redraw.
        vim.schedule(function()
            if api.nvim_win_get_buf(0) == buf then
                api.nvim__redraw({ statusline = true, win = 0 })
            end
        end)
    end,
})

api.nvim_create_autocmd("BufDelete", {
    group = stl_events,
    callback = function(ev)
        buf_cache[ev.buf] = nil
    end,
})

_G.Mjm_Stl = {}
local stl = { "", "", "", "%=%*", "", "" } ---@type string[]

-- LOW: Now that everything is cached, worth re-exploring doing this based on real-time evals
-- rather than re-making the string each time
-- In theory, it should be possible to set certain elements to be static and only redraw when
-- needed. In practice, certain things seem to always fall through the cracks. In the interest of
-- sanity, and because the stl performs fairly cleanly as is, am willing to accept a certain level
-- of compromise on "over-rendering" the stl to avoid having to over-think every edge case
---@return string
function Mjm_Stl.active()
    local buf = api.nvim_get_current_buf()
    local bad_mode = is_bad_mode()

    local head = vim.g.gitsigns_head or "" ---@type string
    local diffs = vim.b.gitsigns_status or "" ---@type string
    stl[1] = "%#stl_a# " .. head .. " " .. diffs .. "%* "

    stl[2] = "%#stl_b# %m %t [" .. mode .. "] %*"

    -- update_in_insert for diags set to false. Avoid showing stale data
    local diags = (not bad_mode) and (diag_cache[buf] or "") or ""
    local lsps = lsp_cache[buf] or "" ---@type string
    local show_progress = progress_cache[buf] and not bad_mode
    local progress = show_progress and progress_cache[buf] or ""
    stl[3] = " %#stl_c#" .. lsps .. " " .. diags .. "%<" .. progress .. "%*"

    stl[5] = "%#stl_c#" .. (buf_cache[buf] or "") .. "%*"

    local win = api.nvim_get_current_win()
    local winnr = api.nvim_win_get_number(win)
    stl[6] = "%#stl_b# [" .. win .. "] [" .. winnr .. "] %p%%" .. " %*%#stl_a# %l/%L | %c %*"

    return table.concat(stl, "")
end
-- MID: Show %f for filename when only one window, and %t for tail when multiple windows.

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

-- MID: Show which treesitter parser(s) are running.
-- MID: https://github.com/neovim/neovim/pull/35428

-- LOW: Build a character index component for spec-ops debugging
-- LOW: Re-check if the virtual column component is usable for spec-ops debugging or if I need to
-- build my own. That might be tough though because you have to binary search each cursor movement

-- MAYBE: Could explore adding the char index. But it looks like I would need to compute that in
-- Lua, which might incur a performance cost

local M = {}

local stl_data = require("mjm.stl-data")

local diag_icons = Has_Nerd_Font
        and { ERROR = "󰅚", WARN = "󰀪", INFO = "󰋽", HINT = "󰌶" }
    or { ERROR = "E:", WARN = "W:", INFO = "I:", HINT = "H:" }

local format_icons = Has_Nerd_Font and { unix = "", dos = "", mac = "" }
    or { unix = "unix", dos = "dos", mac = "mac" }

local function build_separator(stl, opts)
    opts = opts or {}
    local hl = stl_data[string.format("%s-c", (opts.mode or "norm"))]
    table.insert(stl, string.format("%%#%s#%%=%%*", hl))
end

local function build_active_a(stl, opts)
    opts = opts or {}
    local hl = stl_data[string.format("%s-a", (opts.mode or "norm"))]

    local git_symbol = Has_Nerd_Font and " " or " "
    local head = stl_data.head and string.format(" %s ", stl_data.head) or " "

    table.insert(stl, string.format("%%#%s#%s%s", hl, git_symbol, head))
end

local function build_active_b(stl, opts)
    opts = opts or {}
    local hl = stl_data[string.format("%s-b", (opts.mode or "norm"))]
    table.insert(stl, string.format("%%#%s# %%m %%f %%*", hl))
end

local function add_diags(stl, buf)
    local diag_counts = stl_data.diag_count_cache[tostring(buf)]
    if diag_counts then
        local parts = vim.iter({ "ERROR", "WARN", "INFO", "HINT" })
            :map(function(severity)
                local count = diag_counts[severity]
                if count == 0 then
                    return nil
                end

                local diag_hl = "Diagnostic" .. severity:sub(1, 1) .. severity:sub(2):lower()
                return string.format("%%#%s#%s %d ", diag_hl, diag_icons[severity], count)
            end)
            :filter(function(part)
                return part ~= nil
            end)
            :totable()

        table.insert(stl, table.concat(parts, ""))
    end
    table.insert(stl, "%*")
end

local function build_active_c(stl, opts)
    opts = opts or {}
    local mode = opts.mode or "norm"
    local hl = stl_data[string.format("%s-c", mode)]
    table.insert(stl, string.format("%%#%s# ", hl))

    local buf = opts.buf or vim.api.nvim_get_current_buf()
    local display_mode = vim.tbl_contains({ "norm", "vis", "cmd" }, mode)
    add_diags(stl, buf)

    local clients = vim.lsp.get_clients({ bufnr = buf })
    table.insert(stl, clients and #clients >= 1 and string.format("[%d] ", #clients) or "")
    if not (clients and opts.progress and display_mode) then
        return table.insert(stl, "%*")
    end

    local is_attached = vim.tbl_contains(clients, function(c)
        return c.id == opts.progress.client_id
    end, { predicate = true })
    if not is_attached then
        return table.insert(stl, "%*")
    end

    local values = opts.progress.params.value
    local pct = values.kind == "end" and "(Complete) "
        or (values.percentage and string.format("(%d%%%%) ", values.percentage) or "")
    local name = vim.lsp.get_client_by_id(opts.progress.client_id).name
    local message = opts.progress.msg and string.format(" - %s", values.msg) or ""

    table.insert(stl, string.format("%s%s: %s%s%%*", pct, name, values.title, message))
end

local function build_active_x(stl, opts)
    opts = opts or {}
    local hl = stl_data[string.format("%s-c", (opts.mode or "norm"))]

    local bufnr = opts.buf or vim.api.nvim_get_current_buf()
    local encoding = vim.api.nvim_get_option_value("encoding", { scope = "local" })
    local format = vim.api.nvim_get_option_value("fileformat", { buf = bufnr })
    local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

    table.insert(stl, string.format("%%#%s#%s %s %s %%*", hl, encoding, format_icons[format], ft))
end

local function build_active_y_z(stl, opts)
    opts = opts or {}
    local hl_y = stl_data[string.format("%s-b", (opts.mode or "norm"))]
    local hl_z = stl_data[string.format("%s-a", (opts.mode or "norm"))]
    local fn = " %{v:lua.require'mjm.stl-data'.get_scroll_pct()}%% %*"
    table.insert(
        stl,
        string.format("%%#%s#%s%%#%s# %%l/%%L | %%c | v:%%v | %%o %%*", hl_y, fn, hl_z)
    )
end

function M.set_active_stl(opts)
    opts = opts or {}
    local win = vim.api.nvim_get_current_win()

    if opts.buf then
        local found = false
        local wins = vim.api.nvim_list_wins()
        for _, w in pairs(wins) do
            if vim.api.nvim_win_get_buf(w) == opts.buf then
                found = true
                break
            end
        end
        if not found then
            return
        end
    end

    opts.mode = stl_data.modes[vim.fn.mode()]
    local stl = {}

    build_active_a(stl, opts)
    build_active_b(stl, opts)
    build_active_c(stl, opts)
    build_separator(stl, opts)
    build_active_x(stl, opts)
    build_active_y_z(stl, opts)

    vim.api.nvim_set_option_value("stl", table.concat(stl, ""), { win = win })
end

local function build_inactive_b(stl, opts)
    opts = opts or {}
    local hl = stl_data[string.format("%s-b", (opts.mode or "norm"))]
    table.insert(stl, string.format("%%#%s#", hl))

    table.insert(stl, " %m %t ")

    table.insert(stl, "%*")
end

local function build_inactive_y(stl, opts)
    opts = opts or {}
    local hl = stl_data[string.format("%s-b", (opts.mode or "norm"))]
    table.insert(stl, string.format("%%#%s#", hl))

    local scroll_pct = require("mjm.stl-data").get_scroll_pct(opts)
    -- Unlike the active statusline, place the result here so it doesn't dynamically update
    table.insert(stl, string.format(" %d%%%% ", scroll_pct))

    table.insert(stl, "%*")
end

function M.set_inactive_stl(opts)
    opts = opts or {}
    if not opts.win then
        return vim.notify("No window provided to set_inactive_stl", vim.log.levels.WARN)
    end

    local stl = {}

    build_inactive_b(stl)
    build_separator(stl)
    build_inactive_y(stl)

    vim.api.nvim_set_option_value("stl", table.concat(stl, ""), { win = opts.win })
end

return M

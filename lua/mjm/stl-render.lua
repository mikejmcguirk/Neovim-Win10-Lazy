-- TODO: When LSP progress messages send, elements A and B are shrunk to accomodate them
-- Those elements should stay stable
-- MAYBE: Could explore adding the char index. But it looks like I would need to compute that in
-- Lua, which might incur a performance cost
-- MAYBE: Build inactive stl as a Lua function that takes the window number as a parameter
-- Allows for showing diags

local M = {}

local stl_data = require("mjm.stl-data")

local diag_icons = Has_Nerd_Font
        and { ERROR = "󰅚", WARN = "󰀪", INFO = "󰋽", HINT = "󰌶" }
    or { ERROR = "E:", WARN = "W:", INFO = "I:", HINT = "H:" }

local format_icons = Has_Nerd_Font and { unix = "", dos = "", mac = "" }
    or { unix = "unix", dos = "dos", mac = "mac" }

local git_symbol = Has_Nerd_Font and " " or " "

local function build_separator(stl, opts)
    opts = opts or {}
    local hl = stl_data[string.format("%s-c", (opts.mode or "norm"))]
    table.insert(stl, "%#" .. hl .. "#%=%*")
end

local function build_active_a(stl, opts)
    opts = opts or {}
    local hl = stl_data[string.format("%s-a", (opts.mode or "norm"))]

    local head = stl_data.head and string.format(" %s ", stl_data.head) or " "

    table.insert(stl, "%#" .. hl .. "#" .. git_symbol .. head)
end

local function build_active_b(stl, opts)
    opts = opts or {}
    local hl = stl_data[string.format("%s-b", (opts.mode or "norm"))]
    table.insert(stl, "%#" .. hl .. "# %m %f %*")
end

-- TODO: Do not need to individually get the mode and buf for each diag
-- But wait to outline until architecture has re-settled in
function M.get_diags(level)
    local mode = stl_data.modes[vim.fn.mode()] or "norm"
    if not vim.tbl_contains({ "norm", "vis", "cmd" }, mode) then
        return ""
    end

    local buf = vim.api.nvim_get_current_buf()
    local diag_counts = stl_data.diag_cache[tostring(buf)]
    if not diag_counts then
        return ""
    end

    local count = diag_counts[level]
    if count == 0 then
        return ""
    end

    return string.format("%s %d ", diag_icons[level], count)
end

function M.get_lsps()
    local buf = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients({ bufnr = buf })

    if clients and #clients >= 1 then
        return string.format("[%d]", #clients)
    else
        return ""
    end
end

function M.get_progress()
    if not stl_data.progress then
        return ""
    end

    local mode = stl_data.modes[vim.fn.mode()] or "norm"
    if not vim.tbl_contains({ "norm", "vis", "cmd" }, mode) then
        return ""
    end

    local values = stl_data.progress.params.value

    local pct = (function()
        if values.kind == "end" then
            return "(Complete) "
        elseif values.percentage then
            return string.format("%d%% ", values.percentage)
        else
            return ""
        end
    end)()

    local name = vim.lsp.get_client_by_id(stl_data.progress.client_id).name
    local message = stl_data.progress.msg and " - " .. values.msg or ""

    return pct .. name .. ": " .. values.title .. message
end

local function build_active_c(stl, opts)
    opts = opts or {}
    local mode = opts.mode or "norm"
    local hl = stl_data[string.format("%s-c", mode)]
    table.insert(stl, "%#" .. hl .. "# ")

    local err_hl = "%#DiagnosticError#" .. "%{v:lua.require'mjm.stl-render'.get_diags('ERROR')}%*"
    local warn_hl = "%#DiagnosticWarn#" .. "%{v:lua.require'mjm.stl-render'.get_diags('WARN')}%*"
    local info_hl = "%#DiagnosticInfo#" .. "%{v:lua.require'mjm.stl-render'.get_diags('INFO')}%*"
    local hint_hl = "%#DiagnosticHint#" .. "%{v:lua.require'mjm.stl-render'.get_diags('HINT')}%*"

    local diags = err_hl .. warn_hl .. info_hl .. hint_hl
    -- local diags = "%{v:lua.require'mjm.stl-render'.get_diags()} %*"
    local lsp_count = "%{v:lua.require'mjm.stl-render'.get_lsps()} "
    local progress = "%{v:lua.require'mjm.stl-render'.get_progress()} %*"

    table.insert(stl, diags .. lsp_count .. progress)
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

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

function M.get_section_hl(section)
    local mode = stl_data.modes[vim.fn.mode()] or "norm"
    local hl = stl_data[mode .. "-" .. section]
    return "%#" .. hl .. "#"
end

local function build_active_a(stl)
    local head = stl_data.head and string.format(" %s ", stl_data.head) or " "

    table.insert(stl, git_symbol .. head)
end

-- TODO: How to only add spacing for the %m option if it displays
local function build_active_b(stl)
    table.insert(stl, " %m %f ")
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
        return string.format("[%d] ", #clients)
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

local function build_active_c(stl)
    -- The component elements contain a space after if they return a value
    local err_hl = "%#DiagnosticError#" .. "%{v:lua.require'mjm.stl-render'.get_diags('ERROR')}%*"
    local warn_hl = "%#DiagnosticWarn#" .. "%{v:lua.require'mjm.stl-render'.get_diags('WARN')}%*"
    local info_hl = "%#DiagnosticInfo#" .. "%{v:lua.require'mjm.stl-render'.get_diags('INFO')}%*"
    local hint_hl = "%#DiagnosticHint#" .. "%{v:lua.require'mjm.stl-render'.get_diags('HINT')}%*"

    local diags = err_hl .. warn_hl .. info_hl .. hint_hl
    -- local diags = "%{v:lua.require'mjm.stl-render'.get_diags()} %*"
    local lsp_count = "%{v:lua.require'mjm.stl-render'.get_lsps()}"
    local progress = "%{v:lua.require'mjm.stl-render'.get_progress()}"

    table.insert(stl, " " .. diags .. lsp_count .. progress)
end

-- TODO: Ain't no way there aren't built-ins for any of these
local function build_active_x(stl)
    local bufnr = vim.api.nvim_get_current_buf()
    local encoding = vim.api.nvim_get_option_value("encoding", { scope = "local" })
    local format = vim.api.nvim_get_option_value("fileformat", { buf = bufnr })
    local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

    table.insert(stl, string.format("%s %s %s ", encoding, format_icons[format], ft))
end

local function build_active_y(stl)
    table.insert(stl, " %{v:lua.require'mjm.stl-data'.get_scroll_pct()}%% ")
end

local function build_active_z(stl)
    table.insert(stl, " %l/%L | %c | v:%v | %o ")
end

--- TODO: Have a separate set_global_stl function that basically does this logic
--- Want to avoid having to do the if check each time this is run

--- @param global? boolean
function M.set_active_stl(global)
    local stl = {}

    table.insert(stl, "%{%v:lua.require'mjm.stl-render'.get_section_hl('a')%}")
    build_active_a(stl)
    table.insert(stl, "%*")

    table.insert(stl, "%{%v:lua.require'mjm.stl-render'.get_section_hl('b')%}")
    build_active_b(stl)
    table.insert(stl, "%*")

    table.insert(stl, "%{%v:lua.require'mjm.stl-render'.get_section_hl('c')%}")
    build_active_c(stl)
    table.insert(stl, "%*")

    table.insert(stl, "%{%v:lua.require'mjm.stl-render'.get_section_hl('c')%}")
    table.insert(stl, "%=")
    table.insert(stl, "%*")

    table.insert(stl, "%{%v:lua.require'mjm.stl-render'.get_section_hl('c')%}")
    build_active_x(stl)
    table.insert(stl, "%*")

    table.insert(stl, "%{%v:lua.require'mjm.stl-render'.get_section_hl('b')%}")
    build_active_y(stl)
    table.insert(stl, "%*")

    table.insert(stl, "%{%v:lua.require'mjm.stl-render'.get_section_hl('a')%}")
    build_active_z(stl)
    table.insert(stl, "%*")

    local stl_str = table.concat(stl, "")

    if global then
        vim.api.nvim_set_option_value("stl", stl_str, { scope = "global" })
    end

    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_option_value("stl", stl_str, { win = win })
end

function M.set_inactive_stl(win)
    if not win then
        return vim.notify("No window provided to set_inactive_stl", vim.log.levels.WARN)
    end

    local stl = {}

    table.insert(stl, "%{%v:lua.require'mjm.stl-render'.get_section_hl('b')%}")
    table.insert(stl, " %m %t ")
    table.insert(stl, "%*")

    table.insert(stl, "%{%v:lua.require'mjm.stl-render'.get_section_hl('c')%}")
    table.insert(stl, "%=")
    table.insert(stl, "%*")

    table.insert(stl, "%{%v:lua.require'mjm.stl-render'.get_section_hl('b')%}")
    local scroll_pct = require("mjm.stl-data").get_scroll_pct()
    -- Unlike the active statusline, place the result here so it doesn't dynamically update
    table.insert(stl, string.format(" %d%%%% ", scroll_pct))
    table.insert(stl, "%*")

    vim.api.nvim_set_option_value("stl", table.concat(stl, ""), { win = win })
end

return M

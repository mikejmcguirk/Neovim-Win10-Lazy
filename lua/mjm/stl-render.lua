-- TODO: When LSP progress messages send, elements A and B are shrunk to accomodate them
-- Those elements should stay stable
-- MAYBE: Could explore adding the char index. But it looks like I would need to compute that in
-- Lua, which might incur a performance cost. Real time rendering has already been significantly
-- cut back due to flickering
-- MAYBE: Build inactive stl as a Lua function that takes the window number as a parameter
-- Allows for showing diags
-- FUTURE: The stl can be reduced to two colors by combining the filename with the git info and
-- the % progress with the col info. But this might require adjusting what are currently the "c"
-- sections. Also, right now the current aesthetic changes make telling inactive windows easier
-- There's also the congruity with powerline. A simple fix might be though: make the "c" text
-- string colored, but then white in inactive windows

local M = {}

local stl_data = require("mjm.stl-data")

-- FUTURE: Hard icons to get out of because they're ergonomic
local diag_icons = Has_Nerd_Font
        and { ERROR = "󰅚", WARN = "󰀪", INFO = "󰋽", HINT = "󰌶" }
    or { ERROR = "E:", WARN = "W:", INFO = "I:", HINT = "H:" }

-- local format_icons = Has_Nerd_Font and { unix = "", dos = "", mac = "" }
--     or { unix = "unix", dos = "dos", mac = "mac" }
local format_icons = { unix = "unix", dos = "dos", mac = "mac" }

local function get_section_hl(stl, section)
    local mode = stl_data.modes[vim.fn.mode()] or "norm"
    local hl = stl_data[mode .. "-" .. section]
    table.insert(stl, "%#" .. hl .. "#")
end

local function build_active_a(stl)
    local head_info = stl_data.head and string.format(" %s ", stl_data.head) or " "
    table.insert(stl, head_info)
end

-- TODO: How to only add spacing for the %m option if it displays
local function build_active_b(stl)
    table.insert(stl, " %m %f ")
end

local function get_lsps()
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
    local diags = (function()
        local mode = stl_data.modes[vim.fn.mode()] or "norm"
        if not vim.tbl_contains({ "norm", "vis", "cmd" }, mode) then
            return ""
        end

        local buf = vim.api.nvim_get_current_buf()
        local diag_counts = stl_data.diag_cache[tostring(buf)]
        if not diag_counts then
            return ""
        end

        local diag_str = vim.iter({ "Error", "Warn", "Info", "Hint" }):fold("", function(acc, l)
            local upper_l = string.upper(l)
            local count = diag_counts[upper_l]
            if count < 1 then
                return acc
            end

            return string.format("%s%%#Diagnostic%s#%s %d %%*", acc, l, diag_icons[upper_l], count)
        end)

        return diag_str
    end)()

    local progress = "%{v:lua.require'mjm.stl-render'.get_progress()}"

    table.insert(stl, " " .. diags .. get_lsps() .. progress)
end

-- FUTURE: Create events for encoding, format, and filetype changes to refresh stl
local function build_active_x(stl)
    local encoding = vim.api.nvim_get_option_value("encoding", { scope = "local" })

    local bufnr = vim.api.nvim_get_current_buf()
    local format = vim.api.nvim_get_option_value("fileformat", { buf = bufnr })

    local ft = vim.api.nvim_get_option_value("ft", { buf = bufnr })
    local ft_str = ft == "" and "" or "| " .. ft .. " "

    table.insert(stl, encoding .. " | " .. format_icons[format] .. " " .. ft_str)
end

local function build_active_y(stl)
    table.insert(stl, " %{v:lua.require'mjm.stl-data'.get_scroll_pct()}%% ")
end

local function build_active_z(stl)
    table.insert(stl, " %l/%L | %c | v:%v | %o ")
end
function M.set_active_stl()
    local stl = {}

    get_section_hl(stl, "a")
    build_active_a(stl)
    table.insert(stl, "%*")

    get_section_hl(stl, "b")
    build_active_b(stl)
    table.insert(stl, "%*")

    table.insert(stl, "%<")
    get_section_hl(stl, "c")
    build_active_c(stl)
    table.insert(stl, "%*")

    get_section_hl(stl, "c")
    table.insert(stl, "%=")
    table.insert(stl, "%*")

    get_section_hl(stl, "c")
    build_active_x(stl)
    table.insert(stl, "%*")

    get_section_hl(stl, "b")
    build_active_y(stl)
    table.insert(stl, "%*")

    get_section_hl(stl, "a")
    build_active_z(stl)
    table.insert(stl, "%*")

    local stl_str = table.concat(stl, "")

    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_option_value("stl", stl_str, { win = win })
end

function M.set_inactive_stl(win)
    if not win then
        return vim.notify("No window provided to set_inactive_stl", vim.log.levels.WARN)
    end

    local stl = {}

    get_section_hl(stl, "b")
    table.insert(stl, " %m %t ")
    table.insert(stl, "%*")

    get_section_hl(stl, "c")
    table.insert(stl, "%=")
    table.insert(stl, "%*")

    get_section_hl(stl, "b")
    local scroll_pct = require("mjm.stl-data").get_scroll_pct()
    -- Unlike the active statusline, this should be a static value
    table.insert(stl, string.format(" %d%%%% ", scroll_pct))
    table.insert(stl, "%*")

    vim.api.nvim_set_option_value("stl", table.concat(stl, ""), { win = win })
end

return M

-- TODO: When LSP progress messages send, elements A and B are shrunk to accomodate them
-- Those elements should stay stable
-- TODO: Truncate long filenames in split windows
-- TODO: Build a character index component and keep it commented out alongside the virt col one
-- MAYBE: Build inactive stl as a Lua function that takes the window number as a parameter
-- Allows for showing diags

local M = {}

function M.bad_mode(mode)
    return string.match(mode, "[csSiR]")
end

local levels = { "Error", "Warn", "Info", "Hint" }
-- local signs = Has_Nerd_Font and { "󰅚", "󰀪", "󰋽", "󰌶" } or { "E:", "W:", "I:", "H:" }
local signs = { "E:", "W:", "I:", "H:" }

-- local format_icons = Has_Nerd_Font and { unix = "", dos = "", mac = "" }
--     or { unix = "unix", dos = "dos", mac = "mac" }
local format_icons = { unix = "unix", dos = "dos", mac = "mac" }

local function build_active_a(stl)
    -- local head_info = stl_data.head and string.format(" %s ", stl_data.head) or " "
    -- table.insert(stl, head_info)
    table.insert(stl, " %#stl_a#%{FugitiveStatusline()}%*")
end

-- TODO: How to only add spacing for the %m option if it displays
local function build_active_b(stl, mode)
    table.insert(stl, " %#stl_b# %m %f [" .. mode .. "] %*")
end

local function get_lsps()
    local buf = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients({ bufnr = buf })

    if clients and #clients >= 1 then
        return string.format("[%d] %%<", #clients)
    else
        return "%<"
    end
end

-- NOTE: We are assuming in this function that we would not be given a progress message to
-- render unless we were in a valid mode
-- NOTE: This is, like the diags, fastering than caching
local function get_progress(progress)
    if not progress then
        return ""
    end

    local values = progress.params.value
    local pct = (function()
        if values.kind == "end" then
            return "(Complete) "
        elseif values.percentage then
            return string.format("%d%%%% ", values.percentage)
        else
            return ""
        end
    end)()

    local name = vim.lsp.get_client_by_id(progress.client_id).name
    local message = progress.msg and " - " .. values.msg or ""

    return pct .. name .. ": " .. values.title .. message
end

-- Put the LSP to the left of the diags so it canb e cut off on short windows
local function build_active_c(stl, mode, progress)
    -- This actually performs better than caching
    local diags = (function()
        if M.bad_mode(mode) then
            return ""
        end

        local counts = vim.diagnostic.count(0)
        if not counts then
            return ""
        end

        local diag_str = vim.iter(pairs(counts))
            :map(function(s, count)
                return string.format("%%#Diagnostic%s#%s%d%%* ", levels[s], signs[s], count)
            end)
            :join("")

        return diag_str
    end)()

    table.insert(stl, " %#stl_c#" .. get_lsps() .. diags .. get_progress(progress) .. "%*")
end

-- FUTURE: Create events for encoding, format, and filetype changes to refresh stl
local function build_active_x(stl)
    local encoding = vim.api.nvim_get_option_value("encoding", { scope = "local" })

    local bufnr = vim.api.nvim_get_current_buf()
    local format = vim.api.nvim_get_option_value("fileformat", { buf = bufnr })

    local ft = vim.api.nvim_get_option_value("ft", { buf = bufnr })
    local ft_str = ft == "" and "" or "| " .. ft

    local icons = format_icons[format]
    table.insert(stl, "%#stl_c# " .. encoding .. " | " .. icons .. " " .. ft_str .. "%*")
end

function M.get_scroll_pct()
    local win = vim.api.nvim_get_current_win()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local tot_rows = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))

    if row == tot_rows then
        return 100
    end

    local pct = math.floor(row / tot_rows * 100)
    pct = math.min(pct, 99)
    pct = math.max(pct, 1)
    return pct
end

local function build_active_y(stl)
    table.insert(stl, " %#stl_b# %{v:lua.require'mjm.stl-render'.get_scroll_pct()}%% %*")
end

local function build_active_z(stl)
    -- Only use virtcol component when necessary. Causes performance hit + cursor flicker
    -- table.insert(stl, " %l/%L | %c | v:%v | %o ")
    table.insert(stl, " %#stl_a#%l/%L | %c | %o %*")
end

function M.set_active_stl(progress)
    local stl = {}
    local mode = vim.fn.mode(1)

    build_active_a(stl)
    build_active_b(stl, mode)
    build_active_c(stl, mode, progress)

    table.insert(stl, "%=%*")

    build_active_x(stl)
    build_active_y(stl)
    build_active_z(stl)

    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_option_value("stl", table.concat(stl, ""), { win = win })
end

--- @param win integer
--- @return nil
function M.set_inactive_stl(win)
    if not win then
        return vim.notify("No window provided to set_inactive_stl", vim.log.levels.WARN)
    end

    if not vim.api.nvim_win_is_valid(win) then
        return
    end

    local stl = {}

    table.insert(stl, "%#stl_b#%m %t %*")
    table.insert(stl, "%=%*")

    local scroll_pct = M.get_scroll_pct()
    -- Unlike the active statusline, this should be a static value
    table.insert(stl, string.format("%%#stl_b# %d%%%% %%*", scroll_pct))

    vim.api.nvim_set_option_value("stl", table.concat(stl, ""), { win = win })
end

return M

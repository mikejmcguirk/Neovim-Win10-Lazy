local M = {}

-- Alchemical trident symbol
local symbol = Has_Nerd_Font and "\u{1F751}" or "|"
-- Alternatively, "\u{21CC}" (left over right harpoon)

local stl_data = require("mjm.stl-data")
local hl_active = stl_data["norm-b"]
local hl_inactive = stl_data["norm-a"]
local hl_separator = stl_data["norm-c"]

vim.o.showtabline = 2
vim.o.tabline = "%!v:lua.require('mjm.tal').get_tal()"

local function redraw_tal()
    vim.cmd("redrawt")
end

local ok, harpoon = pcall(require, "harpoon")
if ok then
    harpoon:extend({
        NAVIGATE = redraw_tal,
        ADD = redraw_tal,
        REMOVE = redraw_tal,
        REPLACE = redraw_tal,
    })
end

local function build_harpoon_component(tal)
    if not ok then
        return
    end

    local list = harpoon:list()
    if not list then
        return
    end

    local items = list.items
    if not items or #items < 1 then
        return
    end

    local cur_buf_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
    for i, t in pairs(items) do
        local t_path = vim.fn.fnamemodify(t.value, ":p")
        local hl = string.format("%%#%s#", (t_path == cur_buf_path) and hl_active or hl_inactive)

        local modified = (function()
            local t_bufnr = vim.fn.bufnr(t_path)
            if t_bufnr == -1 then
                return ""
            end

            return vim.api.nvim_get_option_value("modified", { buf = t_bufnr }) and "[+]" or ""
        end)()

        local t_basename = vim.fs.basename(t.value)
        local str = string.format("%s %d %s %s %s ", hl, i, symbol, t_basename, modified)
        table.insert(tal, str)
    end

    table.insert(tal, "%*")
end

local function build_tab_component(tal)
    local cur_tab = vim.api.nvim_get_current_tabpage()

    for i, t in pairs(vim.api.nvim_list_tabpages()) do
        local hl_group = (cur_tab == t) and hl_active or hl_inactive
        local hl = string.format("%%#%s#", hl_group)

        local t_wins = vim.api.nvim_tabpage_list_wins(t)
        local has_modified = false
        for _, w in pairs(t_wins) do
            local bufnr = vim.api.nvim_win_get_buf(w)
            if vim.api.nvim_get_option_value("modified", { buf = bufnr }) then
                has_modified = true
                break
            end
        end

        table.insert(tal, string.format("%s %d%s ", hl, i, (has_modified and " [+]" or "")))
    end
end

function M.get_tal()
    local tal = {}

    build_harpoon_component(tal)
    table.insert(tal, string.format("%%#%s#%%=%%*", hl_separator))
    build_tab_component(tal)

    return table.concat(tal)
end

return M

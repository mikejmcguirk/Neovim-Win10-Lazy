local api = vim.api
local fn = vim.fn

local M = {}

-- Alchemical trident symbol
local symbol = "\u{1F751}" ---@type string
-- Alternatively, "\u{21CC}" (left over right harpoon)

local hl_active = "stl_b" ---@type string
local hl_inactive = "stl_a" ---@type string
local hl_separator = "stl_c" ---@type string

local ok, harpoon = pcall(require, "harpoon")

local function build_harpoon_component(tal)
    if not ok then return "" end

    local list = harpoon:list() ---@type table
    if not list then return "" end

    local items = list.items
    if not items or #items < 1 then return "" end

    local cur_buf_path = api.nvim_buf_get_name(0) ---@type string
    for i, t in ipairs(items) do
        local t_path = fn.fnamemodify(t.value, ":p") ---@type string
        ---@type string
        local hl = string.format("%%#%s#", (t_path == cur_buf_path) and hl_active or hl_inactive)

        local modified = (function()
            local buf = fn.bufnr(t_path)
            if buf == -1 then return "" end

            return vim.api.nvim_get_option_value("modified", { buf = buf }) and "[+]" or ""
        end)() ---@type string

        local t_basename = vim.fs.basename(t.value) ---@type string
        ---@type string
        local str = string.format("%s %d %s %s %s ", hl, i, symbol, t_basename, modified)
        tal[#tal + 1] = str
    end

    tal[#tal + 1] = "%*"
end

-- Referenced as a string in the tal setting
function M.build_tab_component()
    local cur_tab = api.nvim_get_current_tabpage() ---@type integer
    local tabs = {} ---@type string[]

    for i, t in ipairs(api.nvim_list_tabpages()) do
        local hl_group = (cur_tab == t) and hl_active or hl_inactive ---@type string
        local hl = string.format("%%#%s#", hl_group) ---@type string

        local t_wins = api.nvim_tabpage_list_wins(t) ---@type integer[]
        local has_modified = false ---@type boolean
        for _, w in ipairs(t_wins) do
            local bufnr = api.nvim_win_get_buf(w) ---@type integer
            if vim.api.nvim_get_option_value("modified", { buf = bufnr }) then
                has_modified = true
                break
            end
        end

        tabs[#tabs + 1] = string.format("%s %d%s ", hl, i, (has_modified and "[+]" or ""))
    end

    return table.concat(tabs, "")
end

local function build_tal()
    local tal = {}

    build_harpoon_component(tal)
    tal[#tal + 1] = string.format("%%#%s#%%=%%*", hl_separator)
    tal[#tal + 1] = "%{%v:lua.require('mjm.tal').build_tab_component()%}%*"

    vim.api.nvim_set_option_value("tal", table.concat(tal, ""), { scope = "global" })
end

if ok then
    harpoon:extend({
        -- NAVIGATE = build_tal,
        ADD = build_tal,
        REMOVE = build_tal,
        REPLACE = build_tal,
    })
end

local tal_events = vim.api.nvim_create_augroup("tal-events", { clear = true }) ---@type integer

vim.api.nvim_create_autocmd({ "BufModifiedSet", "CmdlineLeave" }, {
    group = tal_events,
    callback = function()
        build_tal()
    end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
    group = tal_events,
    callback = function()
        -- Leave autocmd context so cur_buf is correct
        vim.schedule(function()
            build_tal()
        end)
    end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = tal_events,
    callback = function()
        -- For edge case where you change Windows in insert mode. Wait for event to be over to
        -- check mode fresh
        vim.schedule(function()
            -- Avoid rendering in autocompletion windows
            if fn.mode() == "i" then return end

            build_tal()
        end)
    end,
})

vim.api.nvim_set_option_value("stal", 2, { scope = "global" })
build_tal()

return M

-- FUTURE: Build out the harpoon tabline as a lua function that holds the current state in the
-- background so that redraws of the tal don't have to perform all that logic on demand
-- You should be able to feed it the highlight groups for customization, and then it should
-- be possible to just drop the lua fn into any tabline plugin. If you make it based on what
-- Neovim's doing, it requires too many assumptions about how Neovim's state changes occur
-- Example: For buf modified post, should just get event buf, tick state, and redraw if it's
-- on the tabline
-- https://github.com/mike-jl/harpoonEx/blob/main/lua/lualine/components/harpoons/init.lua
-- Future thing: Harpoon gets the current dir from vim.loop.cwd() (would upgrade to vim.uv),
-- if the directory is nil, it causes an enter error

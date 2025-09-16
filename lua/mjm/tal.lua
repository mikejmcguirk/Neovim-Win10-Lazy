-- FUTURE: Build out the harpoon tabline as a lua function that holds the current state in the
-- background so that redraws of the tal don't have to perform all that logic on demand
-- You should be able to feed it the highlight groups for customization, and then it should
-- be possible to just drop the lua fn into any tabline plugin. If you make it based on what
-- Neovim's doing, it requires too many assumptions about how Neovim's state changes occur
-- Example: For buf modified post, should just get event buf, tick state, and redraw if it's
-- on the tabline
-- https://github.com/mike-jl/harpoonEx/blob/main/lua/lualine/components/harpoons/init.lua
-- Future thing: Harpoon gets the current dir from vim.looop.cwd() (would upgrade to vim.uv),
-- if the directory is nil, it causes an enter error

local M = {}

local symbol = Has_Nerd_Font and "\u{1F751}" or "|" -- Alchemical trident symbol
-- Alternatively, "\u{21CC}" (left over right harpoon)

local hl_active = "stl_b"
local hl_inactive = "stl_a"
local hl_separator = "stl_c"

local ok, harpoon = pcall(require, "harpoon")

local function build_harpoon_component(tal)
    if not ok then
        return ""
    end

    local list = harpoon:list()
    if not list then
        return ""
    end

    local items = list.items
    if not items or #items < 1 then
        return ""
    end

    local cur_buf_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
    for i, t in ipairs(items) do
        local t_path = vim.fn.fnamemodify(t.value, ":p")
        local hl = string.format("%%#%s#", (t_path == cur_buf_path) and hl_active or hl_inactive)

        local modified = (function()
            local buf = vim.fn.bufnr(t_path)
            if buf == -1 then
                return ""
            end

            return vim.api.nvim_get_option_value("modified", { buf = buf }) and "[+]" or ""
        end)()

        local t_basename = vim.fs.basename(t.value)
        local str = string.format("%s %d %s %s %s ", hl, i, symbol, t_basename, modified)
        table.insert(tal, str)
    end

    table.insert(tal, "%*")
end

function M.build_tab_component()
    local cur_tab = vim.api.nvim_get_current_tabpage()

    local tabs = {}
    for i, t in ipairs(vim.api.nvim_list_tabpages()) do
        local hl_group = (cur_tab == t) and hl_active or hl_inactive
        local hl = string.format("%%#%s#", hl_group)

        local t_wins = vim.api.nvim_tabpage_list_wins(t)
        local has_modified = false
        for _, w in ipairs(t_wins) do
            local bufnr = vim.api.nvim_win_get_buf(w)
            if vim.api.nvim_get_option_value("modified", { buf = bufnr }) then
                has_modified = true
                break
            end
        end

        table.insert(tabs, string.format("%s %d%s ", hl, i, (has_modified and "[+]" or "")))
    end

    return table.concat(tabs, "")
end

local function build_tal()
    local tal = {}

    build_harpoon_component(tal)
    table.insert(tal, string.format("%%#%s#%%=%%*", hl_separator))
    table.insert(tal, "%{%v:lua.require('mjm.tal').build_tab_component()%}%*")

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

local tal_events = vim.api.nvim_create_augroup("tal-events", { clear = true })

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
            if vim.fn.mode() == "i" then
                return
            end

            build_tal()
        end)
    end,
})

vim.api.nvim_set_option_value("stal", 2, { scope = "global" })
build_tal()

return M

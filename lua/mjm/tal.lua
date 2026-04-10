local api = vim.api
local fn = vim.fn
local fs = vim.fs

-- Alchemical trident symbol
local symbol = "\u{1F751}"
-- Alternatively, "\u{21CC}" (left over right harpoon)
local hl_active = "stl_b"
local hl_inactive = "stl_a"
local hl_separator = "stl_c"
local ok, harpoon = pcall(require, "harpoon")

local M = {}

---@param bufname string
---@return string
local function get_mod_elem(bufname)
    local bufnr = fn.bufnr(bufname)
    if bufnr == -1 then
        return ""
    end

    return api.nvim_get_option_value("mod", { buf = bufnr }) and "[+]" or ""
end

---@param tal string[]
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

    local basename_count = {}
    for _, t in ipairs(items) do
        local basename = fs.basename(t.value)
        basename_count[basename] = (basename_count[basename] or 0) + 1
    end

    local cur_buf_path = api.nvim_buf_get_name(0)
    for i, item in ipairs(items) do
        local path = fs.normalize(fn.fnamemodify(item.value, ":p"))

        local is_cur_buf = path == cur_buf_path
        local hl_group = is_cur_buf and hl_active or hl_inactive
        local elem_hl = string.format("%%#%s#", hl_group)
        local mod_elem = get_mod_elem(path)

        local basename = fs.basename(path)
        local name_elem = basename_count[basename] > 1 and fn.fnamemodify(item.value, ":~:.")
            or basename

        tal[#tal + 1] = string.format("%s %d %s %s %s ", elem_hl, i, symbol, name_elem, mod_elem)
    end

    tal[#tal + 1] = "%*"
end

---Referenced in the tal expression
---@return string
function M.build_tabpage_component()
    local cur_tabpage = api.nvim_get_current_tabpage()

    local tabpages = {} ---@type string[]
    for i, tabpage in ipairs(api.nvim_list_tabpages()) do
        local hl_group = (cur_tabpage == tabpage) and hl_active or hl_inactive
        local hl = string.format("%%#%s#", hl_group)

        local tabpage_wins = api.nvim_tabpage_list_wins(tabpage)
        local has_modified = false
        for _, w in ipairs(tabpage_wins) do
            local bufnr = api.nvim_win_get_buf(w)
            if vim.api.nvim_get_option_value("mod", { buf = bufnr }) then
                has_modified = true
                break
            end
        end

        local mod_elem = has_modified and "[+]" or ""
        tabpages[#tabpages + 1] = string.format("%s %d%s ", hl, i, mod_elem)
    end

    return table.concat(tabpages, "")
end
local function build_tal()
    local tal = {} ---@type string[]

    build_harpoon_component(tal)
    tal[#tal + 1] = string.format("%%#%s#%%=%%*", hl_separator)
    tal[#tal + 1] = "%{%v:lua.require('mjm.tal').build_tabpage_component()%}%*"

    api.nvim_set_option_value("tal", table.concat(tal, ""), { scope = "global" })
end

if ok then
    harpoon:extend({
        -- NAVIGATE = build_tal,
        ADD = build_tal,
        REMOVE = build_tal,
        REPLACE = build_tal,
    })
end

local tal_events = vim.api.nvim_create_augroup("mjm-tal-events", {})
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
            -- Overly cute way to check if we are in insert or replace mode
            -- Avoid rendering due to autocompletion windows
            local short_mode = string.byte(api.nvim_get_mode().mode, 1)
            if short_mode == 105 or short_mode == 82 then
                return
            end

            build_tal()
        end)
    end,
})

api.nvim_set_option_value("stal", 2, { scope = "global" })
build_tal()

return M

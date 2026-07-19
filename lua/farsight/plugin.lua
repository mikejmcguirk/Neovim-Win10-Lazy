local api = vim.api
local fn = vim.fn

-- stylua: ignore
local maps = {
{ { "n", "x", "o" }, "<Plug>(farsight-live-fwd)", ";", "",
    "Enter characters to jump forward to a label", function()
        require("farsight").live.fwd()
    end, },
{ { "n", "x", "o" }, "<Plug>(farsight-live-rev)", ",", "",
    "Enter characters to jump backward to a label", function()
        require("farsight").live.rev()
    end, },
{ { "n", "x", "o" }, "<Plug>(farsight-csearch-fwd)", "f", "",
    "Char search forward", function()
        require("farsight").csearch.fwd()
    end, },
{ { "n", "x", "o" }, "<Plug>(farsight-csearch-rev)", "F", "",
    "Char search backward", function()
        require("farsight").csearch.rev()
    end, },
{ { "n", "x", "o" }, "<Plug>(farsight-csearch-till-fwd)", "t", "",
    "Char search forward till", function()
        require("farsight").csearch.fwd_till()
    end, },
{ { "n", "x", "o" }, "<Plug>(farsight-csearch-till-rev)", "T", "",
    "Char search backward till", function()
        require("farsight").csearch.rev_till()
    end, },
{ { "n", "x", "o" }, "<Plug>(farsight-static)", "<cr>", "",
    "Jump to a pre-calculated label", function()
        require("farsight").static()
    end, },
}

for _, map in ipairs(maps) do
    for _, mode in ipairs(map[1]) do
        api.nvim_set_keymap(mode, map[2], map[4], {
            noremap = true,
            desc = map[5],
            callback = map[6],
        })
    end
end

-- TODO-DEP: Remove this when 0.14 comes out.
api.nvim_set_hl(0, "Dimmed", { default = true, link = "Comment" })

local hls = {
    { "farsightCsearchDim", "Dimmed" },
    { "farsightCsearchChar", "Search" },
    { "farsightCsearchCurChar", "CurSearch" },
    { "farsightCsearchLabel1st", "IncSearch" },
    { "farsightCsearchLabel2nd", "CurSearch" },
    { "farsightCsearchLabel3rd", "Search" },
    { "farsightLiveDim", "Dimmed" },
    { "farsightLiveResult", "Search" },
    { "farsightLiveLabel", "IncSearch" },
    { "farsightStaticDim", "Dimmed" },
    { "farsightStaticLabel", "CurSearch" },
    { "farsightStaticTargetLabel", "IncSearch" },
}

for _, hl in ipairs(hls) do
    api.nvim_set_hl(0, hl[1], { default = true, link = hl[2] })
end

local farsight = require("farsight")
if not farsight.config.default_keymaps_set then
    return
end

for _, map in ipairs(maps) do
    for _, mode in ipairs(map[1]) do
        -- MID: Use `mapcheck()` or `hasmapto()`
        local lhs = map[3]
        local maparg_res = fn.maparg(lhs, mode)
        ---@cast maparg_res string
        -- Check if <cr> is mapped to itself for unsimplification
        if maparg_res == "" or string.lower(maparg_res) == lhs then
            api.nvim_set_keymap(mode, lhs, map[2], { noremap = true, desc = map[5] })
        end
    end
end

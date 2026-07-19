local api = vim.api
local fn = vim.fn

-- stylua: ignore
local maps = {
{ { "n", "x", "o" }, "<Plug>(farsight-live-fwd)", ";", "",
    "Jump to next document highlight", function()
        require("farsight").live.fwd()
    end, },
{ { "n", "x", "o" }, "<Plug>(farsight-live-rev)", ",", "",
    "Jump to first document highlight", function()
        require("farsight").live.rev()
    end, },
{ { "n", "x", "o" }, "<Plug>(farsight-csearch-fwd)", "f", "",
    "Jump to last document highlight", function()
        require("farsight").csearch.fwd()
    end, },
{ { "n", "x", "o" }, "<Plug>(farsight-csearch-rev)", "F", "",
    "Rename a symbol with a default prompt", function()
        require("farsight").csearch.rev()
    end, },
{ { "n", "x", "o" }, "<Plug>(farsight-csearch-till-fwd)", "t", "",
    "Jump to last document highlight", function()
        require("farsight").csearch.fwd_till()
    end, },
{ { "n", "x", "o" }, "<Plug>(farsight-csearch-till-rev)", "T", "",
    "Rename a symbol with a default prompt", function()
        require("farsight").csearch.rev_till()
    end, },
{ { "n", "x", "o" }, "<Plug>(farsight-static)", "<cr>", "",
    "Jump to previous document highlight", function()
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

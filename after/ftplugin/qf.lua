vim.opt_local.colorcolumn = ""
vim.o.buflisted = false

local ut = require("mjm.utils")
vim.keymap.set("n", "cui", function()
    ut.list_closer()
end, { buffer = true })

vim.keymap.set("n", "coi", function()
    ut.list_closer({ loclist = true })
end, { buffer = true })

vim.keymap.set("n", "cup", "<nop>", { buffer = true })
vim.keymap.set("n", "cop", "<nop>", { buffer = true })

-- NOTE: getloclist() requires the list's Window number. Unsure of how to get that inside
-- the location list window
vim.keymap.set("n", "dd", function()
    local cur_win = vim.api.nvim_get_current_win()
    local win_info = vim.fn.getwininfo(cur_win)[1]
    if win_info.quickfix == 1 and win_info.loclist == 1 then
        vim.notify("Cannot direct delete inside a location list")
        return
    end

    local cur_line = vim.fn.line(".") --- @type integer
    local qf_list = vim.fn.getqflist() --- @type any
    table.remove(qf_list, cur_line)

    vim.fn.setqflist(qf_list, "r")
    vim.cmd(":" .. tostring(cur_line))
end, { buffer = true })

-- Only put Nvim defaults here. For plugin specific maps, handle on a case-by-case basis
local bad_maps = { "<C-o>", "<C-i>" }
for _, map in pairs(bad_maps) do
    vim.keymap.set("n", map, function()
        vim.notify("Currently in error list")
    end, { buffer = true })
end

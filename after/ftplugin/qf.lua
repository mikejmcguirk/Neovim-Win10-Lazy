vim.opt_local.colorcolumn = ""
vim.o.buflisted = false

vim.keymap.set("n", "dd", function()
    local cur_line = vim.fn.line(".") --- @type integer
    local cur_win = vim.api.nvim_get_current_win()
    local win_info = vim.fn.getwininfo(cur_win)[1]
    if win_info.quickfix == 1 and win_info.loclist == 1 then
        local list = vim.fn.getloclist(cur_win)
        table.remove(list, cur_line)
        vim.fn.setloclist(cur_win, list, "r")
    else
        local list = vim.fn.getqflist()
        table.remove(list, cur_line)
        vim.fn.setqflist(list, "r")
    end

    vim.cmd(":" .. tostring(cur_line))
end, { buffer = true })

-- Only put Nvim defaults here. For plugin specific maps, handle on a case-by-case basis
local bad_maps = { "<C-o>", "<C-i>" }
for _, map in pairs(bad_maps) do
    vim.keymap.set("n", map, function()
        vim.notify("Currently in error list")
    end, { buffer = true })
end

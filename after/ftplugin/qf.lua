vim.opt_local.colorcolumn = ""
vim.o.buflisted = false

Map("n", "q", "<cmd>q<cr>", { buffer = true })

Map("n", "dd", function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local cur_win = vim.api.nvim_get_current_win()
    local win_info = vim.fn.getwininfo(cur_win)[1]
    if win_info.quickfix == 1 and win_info.loclist == 1 then
        local list = vim.fn.getloclist(cur_win)
        table.remove(list, row)
        vim.fn.setloclist(cur_win, list, "r")
    else
        local list = vim.fn.getqflist()
        table.remove(list, row)
        vim.fn.setqflist(list, "r")
    end

    vim.cmd(":" .. tostring(row))
end, { buffer = true })

Map("n", "<C-cr>", function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local cur_win = vim.api.nvim_get_current_win()
    local win_info = vim.fn.getwininfo(cur_win)[1]
    if win_info.quickfix == 1 and win_info.loclist == 1 then
        vim.cmd(row .. "ll | lclose")
    else
        vim.cmd(row .. "cc | cclose")
    end
end, { buffer = true })

local bad_maps = { "<C-o>", "<C-i>" }
for _, map in pairs(bad_maps) do
    Map("n", map, function()
        vim.notify("Currently in qf buffer")
    end, { buffer = true })
end

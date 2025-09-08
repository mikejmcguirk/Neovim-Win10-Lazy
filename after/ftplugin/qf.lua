vim.api.nvim_set_option_value("buflisted", false, { buf = 0 })

vim.opt_local.colorcolumn = ""
vim.opt_local.list = false

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

    Cmd({ cmd = "normal", args = { row .. "G" }, bang = true }, {})
end, { buffer = true })

-- MAYBE: Copied from the nvim-treesitter file. One dupe now. Maybe outline
local function get_vrange4()
    local cur = vim.fn.getpos(".")
    local fin = vim.fn.getpos("v")
    local mode = vim.fn.mode()

    local region = vim.fn.getregionpos(cur, fin, { type = mode, exclusive = false })
    return { region[1][1][2], region[1][1][3], region[#region][2][2], region[#region][2][3] }
end

Map("x", "d", function()
    local cur_mode = string.sub(vim.api.nvim_get_mode().mode, 1, 1) ---@type string
    if cur_mode ~= "V" then return end

    local vrange_4 = get_vrange4()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    Cmd({ cmd = "normal", args = { "\27" }, bang = true }, {})

    local win = vim.api.nvim_get_current_win()
    local win_info = vim.fn.getwininfo(win)[1]
    local is_loclist = win_info.quickfix == 1 and win_info.loclist == 1

    local list = is_loclist and vim.fn.getloclist(win) or vim.fn.getqflist()
    for i = vrange_4[3], vrange_4[1], -1 do
        table.remove(list, i)
    end

    if is_loclist then
        vim.fn.setloclist(win, list, "r")
    else
        vim.fn.setqflist(list, "r")
    end

    -- MAYBE: Second time I've had to write this code. Maybe outline
    local line_count = vim.api.nvim_buf_line_count(0)
    row = math.min(row, line_count)
    local set_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    col = math.min(col, #set_line - 1)
    col = math.max(col, 0)

    vim.api.nvim_win_set_cursor(win, { row, col })
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
    Map("n", map, function() vim.notify("Currently in qf buffer") end, { buffer = true })
end

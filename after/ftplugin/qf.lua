vim.opt_local.colorcolumn = ""

vim.keymap.set("n", "dd", function()
    local cur_line = vim.fn.line(".") --- @type number
    local qf_list = vim.fn.getqflist() --- @type any
    table.remove(qf_list, cur_line)

    vim.fn.setqflist(qf_list, "r")
    local reset_line_cmd = ":" .. tostring(cur_line)
    vim.cmd(reset_line_cmd)
end, { buffer = true })

vim.keymap.set("n", "<leader>qt", "<cmd>cclose<cr>", { buffer = true })

local bad_maps = { "<C-o>", "<C-i>" }
for _, map in pairs(bad_maps) do
    vim.keymap.set("n", map, function()
        vim.notify("Currently in quickfix list")
    end, { buffer = true })
end

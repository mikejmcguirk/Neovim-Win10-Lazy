vim.opt_local.colorcolumn = ""

vim.keymap.set("n", "<leader>qt", "<cmd>cclose<cr>", { buffer = true })
vim.keymap.set("n", "dd", function()
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
        vim.notify("Currently in quickfix list")
    end, { buffer = true })
end

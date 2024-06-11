vim.opt_local.colorcolumn = ""

vim.keymap.set("n", "dd", function()
    local cur_line = vim.fn.line(".")
    local qf_list = vim.fn.getqflist()
    table.remove(qf_list, cur_line)

    vim.fn.setqflist(qf_list, "r")
    local reset_line_cmd = ":" .. tostring(cur_line)
    vim.api.nvim_exec2(reset_line_cmd, {})
end, { buffer = true })

vim.keymap.set("n", "<leader>qt", "<cmd>cclose<cr>", { buffer = true })

vim.keymap.set("n", "<cr>", function()
    local cur_line = vim.fn.line(".")
    vim.api.nvim_exec2("cc! " .. cur_line, {})
    vim.api.nvim_exec2("botright copen", {})
    vim.api.nvim_exec2(":" .. cur_line, {})
end, { buffer = true })
vim.keymap.set("n", "<leader>qo", function()
    local cur_line = vim.fn.line(".")
    vim.api.nvim_exec2("cc! " .. tostring(cur_line), {})
    vim.api.nvim_exec2("cclose", {})
end)

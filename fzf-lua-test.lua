-- nvim -u fzf-lua-test.lua
vim.pack.add({ { src = "https://github.com/ibhagwan/fzf-lua" } })
vim.pack.update({ "fzf-lua" }, { force = true })

require("fzf-lua").setup({ ui_select = true })
vim.api.nvim_buf_set_lines(0, 0, 1, false, { "Hoyt" })
-- Run `z=`

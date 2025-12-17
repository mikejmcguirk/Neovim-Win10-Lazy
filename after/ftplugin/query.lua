local api = vim.api

require("mjm.utils").set_buf_space_indent(0, 2)
api.nvim_set_option_value("cc", "", { scope = "local" })
api.nvim_cmd({ cmd = "wincmd", args = { "=" } }, {})
vim.keymap.set("n", "q", "<cmd>bwipe<cr>", { buffer = 0 })

local api = vim.api

local width = 2
api.nvim_set_option_value("ts", width, { buf = 0 })
api.nvim_set_option_value("sts", width, { buf = 0 })
api.nvim_set_option_value("sw", width, { buf = 0 })

api.nvim_cmd({ cmd = "wincmd", args = { "=" } }, {})
api.nvim_set_option_value("cc", "", { scope = "local" })
vim.keymap.set("n", "q", "<cmd>bd<cr>", { buffer = true })

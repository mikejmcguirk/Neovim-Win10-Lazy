local devicons = "nvim-web-devicons"
vim.cmd.packadd({ vim.fn.escape(devicons, " "), bang = false, magic = { file = false } })

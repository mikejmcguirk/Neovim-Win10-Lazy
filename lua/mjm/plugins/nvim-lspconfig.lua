vim.cmd.packadd({
    vim.fn.escape("nvim-lspconfig", " "),
    bang = true,
    magic = { file = false },
})

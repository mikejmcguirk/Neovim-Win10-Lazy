vim.cmd.packadd({
    vim.fn.escape("vim-fugitive", " "),
    bang = true,
    magic = { file = false },
})

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("git-diff-ts", { clear = true }),
    pattern = "git",
    -- TODO: Should use nvim_cmd
    command = "set filetype=diff",
})

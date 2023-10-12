return {
    'rust-lang/rust.vim',
    ft = "rust",
    init = function()
        vim.g.rustfmt_autosave = 0
        vim.g.rustfmt_fail_silently = 1
    end
}

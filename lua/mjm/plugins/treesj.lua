require("treesj").setup({
    use_default_keymaps = false,
    max_join_length = 99,
    notify = false,
})

vim.keymap.set("n", "gs", require("treesj").toggle)
vim.keymap.set("n", "gS", function()
    require("treesj").split({ split = { recursive = true } })
end)

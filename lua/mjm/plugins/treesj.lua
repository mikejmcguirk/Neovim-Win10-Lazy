require("treesj").setup({
    use_default_keymaps = false,
    max_join_length = 99,
    notify = false,
})

Map("n", "gs", require("treesj").toggle)
Map("n", "gS", function()
    require("treesj").split({ split = { recursive = true } })
end)

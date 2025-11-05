return {
    "Wansmer/treesj",
    keys = { { "gs", nil, mode = "n" }, { "gS", nil, mode = "n" } },
    config = function()
        require("treesj").setup({
            max_join_length = 99,
            notify = false,
            use_default_keymaps = false,
        })

        vim.keymap.set("n", "gs", function()
            require("treesj").toggle()
        end)

        vim.keymap.set("n", "gS", function()
            require("treesj").split({ split = { recursive = true } })
        end)
    end,
}

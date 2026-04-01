return {
    "Wansmer/treesj",
    keys = {
        { "gJ", nil, mode = "n" },
        -- { "gS", nil, mode = "n" },
    },
    config = function()
        require("treesj").setup({
            max_join_length = 99,
            notify = false,
            use_default_keymaps = false,
        })

        vim.keymap.set("n", "gJ", function()
            require("treesj").toggle({ split = { recursive = true } })
        end)

        -- vim.keymap.set("n", "gS", function()
        --     require("treesj").split({ split = { recursive = true } })
        -- end)
    end,
}
-- MAYBE: If gJ with recursive is too much, can add another map in. gS is not terrible.

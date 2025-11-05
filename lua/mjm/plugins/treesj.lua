return {
    "Wansmer/treesj",
    keys = {
        {
            "gs",
            function()
                require("treesj").toggle()
            end,
            mode = "n",
        },
        {
            "gS",
            function()
                require("treesj").split({ split = { recursive = true } })
            end,
            mode = "n",
        },
    },
    opts = {
        max_join_length = 99,
        notify = false,
        use_default_keymaps = false,
    },
}

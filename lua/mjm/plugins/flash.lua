return {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
        modes = {
            char = {
                enabled = false,
            },
        },
        jump = {
            pos = "end", -- Match how / and ? work
        },
        highlight = {
            backdrop = false,
            groups = {
                current = "CurSearch",
                -- label = "DiffText",
                label = "QuickScopePrimary",
                match = "CurSearch",
            },
        },
    },
    keys = {
        {
            "\\",
            mode = { "n" },
            function()
                require("flash").jump({
                    search = { forward = true, wrap = false, multi_window = false },
                })
            end,
        },
        {
            "|",
            mode = { "n" },
            function()
                require("flash").jump({
                    search = { forward = false, wrap = false, multi_window = false },
                })
            end,
        },
    },
}

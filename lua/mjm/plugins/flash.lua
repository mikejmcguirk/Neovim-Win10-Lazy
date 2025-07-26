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
                -- TODO: Create this as an hl group in the colorscheme config so I'm not relying
                -- on QuickScope to make it
                label = "QuickScopePrimary",
                match = "CurSearch",
            },
        },
    },
    keys = {
        {
            "\\",
            mode = { "n", "x" },
            function()
                require("flash").jump({
                    search = { forward = true, wrap = false, multi_window = false },
                })
            end,
        },
        {
            "|",
            mode = { "n", "x" },
            function()
                require("flash").jump({
                    search = { forward = false, wrap = false, multi_window = false },
                })
            end,
        },
    },
}

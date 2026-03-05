return {
    "folke/flash.nvim",
    -- enabled = false,
    event = "VeryLazy",
    keys = {
        -- { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
        -- { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
        -- { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
        -- { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
        -- {
        --     "<c-s>",
        --     mode = { "c" },
        --     function()
        --         require("flash").toggle()
        --     end,
        --     desc = "Toggle Flash Search",
        -- },
    },
    init = function()
        vim.keymap.set({ "n", "o" }, "s", function()
            require("flash").jump({
                search = { forward = true, wrap = false, multi_window = false },
            })
        end)

        vim.keymap.set({ "n", "o" }, "S", function()
            require("flash").jump({
                search = { forward = false, wrap = false, multi_window = false },
            })
        end)
    end,
    opts = {
        modes = {
            char = {
                enabled = false,
            },
            -- search = {
            --     enabled = true,
            -- },
        },
    },
}

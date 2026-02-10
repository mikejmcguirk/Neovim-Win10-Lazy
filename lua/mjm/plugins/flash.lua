return {
    "folke/flash.nvim",
    enabled = false,
    event = "VeryLazy",
    config = function()
        vim.keymap.set({ "n", "o" }, "/", function()
            require("flash").jump({
                search = { forward = true, wrap = false, multi_window = false },
            })
        end)

        vim.keymap.set({ "n", "o" }, "?", function()
            require("flash").jump({
                search = { forward = false, wrap = false, multi_window = false },
            })
        end)
    end,
}

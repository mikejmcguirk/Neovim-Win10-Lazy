vim.keymap.set("n", "<cr>", function()
    require("farsight.jump").jump({ all_wins = true })
end)

vim.keymap.set({ "x", "o" }, "<cr>", function()
    require("farsight.jump").jump({})
end)

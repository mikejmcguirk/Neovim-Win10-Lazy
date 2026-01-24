vim.keymap.set("n", "<cr>", function()
    require("farsight.jump").jump({ all_wins = true })
end)

vim.keymap.set({ "x", "o" }, "<cr>", function()
    require("farsight.jump").jump({})
end)

vim.keymap.set("n", "f", function()
    require("farsight.csearch").csearch()
end)

-- vim.keymap.set("n", "F", function()
--     require("farsight.csearch").csearch({ forward = false })
-- end)

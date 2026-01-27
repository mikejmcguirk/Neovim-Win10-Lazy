vim.keymap.set("n", "<cr>", function()
    require("farsight.jump").jump({ all_wins = true })
end)

vim.keymap.set({ "x", "o" }, "<cr>", function()
    require("farsight.jump").jump({})
end)

local actions_forward = {

    ["\r"] = function()
        require("farsight.jump").jump({ all_wins = false, dir = 1 })
    end,
}

local actions_backward = {

    ["\r"] = function()
        require("farsight.jump").jump({ all_wins = false, dir = -1 })
    end,
}

vim.keymap.set("n", "f", function()
    require("farsight.csearch").csearch({ actions = actions_forward })
end)

vim.keymap.set("n", "t", function()
    require("farsight.csearch").csearch({
        t_cmd = true,
        actions = actions_forward,
    })
end)

vim.keymap.set("n", "F", function()
    require("farsight.csearch").csearch({
        forward = false,
        actions = actions_backward,
    })
end)

vim.keymap.set("n", "T", function()
    require("farsight.csearch").csearch({
        actions = actions_backward,
        forward = false,
        t_cmd = true,
    })
end)

vim.keymap.set("n", ";", function()
    require("farsight.csearch").rep()
end)

vim.keymap.set("n", ",", function()
    require("farsight.csearch").rep({ reverse = true })
end)

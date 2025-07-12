return {
    "mbbill/undotree",
    event = { "BufReadPre", "BufNewFile" },
    init = function()
        vim.g.undotree_WindowLayout = 3
        vim.g.undotree_SplitWidth = 42
        vim.g.undotree_DiffpanelHeight = 18
        vim.g.undotree_SetFocusWhenToggle = 1
    end,
    config = function()
        vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)
    end,
}

return {
    "mbbill/undotree",
    event = { "BufReadPre", "BufNewFile" },
    init = function()
        vim.g.undotree_WindowLayout = 3
        vim.g.undotree_SplitWidth = 42
    end,
    config = function()
        vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)
    end,
}

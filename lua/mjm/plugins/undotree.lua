vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-undotree", { clear = true }),
    once = true,
    callback = function()
        vim.g.undotree_WindowLayout = 3
        vim.g.undotree_SplitWidth = 42
        vim.g.undotree_DiffpanelHeight = 18
        vim.g.undotree_SetFocusWhenToggle = 1

        require("mjm.pack").post_load("undotree")

        vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)
    end,
})

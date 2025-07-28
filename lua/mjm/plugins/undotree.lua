local function load_undotree()
    vim.g.undotree_WindowLayout = 3
    vim.g.undotree_SplitWidth = 42
    vim.g.undotree_DiffpanelHeight = 18
    vim.g.undotree_SetFocusWhenToggle = 1
    vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)
end

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-undotree", { clear = true }),
    once = true,
    callback = function()
        load_undotree()
    end,
})

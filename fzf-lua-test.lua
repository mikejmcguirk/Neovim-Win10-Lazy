vim.pack.add({
    {
        src = "https://github.com/ibhagwan/fzf-lua",
        version = "0e0962a", -- Does not work
        -- version = "9449f39", -- Commit before. Works
    },
})

vim.pack.update({ "fzf-lua" }, { force = true })

require("fzf-lua").setup({})
vim.keymap.set("n", "<leader>fh", function()
    require("fzf-lua").helptags()
end)

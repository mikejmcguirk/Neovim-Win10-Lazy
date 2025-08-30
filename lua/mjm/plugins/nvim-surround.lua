-- LOW: If you post-load this plugin, it will create a keymap on "c" for change line in normal
-- mode. I don't see a "plugin" file in the code that it would source
-- If I packadd! here and lazily run the setup function, this does not occur
-- But it's worth understanding what's going on here

vim.cmd.packadd({ vim.fn.escape("nvim-surround", " "), bang = true, magic = { file = false } })
-- require("nvim-surround").setup({})

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("load-nvim-surround", { clear = true }),
    once = true,
    callback = function()
        -- require("mjm.pack").post_load("nvim-surround")
        require("nvim-surround").setup({})
    end,
})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

vim.opt.rtp:prepend(lazypath)

local lazy = require("lazy")

lazy.setup("mjm.plugins", {
    ui = {
        border = "single"
    }
})

vim.keymap.set("n", "<leader>zc", lazy.check)
vim.keymap.set("n", "<leader>zx", lazy.clean)
vim.keymap.set("n", "<leader>zd", lazy.debug)
vim.keymap.set("n", "<leader>ze", lazy.help)
vim.keymap.set("n", "<leader>zh", lazy.home)
vim.keymap.set("n", "<leader>zi", lazy.install)
vim.keymap.set("n", "<leader>zl", lazy.log)
vim.keymap.set("n", "<leader>zp", lazy.profile)
vim.keymap.set("n", "<leader>zs", lazy.sync)
vim.keymap.set("n", "<leader>zu", lazy.update)

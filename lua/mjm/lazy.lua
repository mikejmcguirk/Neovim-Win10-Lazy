local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        lazyrepo,
        lazypath,
    })

    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end

vim.opt.rtp:prepend(lazypath)

local lazy = require("lazy")
lazy.setup("mjm.plugins", {
    ui = {
        border = "single",
    },
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

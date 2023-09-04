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

-- if not os.getenv("OmniSharpDLL") then
--     print("OmniSharpDLL environment variable not set. Omnisharp will be unable to attach")
-- end

require("lazy").setup("mjm.plugins", {
    ui = {
        border = "single"
    }
})

local lazy = require("lazy")
local loudOpts = { noremap = true, silent = false }

vim.keymap.set("n", "<leader>zc", lazy.check, loudOpts)
vim.keymap.set("n", "<leader>zx", lazy.clean, loudOpts)
vim.keymap.set("n", "<leader>zd", lazy.debug, loudOpts)
vim.keymap.set("n", "<leader>ze", lazy.help, loudOpts)
vim.keymap.set("n", "<leader>zh", lazy.home, loudOpts)
vim.keymap.set("n", "<leader>zi", lazy.install, loudOpts)
vim.keymap.set("n", "<leader>zl", lazy.log, loudOpts)
vim.keymap.set("n", "<leader>zp", lazy.profile, loudOpts)
vim.keymap.set("n", "<leader>zs", lazy.sync, loudOpts)
vim.keymap.set("n", "<leader>zu", lazy.update, loudOpts)

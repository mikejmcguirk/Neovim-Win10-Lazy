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

----------------

require("lazy").setup({
    change_detection = { enabled = false, notify = false },
    rocks = { enabled = false },
    spec = { { import = "mjm.plugins" } },
    ui = { border = "single" },
})

vim.keymap.set("n", "<leader>zp", "<cmd>Lazy profile<cr>")
vim.keymap.set("n", "<leader>zu", "<cmd>Lazy update<cr>")
vim.keymap.set("n", "<leader>zx", "<cmd>Lazy clean<cr>")
vim.keymap.set("n", "<leader>zz", "<cmd>Lazy<cr>")

-- MAYBE: https://github.com/rockerBOO/awesome-neovim - So many plugins out there
-- MAYBE: https://github.com/mrcjkb/rustaceanvim
-- MAYBE: Dap setup?
--    - https://github.com/tjdevries/config.nvim/blob/master/lua/custom/plugins/dap.lua
-- MAYBE: For dbs
--    - https://github.com/kndndrj/nvim-dbee
-- MAYBE: Markdown previewers:
-- - https://github.com/toppair/peek.nvim -- Markdown preview
-- - Previewer for a lot of things: https://github.com/OXY2DEV/markview.nvim
-- MAYBE: https://github.com/chentoast/marks.nvim

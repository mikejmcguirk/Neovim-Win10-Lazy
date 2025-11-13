local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    -- LOW: Should be vim.system:wait()
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

-- LOW: vim.opt will be deprecated eventually
vim.opt.rtp:prepend(lazypath)
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

-- TODO: Use-case for ts-context - When looking at unfamiliar code bases, and you are in a big
-- function, it is useful to be able to just see the function name without having to scroll up
-- to find its beginning. But if it's brought back, it needs to be togglable. Not something I
-- want to have always on. Can put it under <leader>t somewhere
-- TODO: https://github.com/nvim-mini/mini.sessions
-- Another mksession wrapper to try. Use case here: When working on changes, I get trapped in the
-- close Nvim then re-open my buffers loop. So we need to make sure that toggling whether or not
-- to auto-reload sessions is low friction, since we don't need it all the time

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

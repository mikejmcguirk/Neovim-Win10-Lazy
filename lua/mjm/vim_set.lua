-------------------------------
-- Brick netrw for nvim-tree --
-------------------------------

-- This is here instead of plugin_set so it is done first thing

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1

------------------------------------
-- Line Numbering & Column Widths --
------------------------------------

vim.opt.nu = true
vim.opt.relativenumber = true
vim.opt.numberwidth = 5

vim.opt.signcolumn = "yes:1"

vim.opt.colorcolumn = "100"

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.shiftround = true

--------------------------
-- Configure cursorline --
--------------------------

vim.opt.cursorline = true

local group = vim.api.nvim_create_augroup("CursorLineControl", { clear = true })
local set_cursorline = function(event, value, pattern)
    vim.api.nvim_create_autocmd(event, {
        group = group,
        pattern = pattern,
        callback = function()
            vim.opt_local.cursorline = value
        end,
    })
end

set_cursorline("WinLeave", false)
set_cursorline("WinEnter", true)
set_cursorline("FileType", false, "TelescopePrompt")

----------------
-- Aesthetics --
----------------

vim.opt.termguicolors = true

vim.cmd([[set gcr=n:block-blinkon1,i-c:ver100-blinkon1,v-r:hor100-blinkon1]])

vim.opt.scrolloff = 6

vim.wo.wrap = false
vim.opt.wrap = false

vim.opt.splitright = true

vim.opt.showmode = false

vim.opt.hlsearch = true
vim.opt.incsearch = true

-------------------------
-- Misc. Functionality --
-------------------------

vim.opt.autoindent = true
vim.opt.cindent = true

vim.opt.updatetime = 1000

vim.opt.ignorecase = true
vim.opt.smartcase = true

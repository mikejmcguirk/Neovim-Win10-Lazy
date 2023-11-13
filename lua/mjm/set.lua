-- Because of race conditions at startup, netrw should be disabled at the very beginning of
-- startup if nvim-tree is installed
local status, nvim_tree = pcall(require, "nvim-tree")

if status then
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
    vim.g.loaded_netrwSettings = 1
    vim.g.netrw_banner = 0
end

vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", Opts)
vim.g.mapleader = " "
vim.g.maplocaleader = " "

vim.opt.nu = true
vim.opt.relativenumber = true
vim.opt.numberwidth = 5
vim.opt.signcolumn = "yes:1"
vim.opt.colorcolumn = "100"

local default_tab_width = 4

vim.opt.tabstop = default_tab_width
vim.opt.softtabstop = default_tab_width
vim.opt.shiftwidth = default_tab_width
vim.opt.expandtab = true
vim.opt.shiftround = true

vim.opt.autoindent = true
vim.opt.cindent = true

vim.opt.termguicolors = true
vim.cmd([[set gcr=n:block-blinkon1,i-c-ci:ver100-blinkon1,v-r:hor100-blinkon1]])
vim.opt.lazyredraw = true

vim.opt.scrolloff = 6
vim.opt.startofline = true

vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.showmode = false

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.modelines = 1
vim.opt.updatetime = 1000

vim.opt.listchars = {
    tab = "<–>",
    extends = "»",
    precedes = "«",
    nbsp = "×",
}

vim.opt.list = true

vim.opt.cursorline = true

local aesthetic_control = vim.api.nvim_create_augroup("aesthetic_control", { clear = true })

---@param event string
---@param value boolean
---@param pattern string
local set_cursorline = function(event, value, pattern)
    vim.api.nvim_create_autocmd(event, {
        group = aesthetic_control,
        pattern = pattern,
        callback = function()
            vim.opt_local.cursorline = value
        end,
    })
end

set_cursorline("WinLeave", false, "")
set_cursorline("WinEnter", true, "")
set_cursorline("FileType", false, "TelescopePrompt")

vim.opt.wrap = false
vim.opt.linebreak = true

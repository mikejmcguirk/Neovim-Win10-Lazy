vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1

vim.keymap.set("", "<Space>", "<Nop>", { noremap = true, silent = true })
vim.g.mapleader = " "
vim.g.maplocaleader = " "

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

vim.opt.cursorline = true

local cursorLineGroup = vim.api.nvim_create_augroup("CursorLineControl", { clear = true })

local set_cursorline = function(event, value, pattern)
    vim.api.nvim_create_autocmd(event, {
        group = cursorLineGroup,
        pattern = pattern,
        callback = function()
            vim.opt_local.cursorline = value
        end,
    })
end

set_cursorline("WinLeave", false)
set_cursorline("WinEnter", true)
set_cursorline("FileType", false, "TelescopePrompt")

vim.opt.termguicolors = true
vim.cmd([[set gcr=n:block-blinkon1,i-c:ver100-blinkon1,v-r:hor100-blinkon1]])

vim.opt.wrap = false

local wrap_control = vim.api.nvim_create_augroup("wrap_control", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = wrap_control,
    pattern = "*",
    callback = function()
        if vim.bo.filetype == "markdown" then
            vim.wo.wrap = true
        else
            vim.wo.wrap = false
        end
    end,
})

vim.opt.scrolloff = 6
vim.opt.splitright = true
vim.opt.showmode = false

vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.autoindent = true
vim.opt.cindent = true

vim.opt.updatetime = 1000

vim.cmd "packadd cfilter"

vim.opt.grepformat = "%f:%l:%m"
vim.opt.grepprg = "rg --line-number"

-- For nvim-tree, netrw should be disabled right away to avoid startup race conditions
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1

-- Prevent other default plugins from loading
vim.g.loaded_2html_plugin = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_gzip = 1
vim.g.did_install_default_menus = 1

-- Set leader immediately to ensure leader mappings are correct
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>")
vim.g.mapleader = " "
vim.g.maplocaleader = " "

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
vim.opt.number = true
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

vim.opt.fileformats = "unix,dos" -- Override \r\n on Windows

vim.opt.termguicolors = true
vim.api.nvim_exec2("set gcr=n:block-blinkon1,i-c-ci:ver100-blinkon1,v-r:hor100-blinkon1", {})
vim.opt.lazyredraw = false -- Disabled because it prevents search result indexes from showing
vim.opt.showmode = false
vim.opt.shortmess:append("I")

vim.opt.scrolloff = 6
vim.opt.startofline = true
vim.opt.jumpoptions:append("view")

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = false -- Prevent screen from shifting when entering substitution patterns
vim.opt.modelines = 1

vim.opt.updatetime = 500
vim.opt.timeoutlen = 500

vim.opt.list = true
vim.opt.listchars = {
    tab = "<–>",
    extends = "»",
    precedes = "«",
    nbsp = "×",
}

vim.opt.wrap = false
vim.opt.linebreak = true
vim.opt.spell = false
vim.opt.spelllang = "en_us"

vim.opt.cursorline = true
---@param event string
---@param value boolean
---@param pattern string
---@return nil
local set_cursorline = function(event, value, pattern)
    vim.api.nvim_create_autocmd(event, {
        group = vim.api.nvim_create_augroup("cursor_control", { clear = true }),
        pattern = pattern,
        callback = function()
            vim.opt_local.cursorline = value
        end,
    })
end
set_cursorline("WinLeave", false, "")
set_cursorline("WinEnter", true, "")
set_cursorline("FileType", false, "TelescopePrompt")

-- To avoid race conditions with nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1

-- Prevent other default plugins from loading
vim.g.loaded_2html_plugin = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_gzip = 1
vim.g.did_install_default_menus = 1

-- Set immediately to ensure leader mappings are correct
vim.keymap.set({ "n", "x" }, "<Space>", "<Nop>")
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

vim.opt.lazyredraw = false -- Causes unpredictable problems
vim.opt.termguicolors = true
vim.cmd("set gcr=n:block-blinkon1,i-c-ci:ver100-blinkon1,v-r:hor100-blinkon1")
vim.opt.showmode = false

vim.opt.scrolloff = 6
vim.opt.startofline = true
vim.opt.jumpoptions:append("view") -- Restore views when possible

vim.opt.shortmess:append("I")
vim.opt.cpoptions:append("W") -- Don't overwrite read-only files

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = false -- Prevent screen shifting while entering search/substitute patterns

vim.opt.modelines = 1

-- Prevents disabled <C-w> and Z mappings from becoming active again after timeout
vim.opt.timeout = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true
vim.opt.updatetime = 250
-- Previous windows undo path
-- data_path = os.getenv("USERPROFILE") .. "\\AppData\\Local\\nvim-data\\undodir"

vim.opt.list = true
vim.opt.listchars = { tab = "<–>", extends = "»", precedes = "«", nbsp = "␣" }
vim.opt.wrap = false
vim.opt.linebreak = true

vim.opt.spell = false
vim.opt.spelllang = "en_us" -- If spell is turned on by an ftplugin file

vim.opt.cursorline = true
local cursorline_control = vim.api.nvim_create_augroup("cursorline_control", { clear = true })
---@param event string
---@param value boolean
---@param pattern string
---@return nil
local set_cursorline = function(event, value, pattern)
    vim.api.nvim_create_autocmd(event, {
        group = cursorline_control,
        pattern = pattern,
        callback = function()
            vim.opt_local.cursorline = value
        end,
    })
end
set_cursorline("WinLeave", false, "")
set_cursorline("WinEnter", true, "")
set_cursorline("FileType", false, "TelescopePrompt")

-- To avoid race conditions with nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1

-- Prevent other default plugins from loading
vim.g.loaded_gzip = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_matchit = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_netrwPlugin = 1
-- vim.g.loaded_matchparen = 1
vim.g.did_install_default_menus = 1

-- Load useful plugins
-- NOTE: cfilter only works on the "text" portion of the qf entry
vim.cmd("packadd cfilter")

-- Set immediately to ensure leader mappings are correct
vim.keymap.set({ "n", "x" }, "<Space>", "<Nop>")
vim.g.mapleader = " "
vim.g.maplocaleader = " "

vim.opt.mouse = "a" -- Otherwise, the terminal handles mouse functionality
vim.o.mousescroll = "ver:0,hor:0"

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.numberwidth = 5
vim.opt.signcolumn = "yes:1"
vim.opt.colorcolumn = "100"

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.shiftround = true

vim.opt.fileformats = "unix,dos" -- Override \r\n on Windows

vim.opt.lazyredraw = false -- Causes unpredictable problems
vim.opt.termguicolors = true
vim.opt.showmode = false
vim.opt.modelines = 1

-- Don't use. Sets arbitrary border around zen mode display
-- vim.opt.winborder = "single"

local blink_setting = "blinkon1-blinkoff1"
local block_cursor = "n:" .. blink_setting
local ver_cursor = "i-c-ci:ver100-" .. blink_setting
local hor_cursor = "v-r:hor100-" .. blink_setting
vim.cmd("set gcr=" .. block_cursor .. "," .. ver_cursor .. "," .. hor_cursor)

vim.opt.scrolloff = Scrolloff_Val
vim.opt.startofline = false
vim.opt.jumpoptions:append("view") -- Restore views when possible
vim.opt.matchpairs:append("<:>")
vim.opt.cpoptions:append("W") -- Don't overwrite read-only files

vim.opt.selection = "old"
vim.opt.smartindent = true

vim.opt.shortmess:append("I")
vim.opt.shortmess:append("W")
vim.opt.shortmess:append("s")
vim.opt.shortmess:append("r")

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = false -- Prevent screen shifting while entering search/substitute patterns

-- Prevents disabled mappings from becoming active again after timeout
vim.opt.timeout = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true
vim.opt.updatetime = 250

vim.opt.list = true
vim.opt.listchars = { tab = "<–>", extends = "»", precedes = "«", nbsp = "␣" }
-- vim.opt.listchars = { tab = "<–>", extends = "»", precedes = "«", nbsp = "␣", trail = "⣿" }
-- vim.opt.listchars = { eol = "↲", tab = "<–>", extends = "»", precedes = "«", nbsp = "␣" }
vim.opt.wrap = false
vim.opt.breakindent = true -- For fts where opt_local wrap is true
vim.opt.linebreak = true

vim.opt.spell = false
vim.opt.spelllang = "en_us" -- If spell is turned on by an ftplugin file

vim.opt.cursorline = true
local cursorline_control = vim.api.nvim_create_augroup("cursorline_control", { clear = true })

---@param event string
---@param pattern string
---@param value boolean
---@return nil
local set_cursorline = function(event, pattern, value)
    vim.api.nvim_create_autocmd(event, {
        group = cursorline_control,
        pattern = pattern,
        callback = function()
            vim.opt_local.cursorline = value
        end,
    })
end

set_cursorline("WinLeave", "", false)
set_cursorline("WinEnter", "", true)
set_cursorline("FileType", "TelescopePrompt", false)

-----------------------
-- Internal Behavior --
-----------------------

-- Override \r\n on Windows
vim.api.nvim_set_option_value("fileformats", "unix,dos", { scope = "global" })
vim.opt.jumpoptions:append("view")

vim.api.nvim_set_option_value("backup", false, { scope = "global" })
vim.api.nvim_set_option_value("writebackup", false, { scope = "global" })
vim.api.nvim_set_option_value("swapfile", false, { scope = "global" })
vim.api.nvim_set_option_value("undofile", true, { scope = "global" })
vim.api.nvim_set_option_value("updatetime", 250, { scope = "global" })
vim.api.nvim_set_option_value("shada", "'100,<50,s10,:1000,/100,@100,h", { scope = "global" })

--------
-- UI --
--------

vim.api.nvim_set_option_value("tabstop", 4, { scope = "global" })
vim.api.nvim_set_option_value("softtabstop", 4, { scope = "global" })
vim.api.nvim_set_option_value("shiftwidth", 4, { scope = "global" })
vim.api.nvim_set_option_value("expandtab", true, { scope = "global" })
vim.api.nvim_set_option_value("shiftround", true, { scope = "global" })

vim.api.nvim_set_option_value("backspace", "indent,eol,nostop", { scope = "global" })

vim.opt.cpoptions:append("W") -- Don't overwrite readonly files
vim.opt.cpoptions:append("Z") -- Don't reset readonly with w!

vim.api.nvim_set_option_value("ignorecase", true, { scope = "global" })
vim.api.nvim_set_option_value("smartcase", true, { scope = "global" })
-- Don't want screen shifting while entering search/subsitute patterns
vim.api.nvim_set_option_value("incsearch", false, { scope = "global" })

vim.opt.matchpairs:append("<:>")

vim.api.nvim_set_option_value("mouse", "", { scope = "global" })

vim.api.nvim_set_option_value("modelines", 1, { scope = "global" })

vim.api.nvim_set_option_value("selection", "old", { scope = "global" })
vim.api.nvim_set_option_value("scrolloff", Scrolloff_Val, { scope = "global" })

vim.api.nvim_set_option_value("splitbelow", true, { scope = "global" })
vim.api.nvim_set_option_value("splitright", true, { scope = "global" })

---------------------
-- Buffer Behavior --
---------------------

-- https://github.com/neovim/neovim/issues/35575
-- vim.api.nvim_set_option_value("wrap", false, { scope = "global" })
-- For fts where opt_local wrap is true
vim.api.nvim_set_option_value("breakindent", true, { scope = "global" })
vim.api.nvim_set_option_value("linebreak", true, { scope = "global" })
vim.api.nvim_set_option_value("smartindent", true, { scope = "global" })

local dict = vim.fn.expand("~/.local/bin/words/words_alpha.txt")
vim.api.nvim_set_option_value("dictionary", dict, { scope = "global" })
vim.api.nvim_set_option_value("spell", false, { scope = "global" })
vim.api.nvim_set_option_value("spelllang", "en_us", { scope = "global" })

----------------
-- Aesthetics --
----------------

vim.opt.fillchars:append({ eob = " " })

local blink_setting = "blinkon1-blinkoff1"
local norm_cursor = "n:block" .. blink_setting
local ver_cursor = "i-sm-c-ci-t:ver100-" .. blink_setting
local hor_cursor = "o-v-ve-r-cr:hor100-" .. blink_setting
local gcr = norm_cursor .. "," .. ver_cursor .. "," .. hor_cursor
vim.api.nvim_set_option_value("guicursor", gcr, { scope = "global" })

vim.api.nvim_set_option_value("list", true, { scope = "global" })
local listchars = "tab:<->,extends:»,precedes:«,nbsp:␣,trail:⣿"
vim.api.nvim_set_option_value("listchars", listchars, { scope = "global" })

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
vim.api.nvim_set_option_value("number", true, { scope = "global" })
vim.api.nvim_set_option_value("relativenumber", true, { scope = "global" })
vim.api.nvim_set_option_value("colorcolumn", "100", { scope = "global" })
vim.api.nvim_set_option_value("numberwidth", 5, { scope = "global" })
vim.api.nvim_set_option_value("signcolumn", "yes:1", { scope = "global" })

vim.api.nvim_set_option_value("cursorline", true, { scope = "global" })

vim.opt.shortmess:append("a") --- Abbreviations
vim.opt.shortmess:append("s") --- No search hit top/bottom messages
vim.opt.shortmess:append("I") --- No intro message
vim.opt.shortmess:append("W") --- No "written" notifications

vim.api.nvim_set_option_value("ruler", false, { scope = "global" })
vim.api.nvim_set_option_value("showmode", false, { scope = "global" })

----------------------
-- Autocmd Controls --
----------------------

local set_group = vim.api.nvim_create_augroup("set-group", { clear = true })

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group = set_group,
    pattern = ".bashrc_custom",
    callback = function()
        vim.api.nvim_cmd({ cmd = "set", args = { "filetype=sh" } }, {})
    end,
})

-- See help fo-table
-- Since multiple runtime ftplugin files set formatoptions, correct here
vim.api.nvim_create_autocmd({ "FileType" }, {
    group = set_group,
    pattern = "*",
    callback = function()
        vim.opt.formatoptions:remove("o")
    end,
})

local clear_conditions = {
    "BufEnter",
    "CmdlineEnter",
    -- "InsertEnter",
    "RecordingEnter",
    "TabLeave",
    "TabNewEntered",
    "WinEnter",
    "WinLeave",
} ---@type string[]

vim.api.nvim_create_autocmd(clear_conditions, {
    group = set_group,
    pattern = "*",
    -- The highlight state is saved and restored when autocmds are triggered, so
    -- schedule_wrap is used to trigger nohlsearch aftewards
    -- See nohlsearch() help
    callback = vim.schedule_wrap(function()
        vim.cmd.nohlsearch()
    end),
})

vim.api.nvim_create_autocmd("WinEnter", {
    group = set_group,
    callback = function()
        vim.api.nvim_set_option_value("cul", true, { win = vim.api.nvim_get_current_win() })
    end,
})

vim.api.nvim_create_autocmd("WinLeave", {
    group = set_group,
    callback = function()
        vim.api.nvim_set_option_value("cul", false, { win = vim.api.nvim_get_current_win() })
    end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
    group = set_group,
    callback = function()
        vim.api.nvim_set_option_value("list", false, { win = vim.api.nvim_get_current_win() })
    end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
    group = set_group,
    callback = function()
        vim.api.nvim_set_option_value("list", true, { win = vim.api.nvim_get_current_win() })
    end,
})

---@param event string|string[]
---@param pattern string
---@param value boolean
---@return nil
local set_rnu = function(event, pattern, value)
    vim.api.nvim_create_autocmd(event, {
        group = set_group,
        pattern = pattern,
        callback = function()
            vim.api.nvim_set_option_value("rnu", value, { win = vim.api.nvim_get_current_win() })
        end,
    })
end

vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = set_group,
    callback = function()
        vim.api.nvim_set_option_value("rnu", false, { win = vim.api.nvim_get_current_win() })
        if not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype) then
            vim.cmd("redraw")
        end
    end,
})

-- Note: Need BufLeave/BufEnter for this to work when going into help
set_rnu({ "WinLeave", "BufLeave" }, "*", false)
set_rnu({ "WinEnter", "CmdlineLeave", "BufEnter" }, "*", true)

vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    group = set_group,
    pattern = "*",
    callback = function()
        vim.fn.setreg("/", nil)
    end,
})

----------------

-- vim.opt.lazyredraw = false -- Causes unpredictable problems
-- vim.opt.startofline = false -- Makes gg/G feel weird
-- vim.opt.winborder = "single" -- Sets arbitrary border around Zen mode display

-- Otherwise, the terminal handles mouse functionality
vim.api.nvim_set_option_value("mouse", "a", { scope = "global" })
vim.api.nvim_set_option_value("mousescroll", "ver:0,hor:0", { scope = "global" })

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
vim.api.nvim_set_option_value("nu", true, { scope = "global" })
vim.api.nvim_set_option_value("rnu", true, { scope = "global" })
vim.api.nvim_set_option_value("nuw", 5, { scope = "global" })
vim.api.nvim_set_option_value("scl", "yes:1", { scope = "global" })
vim.api.nvim_set_option_value("cc", "100", { scope = "global" })

local rnu_control = vim.api.nvim_create_augroup("rnu_control", { clear = true })

---@param event string|string[]
---@param pattern string
---@param value boolean
---@return nil
local set_rnu = function(event, pattern, value)
    vim.api.nvim_create_autocmd(event, {
        group = rnu_control,
        pattern = pattern,
        callback = function(ev)
            local win = vim.api.nvim_get_current_win()
            vim.api.nvim_set_option_value("rnu", value, { win = win })
            if ev.event == "CmdlineEnter" then
                if not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype) then
                    vim.cmd("redraw")
                end
            end
        end,
    })
end

-- Note: Need BufLeave/BufEnter for this to work when going into help. Seems like the autocmds run
-- before the buf is loaded, and rnu can't be set on Win Enter since there's no buffer
set_rnu({ "WinLeave", "CmdlineEnter", "BufLeave" }, "*", false)
set_rnu({ "WinEnter", "CmdlineLeave", "BufEnter" }, "*", true)

vim.api.nvim_set_option_value("tabstop", 4, { scope = "global" })
vim.api.nvim_set_option_value("softtabstop", 4, { scope = "global" })
vim.api.nvim_set_option_value("shiftwidth", 4, { scope = "global" })
vim.api.nvim_set_option_value("expandtab", true, { scope = "global" })
vim.api.nvim_set_option_value("shiftround", true, { scope = "global" })

-- Override \r\n on Windows
vim.api.nvim_set_option_value("fileformats", "unix,dos", { scope = "global" })

-- Have to turn this off. When doing Git push with Fugitive, it goes into replace(?) mode,
-- and sometimes the "last saved" position in the file gets broken
-- PR: Identify why this happens. Though, in the longer term, extui should finally alleviate
-- the need for this setting at all
-- vim.api.nvim_set_option_value("messagesopt", "wait:2000,history:500", { scope = "global" })
vim.api.nvim_set_option_value("showmode", false, { scope = "global" })
vim.api.nvim_set_option_value("modelines", 1, { scope = "global" })

local blink_setting = "blinkon1-blinkoff1"
local block_cursor = "n:" .. blink_setting
local ver_cursor = "i-c-ci:ver100-" .. blink_setting
local hor_cursor = "v-r:hor100-" .. blink_setting
local gcr = block_cursor .. "," .. ver_cursor .. "," .. hor_cursor
vim.api.nvim_set_option_value("gcr", gcr, { scope = "global" })

vim.api.nvim_set_option_value("scrolloff", Scrolloff_Val, { scope = "global" })
vim.opt.jumpoptions:append("view")
vim.opt.matchpairs:append("<:>")
vim.opt.cpoptions:append("W")
-- TODO: Should "Z" be added to cpoptions?

vim.api.nvim_set_option_value("backspace", "indent,eol,nostop", { scope = "global" })
vim.api.nvim_set_option_value("selection", "old", { scope = "global" })
vim.api.nvim_set_option_value("smartindent", true, { scope = "global" })

vim.opt.shortmess:append("I")
vim.opt.shortmess:append("W")
vim.opt.shortmess:append("s")
vim.opt.shortmess:append("r")

vim.api.nvim_set_option_value("splitright", true, { scope = "global" })
vim.api.nvim_set_option_value("splitbelow", true, { scope = "global" })

vim.api.nvim_set_option_value("ignorecase", true, { scope = "global" })
vim.api.nvim_set_option_value("smartcase", true, { scope = "global" })
-- Don't want screen shifting while entering search/subsitute patterns
vim.api.nvim_set_option_value("incsearch", false, { scope = "global" })

vim.api.nvim_set_option_value("swapfile", false, { scope = "global" })
vim.api.nvim_set_option_value("backup", false, { scope = "global" })
vim.api.nvim_set_option_value("undofile", true, { scope = "global" })
vim.api.nvim_set_option_value("updatetime", 250, { scope = "global" })

vim.api.nvim_set_option_value("list", true, { scope = "global" })
vim.opt.listchars = { tab = "<–>", extends = "»", precedes = "«", nbsp = "␣" }
-- vim.opt.listchars = { tab = "<–>", extends = "»", precedes = "«", nbsp = "␣", trail = "⣿" }
-- vim.opt.listchars = { eol = "↲", tab = "<–>", extends = "»", precedes = "«", nbsp = "␣" }
vim.api.nvim_set_option_value("wrap", false, { scope = "global" })
-- For fts where opt_local wrap is true
vim.api.nvim_set_option_value("breakindent", true, { scope = "global" })
vim.api.nvim_set_option_value("linebreak", true, { scope = "global" })

vim.api.nvim_set_option_value("spell", false, { scope = "global" })
vim.api.nvim_set_option_value("spelllang", "en_us", { scope = "global" })
vim.opt.dictionary = vim.fn.expand("~/.local/bin/words/words_alpha.txt")

vim.api.nvim_set_option_value("cursorline", true, { scope = "global" })
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
            local win = vim.api.nvim_get_current_win()
            vim.api.nvim_set_option_value("cursorline", value, { win = win })
        end,
    })
end

set_cursorline("WinLeave", "", false)
set_cursorline("WinEnter", "", true)

----------------

-- vim.opt.lazyredraw = false -- Causes unpredictable problems
-- vim.opt.startofline = false -- Makes gg/G feel weird
-- vim.opt.winborder = "single" -- Sets arbitrary border around Zen mode display

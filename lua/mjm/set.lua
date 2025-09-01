local set_group = vim.api.nvim_create_augroup("set-group", { clear = true })

vim.opt.mls = 1
vim.opt.mouse = ""
vim.opt.sb = true
vim.opt.spr = true

-- Override \r\n on Windows
vim.opt.ffs = "unix,dos"
vim.opt.jop:append("view")

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group = set_group,
    pattern = ".bashrc_custom",
    callback = function()
        vim.api.nvim_cmd({ cmd = "set", args = { "filetype=sh" } }, {})
    end,
})

vim.opt.bk = false
vim.opt.swf = false
vim.opt.udf = true
vim.opt.ut = 250

vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    group = set_group,
    pattern = "*",
    callback = function()
        vim.fn.setreg("/", nil)
    end,
})

vim.opt.dictionary = vim.fn.expand("~/.local/bin/words/words_alpha.txt")
vim.opt.spell = false
vim.opt.spl = "en_us"

local blink_setting = "blinkon1-blinkoff1"
local norm_cursor = "n:block" .. blink_setting
local ver_cursor = "i-sm-c-ci-t:ver100-" .. blink_setting
local hor_cursor = "o-v-ve-r-cr:hor100-" .. blink_setting
local gcr = norm_cursor .. "," .. ver_cursor .. "," .. hor_cursor
vim.opt.gcr = gcr

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
vim.opt.nu = true
vim.opt.rnu = true
vim.opt.cc = "100"
vim.opt.nuw = 5
vim.opt.scl = "yes:1"

-- https://github.com/neovim/neovim/issues/35575
-- vim.opt.wrap = false
-- For fts where opt_local wrap is true
vim.opt.bri = true
vim.opt.lbr = true

vim.opt.fillchars:append({ eob = " " })
vim.opt.shortmess:append("I")
vim.opt.smd = false

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

vim.opt.cul = true
local cul_control = vim.api.nvim_create_augroup("cul_control", { clear = true })

---@param event string
---@param pattern string
---@param value boolean
---@return nil
local set_cul = function(event, pattern, value)
    vim.api.nvim_create_autocmd(event, {
        group = cul_control,
        pattern = pattern,
        callback = function()
            local win = vim.api.nvim_get_current_win()
            vim.api.nvim_set_option_value("cul", value, { win = win })
        end,
    })
end

set_cul("WinLeave", "", false)
set_cul("WinEnter", "", true)

----------------

-- vim.opt.lazyredraw = false -- Causes unpredictable problems
-- vim.opt.startofline = false -- Makes gg/G feel weird
-- vim.opt.winborder = "single" -- Sets arbitrary border around Zen mode display

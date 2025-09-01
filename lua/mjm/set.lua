local set_group = vim.api.nvim_create_augroup("set-group", { clear = true })

vim.api.nvim_set_option_value("mls", 1, { scope = "global" })
vim.api.nvim_set_option_value("mouse", "", { scope = "global" })
vim.api.nvim_set_option_value("sb", true, { scope = "global" })
vim.api.nvim_set_option_value("spr", true, { scope = "global" })

-- Override \r\n on Windows
vim.api.nvim_set_option_value("ffs", "unix,dos", { scope = "global" })
vim.opt.jop:append("view")

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group = set_group,
    pattern = ".bashrc_custom",
    callback = function()
        vim.api.nvim_cmd({ cmd = "set", args = { "filetype=sh" } }, {})
    end,
})

vim.api.nvim_set_option_value("bk", false, { scope = "global" })
vim.api.nvim_set_option_value("swf", false, { scope = "global" })
vim.api.nvim_set_option_value("udf", true, { scope = "global" })
vim.api.nvim_set_option_value("ut", 250, { scope = "global" })

vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    group = set_group,
    pattern = "*",
    callback = function()
        vim.fn.setreg("/", nil)
    end,
})

local dict = vim.fn.expand("~/.local/bin/words/words_alpha.txt")
vim.api.nvim_set_option_value("dictionary", dict, { scope = "global" })
vim.api.nvim_set_option_value("spell", false, { scope = "global" })
vim.api.nvim_set_option_value("spl", "en_us", { scope = "global" })

local blink_setting = "blinkon1-blinkoff1"
local norm_cursor = "n:block" .. blink_setting
local ver_cursor = "i-sm-c-ci-t:ver100-" .. blink_setting
local hor_cursor = "o-v-ve-r-cr:hor100-" .. blink_setting
local gcr = norm_cursor .. "," .. ver_cursor .. "," .. hor_cursor
vim.api.nvim_set_option_value("gcr", gcr, { scope = "global" })

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
vim.api.nvim_set_option_value("nu", true, { scope = "global" })
vim.api.nvim_set_option_value("rnu", true, { scope = "global" })
vim.api.nvim_set_option_value("cc", "100", { scope = "global" })
vim.api.nvim_set_option_value("nuw", 5, { scope = "global" })
vim.api.nvim_set_option_value("scl", "yes:1", { scope = "global" })

-- https://github.com/neovim/neovim/issues/35575
-- vim.api.nvim_set_option_value("wrap", false, { scope = "global" })
-- For fts where opt_local wrap is true
vim.api.nvim_set_option_value("bri", true, { scope = "global" })
vim.api.nvim_set_option_value("lbr", true, { scope = "global" })

vim.opt.fillchars:append({ eob = " " })
vim.opt.shortmess:append("I")
vim.api.nvim_set_option_value("smd", false, { scope = "global" })

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

vim.api.nvim_set_option_value("cul", true, { scope = "global" })
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

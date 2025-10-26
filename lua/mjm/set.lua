local set_group = vim.api.nvim_create_augroup("set-group", { clear = true })
local global_scope = { scope = "global" }

-- LOW: Which settings in here can be deferred? The problem is making sure that global scope
-- settings are picked up

-------------------
--- Global Vars ---
-------------------

vim.api.nvim_set_var("no_plugin_maps", 1)

--- :h standard-plugin-list
--- Disabling these has a non-trivial effect on startup time
vim.api.nvim_set_var("loaded_2html_plugin", 1)
vim.api.nvim_set_var("did_install_default_menus", 1)
vim.api.nvim_set_var("loaded_gzip", 1)
vim.api.nvim_set_var("loaded_man", 1)
vim.api.nvim_set_var("loaded_matchit", 1)
vim.api.nvim_set_var("loaded_matchparen", 1)
vim.api.nvim_set_var("loaded_netrw", 1)
vim.api.nvim_set_var("loaded_netrwPlugin", 1)
vim.api.nvim_set_var("loaded_netrwSettings", 1)
vim.api.nvim_set_var("loaded_remote_plugins", 1)
vim.api.nvim_set_var("loaded_shada_plugin", 1)
vim.api.nvim_set_var("loaded_spellfile_plugin", 1)
vim.api.nvim_set_var("loaded_tar", 1)
vim.api.nvim_set_var("loaded_tarPlugin", 1)
vim.api.nvim_set_var("loaded_tutor_mode_plugin", 1)
vim.api.nvim_set_var("loaded_zip", 1)
vim.api.nvim_set_var("loaded_zipPlugin", 1)

-- I have xsel on my system
local termfeatures = vim.g.termfeatures or {}
termfeatures.osc52 = false
vim.api.nvim_set_var("termfeatures", termfeatures)

-----------------------
-- Internal Behavior --
-----------------------

vim.api.nvim_set_option_value("fileformats", "unix,dos", global_scope)
vim.api.nvim_set_option_value("jop", "stack,clean,view", global_scope)

vim.api.nvim_set_option_value("swapfile", false, global_scope)
vim.api.nvim_set_option_value("undofile", true, global_scope)
vim.api.nvim_set_option_value("updatetime", 300, global_scope)

-- :h 'sd'
vim.api.nvim_set_option_value("sd", [[<0,'100,/0,:1000,h]], global_scope)

-- Unsimplify mappings
-- See :h <tab> and https://github.com/neovim/neovim/pull/17932
-- NOTE: For this to work in Tmux, that config has to be handled separately
vim.keymap.set("n", "<C-i>", "<C-i>")
vim.keymap.set("n", "<tab>", "<tab>")
vim.keymap.set("n", "<C-m>", "<C-m>")
vim.keymap.set("n", "<cr>", "<cr>")
vim.keymap.set("n", "<C-[>", "<C-[>")
vim.keymap.set("n", "<esc>", "<esc>")

--------
-- UI --
--------

vim.api.nvim_set_option_value("mouse", "", global_scope)

vim.api.nvim_set_option_value("backspace", "indent,eol,nostop", global_scope)
vim.api.nvim_set_option_value(
    "mps",
    vim.api.nvim_get_option_value("mps", global_scope) .. ",<:>",
    { scope = "global" }
)

--- W - Don't overwrite readonly files
--- Z - Don't reset readonly with W!
vim.api.nvim_set_option_value(
    "cpo",
    vim.api.nvim_get_option_value("cpo", global_scope) .. "WZ",
    { scope = "global" }
)
vim.api.nvim_set_option_value("modelines", 1, global_scope)

vim.api.nvim_set_option_value("ignorecase", true, global_scope)
vim.api.nvim_set_option_value("smartcase", true, global_scope)
-- Don't want screen shifting while entering search/subsitute patterns
vim.api.nvim_set_option_value("incsearch", false, global_scope)

vim.api.nvim_set_option_value("selection", "old", global_scope)
vim.api.nvim_set_option_value("so", Scrolloff, global_scope)

vim.api.nvim_set_option_value("splitbelow", true, global_scope)
vim.api.nvim_set_option_value("splitright", true, global_scope)
-- For some reason, uselast needs to be manually set globally
vim.api.nvim_set_option_value("switchbuf", "useopen,uselast", global_scope)

vim.api.nvim_set_option_value("foldenable", false, global_scope)

--------------------------
--- Text Input/Display ---
--------------------------

vim.api.nvim_set_option_value("tabstop", 4, global_scope)
vim.api.nvim_set_option_value("softtabstop", 4, global_scope)
vim.api.nvim_set_option_value("shiftwidth", 4, global_scope)
vim.api.nvim_set_option_value("expandtab", true, global_scope)
vim.api.nvim_set_option_value("shiftround", true, global_scope)

---------------------
-- Buffer Behavior --
---------------------

-- https://github.com/neovim/neovim/pull/35536
-- https://github.com/neovim/neovim/issues/35575
-- Issue is better after this pull request, but not resolve. In this file I can see some
-- global scope settings still whited out.
-- vim.api.nvim_set_option_value("wrap", false, global_scope)
-- For fts where opt_local wrap is true
-- TODO: Test this again
vim.api.nvim_set_option_value("breakindent", true, global_scope)
vim.api.nvim_set_option_value("linebreak", true, global_scope)
vim.api.nvim_set_option_value("smartindent", true, global_scope)

local dict = vim.fn.expand("~/.local/bin/words/words_alpha.txt")
vim.api.nvim_set_option_value("dictionary", dict, global_scope)
vim.api.nvim_set_option_value("spell", false, global_scope)
vim.api.nvim_set_option_value("spelllang", "en_us", global_scope)

----------------
-- Aesthetics --
----------------

vim.api.nvim_set_option_value("fcs", "eob: ", global_scope)

local blink_setting = "blinkon1-blinkoff1"
local norm_cursor = "n:block" .. blink_setting
local ver_cursor = "i-sm-c-ci-t:ver100-" .. blink_setting
local hor_cursor = "o-v-ve-r-cr:hor100-" .. blink_setting
local gcr = norm_cursor .. "," .. ver_cursor .. "," .. hor_cursor
vim.api.nvim_set_option_value("guicursor", gcr, global_scope)

--- a - All abbreviations
--- s - No search hit top/bottom messages
--- I - No intro message
--- W - No "written" notifications
vim.api.nvim_set_option_value(
    "shm",
    vim.api.nvim_get_option_value("shm", global_scope) .. "asIW",
    { scope = "global" }
)

vim.api.nvim_set_option_value("ru", false, global_scope)

vim.filetype.add({ filename = { [".bashrc_custom"] = "sh" } })

---@param event string|string[]
---@param opt string
---@param val any
local function autoset_winopt(event, opt, val)
    vim.api.nvim_create_autocmd(event, {
        group = set_group,
        callback = function()
            vim.api.nvim_set_option_value(opt, val, { win = vim.api.nvim_get_current_win() })
        end,
    })
end

------------------
--- Cursorline ---
------------------

vim.api.nvim_set_option_value("cul", true, global_scope)
autoset_winopt("WinEnter", "cul", true)
autoset_winopt("WinLeave", "cul", false)

----------------------
--- Format Options ---
----------------------

-- See help fo-table
-- Since multiple runtime ftplugin files set formatoptions, correct here
vim.api.nvim_create_autocmd({ "FileType" }, {
    group = set_group,
    pattern = "*",
    callback = function(ev)
        local fo = vim.api.nvim_get_option_value("fo", { buf = ev.buf })
        local new_fo = string.gsub(fo, "o", "")
        vim.api.nvim_set_option_value("fo", new_fo, { buf = ev.buf })
    end,
})

-----------------
--- Listchars ---
-----------------

vim.api.nvim_set_option_value("list", true, global_scope)
vim.api.nvim_set_option_value(
    "lcs",
    "tab:<->,extends:»,precedes:«,nbsp:␣,trail:⣿",
    global_scope
)
autoset_winopt("InsertEnter", "list", false)
autoset_winopt("InsertLeave", "list", true)

------------------
--- Numberline ---
------------------

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
vim.api.nvim_set_option_value("nu", true, global_scope)
vim.api.nvim_set_option_value("rnu", true, global_scope)
vim.api.nvim_set_option_value("cc", "100", global_scope)
vim.api.nvim_set_option_value("nuw", 5, global_scope)
vim.api.nvim_set_option_value("scl", "yes:1", global_scope)
vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = set_group,
    callback = function()
        vim.api.nvim_set_option_value("rnu", false, { win = vim.api.nvim_get_current_win() })
        if not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype) then vim.cmd("redraw") end
    end,
})

-- MID: can BufWinEnter be used instead of BufEnter?

autoset_winopt({ "WinLeave", "BufLeave" }, "rnu", false)
autoset_winopt({ "WinEnter", "CmdlineLeave", "BufEnter" }, "rnu", true)

----------------------
-- Autocmd Controls --
----------------------

-- BufReadPre does not work reliably with FzfLua or my Harpoon open script
-- MID: It is probably worth understanding the load process for both of them
vim.api.nvim_create_autocmd("BufReadPost", {
    group = set_group,
    desc = "Go to the last cursor position when opening a buffer",
    callback = function(ev)
        local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
        if mark[1] < 1 or mark[1] > vim.api.nvim_buf_line_count(ev.buf) then return end

        vim.api.nvim_cmd({ cmd = "normal", args = { 'g`"zz' }, bang = true }, {})
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
        vim.api.nvim_cmd({ cmd = "nohlsearch" }, {})
    end),
})

-- https://github.com/yutkat/dotfiles/blob/main/.config/nvim/lua/rc/autocmd.lua
-- MID: Seems interesting. Do with vim.system
-- vim.api.nvim_create_autocmd({ "BufWritePost" }, {
--     group = group_name,
--     pattern = "*",
--     callback = function()
--         if string.match(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], "^#!") then
--             if string.match(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1], ".+/bin/.+") then
--                 vim.cmd([[silent !chmod a+x <afile>]])
--             end
--         end
--     end,
--     once = false,
-- })

-- vim.opt.lazyredraw = false -- Causes unpredictable problems
-- vim.opt.startofline = false -- Makes gg/G feel weird
-- vim.opt.winborder = "single" -- Sets arbitrary border around Zen mode display

-- LOW: SSH Clipboard Config
-- https://github.com/tjdevries/config.nvim/blob/master/plugin/clipboard.lua

local set_group = Augroup("set-group", { clear = true })
local global_scope = { scope = "global" }

-- LOW: Which settings in here can be deferred? The problem is making sure that global scope
-- settings are picked up

-------------------
--- Global Vars ---
-------------------

Gset("no_plugin_maps", 1)

--- :h standard-plugin-list
--- Disabling these has a non-trivial effect on startup time
Gset("loaded_2html_plugin", 1)
Gset("did_install_default_menus", 1)
Gset("loaded_gzip", 1)
Gset("loaded_man", 1)
Gset("loaded_matchit", 1)
Gset("loaded_matchparen", 1)
Gset("loaded_netrw", 1)
Gset("loaded_netrwPlugin", 1)
Gset("loaded_netrwSettings", 1)
Gset("loaded_remote_plugins", 1)
Gset("loaded_shada_plugin", 1)
Gset("loaded_spellfile_plugin", 1)
Gset("loaded_tar", 1)
Gset("loaded_tarPlugin", 1)
Gset("loaded_tutor_mode_plugin", 1)
Gset("loaded_zip", 1)
Gset("loaded_zipPlugin", 1)

-- I have xsel on my system
local termfeatures = vim.g.termfeatures or {}
termfeatures.osc52 = false
Gset("termfeatures", termfeatures)

-----------------------
-- Internal Behavior --
-----------------------

SetOpt("fileformats", "unix,dos", global_scope)
SetOpt("jop", "stack,clean,view", global_scope)

SetOpt("swapfile", false, global_scope)
SetOpt("undofile", true, global_scope)
SetOpt("updatetime", 300, global_scope)

-- :h 'sd'
SetOpt("sd", [[<0,'100,/0,:1000,h]], global_scope)

-- Unsimplify mappings
-- See :h <tab> and https://github.com/neovim/neovim/pull/17932
-- NOTE: For this to work in Tmux, that config has to be handled separately
Map("n", "<C-i>", "<C-i>")
Map("n", "<tab>", "<tab>")
Map("n", "<C-m>", "<C-m>")
Map("n", "<cr>", "<cr>")
Map("n", "<C-[>", "<C-[>")
Map("n", "<esc>", "<esc>")

--------
-- UI --
--------

SetOpt("mouse", "", global_scope)

SetOpt("backspace", "indent,eol,nostop", global_scope)
SetOpt("mps", GetOpt("mps", global_scope) .. ",<:>", { scope = "global" })

--- W - Don't overwrite readonly files
--- Z - Don't reset readonly with W!
SetOpt("cpo", GetOpt("cpo", global_scope) .. "WZ", { scope = "global" })
SetOpt("modelines", 1, global_scope)

SetOpt("ignorecase", true, global_scope)
SetOpt("smartcase", true, global_scope)
-- Don't want screen shifting while entering search/subsitute patterns
SetOpt("incsearch", false, global_scope)

SetOpt("selection", "old", global_scope)
SetOpt("so", Scrolloff_Val, global_scope)

SetOpt("splitbelow", true, global_scope)
SetOpt("splitright", true, global_scope)
-- For some reason, uselast needs to be manually set globally
SetOpt("switchbuf", "useopen,uselast", global_scope)

SetOpt("foldenable", false, global_scope)

--------------------------
--- Text Input/Display ---
--------------------------

SetOpt("tabstop", 4, global_scope)
SetOpt("softtabstop", 4, global_scope)
SetOpt("shiftwidth", 4, global_scope)
SetOpt("expandtab", true, global_scope)
SetOpt("shiftround", true, global_scope)

---------------------
-- Buffer Behavior --
---------------------

-- https://github.com/neovim/neovim/pull/35536
-- https://github.com/neovim/neovim/issues/35575
-- Issue is better after this pull request, but not resolve. In this file I can see some
-- global scope settings still whited out.
-- SetOpt("wrap", false, global_scope)
-- For fts where opt_local wrap is true
SetOpt("breakindent", true, global_scope)
SetOpt("linebreak", true, global_scope)
SetOpt("smartindent", true, global_scope)

local dict = vim.fn.expand("~/.local/bin/words/words_alpha.txt")
SetOpt("dictionary", dict, global_scope)
SetOpt("spell", false, global_scope)
SetOpt("spelllang", "en_us", global_scope)

----------------
-- Aesthetics --
----------------

SetOpt("fcs", "eob: ", global_scope)

local blink_setting = "blinkon1-blinkoff1"
local norm_cursor = "n:block" .. blink_setting
local ver_cursor = "i-sm-c-ci-t:ver100-" .. blink_setting
local hor_cursor = "o-v-ve-r-cr:hor100-" .. blink_setting
local gcr = norm_cursor .. "," .. ver_cursor .. "," .. hor_cursor
SetOpt("guicursor", gcr, global_scope)

--- a - All abbreviations
--- s - No search hit top/bottom messages
--- I - No intro message
--- W - No "written" notifications
SetOpt("shm", GetOpt("shm", global_scope) .. "asIW", { scope = "global" })

SetOpt("ru", false, global_scope)

vim.filetype.add({ filename = { [".bashrc_custom"] = "sh" } })

--- @param event string|string[]
--- @param opt string
--- @param val any
local function autoset_winopt(event, opt, val)
    Autocmd(event, {
        group = set_group,
        callback = function()
            SetOpt(opt, val, { win = vim.api.nvim_get_current_win() })
        end,
    })
end

------------------
--- Cursorline ---
------------------

SetOpt("cul", true, global_scope)
autoset_winopt("WinEnter", "cul", true)
autoset_winopt("WinLeave", "cul", false)

----------------------
--- Format Options ---
----------------------

-- See help fo-table
-- Since multiple runtime ftplugin files set formatoptions, correct here
Autocmd({ "FileType" }, {
    group = set_group,
    pattern = "*",
    callback = function(ev)
        local fo = GetOpt("fo", { buf = ev.buf })
        local new_fo = string.gsub(fo, "o", "")
        SetOpt("fo", new_fo, { buf = ev.buf })
    end,
})

-----------------
--- Listchars ---
-----------------

SetOpt("list", true, global_scope)
SetOpt("lcs", "tab:<->,extends:»,precedes:«,nbsp:␣,trail:⣿", global_scope)
autoset_winopt("InsertEnter", "list", false)
autoset_winopt("InsertLeave", "list", true)

------------------
--- Numberline ---
------------------

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
SetOpt("nu", true, global_scope)
SetOpt("rnu", true, global_scope)
SetOpt("cc", "100", global_scope)
SetOpt("nuw", 5, global_scope)
SetOpt("scl", "yes:1", global_scope)
Autocmd("CmdlineEnter", {
    group = set_group,
    callback = function()
        SetOpt("rnu", false, { win = vim.api.nvim_get_current_win() })
        if not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype) then vim.cmd("redraw") end
    end,
})

autoset_winopt({ "WinLeave", "BufLeave" }, "rnu", false)
autoset_winopt({ "WinEnter", "CmdlineLeave", "BufEnter" }, "rnu", true)

----------------------
-- Autocmd Controls --
----------------------

-- BufReadPre does not work reliably with FzfLua or my Harpoon open script
-- MID: It is probably worth understanding the load process for both of them
Autocmd("BufReadPost", {
    group = set_group,
    desc = "Go to the last cursor position when opening a buffer",
    callback = function(ev)
        local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
        if mark[1] < 1 or mark[1] > vim.api.nvim_buf_line_count(ev.buf) then return end

        Cmd({ cmd = "normal", args = { 'g`"zz' }, bang = true }, {})
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

Autocmd(clear_conditions, {
    group = set_group,
    pattern = "*",
    -- The highlight state is saved and restored when autocmds are triggered, so
    -- schedule_wrap is used to trigger nohlsearch aftewards
    -- See nohlsearch() help
    callback = vim.schedule_wrap(function()
        Cmd({ cmd = "nohlsearch" }, {})
    end),
})

-- vim.opt.lazyredraw = false -- Causes unpredictable problems
-- vim.opt.startofline = false -- Makes gg/G feel weird
-- vim.opt.winborder = "single" -- Sets arbitrary border around Zen mode display

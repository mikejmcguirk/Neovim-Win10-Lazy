local api = vim.api

-------------------
--- GLOBAL VARS ---
-------------------

api.nvim_set_var("no_plugin_maps", 1)

--- :h standard-plugin-list
api.nvim_set_var("loaded_2html_plugin", 1)
api.nvim_set_var("did_install_default_menus", 1)
api.nvim_set_var("loaded_gzip", 1)
api.nvim_set_var("loaded_man", 1)
api.nvim_set_var("loaded_matchit", 1)
api.nvim_set_var("loaded_matchparen", 1)
api.nvim_set_var("loaded_netrw", 1)
api.nvim_set_var("loaded_netrwPlugin", 1)
api.nvim_set_var("loaded_netrwSettings", 1)
api.nvim_set_var("loaded_remote_plugins", 1)
api.nvim_set_var("loaded_shada_plugin", 1)
api.nvim_set_var("loaded_spellfile_plugin", 1)
api.nvim_set_var("loaded_tar", 1)
api.nvim_set_var("loaded_tarPlugin", 1)
api.nvim_set_var("loaded_tutor_mode_plugin", 1)
api.nvim_set_var("loaded_zip", 1)
api.nvim_set_var("loaded_zipPlugin", 1)

local termfeatures = vim.g.termfeatures or {}
termfeatures.osc52 = false -- I use xsel
api.nvim_set_var("termfeatures", termfeatures)

-------------
-- OPTIONS --
-------------

api.nvim_set_option_value("fileformats", "unix,dos", { scope = "global" })
api.nvim_set_option_value("sd", [[<0,'100,/0,:1000,h]], { scope = "global" })

api.nvim_set_option_value("swapfile", false, { scope = "global" })
api.nvim_set_option_value("undofile", true, { scope = "global" })
api.nvim_set_option_value("updatetime", 300, { scope = "global" })

local new_cpo = api.nvim_get_option_value("cpo", { scope = "global" }) .. "WZ" ---@type string
api.nvim_set_option_value("cpo", new_cpo, { scope = "global" })
api.nvim_set_option_value("jop", "stack,clean,view", { scope = "global" })
api.nvim_set_option_value("mls", 1, { scope = "global" })

api.nvim_set_option_value("bs", "indent,eol,nostop", { scope = "global" })
api.nvim_set_option_value("mouse", "", { scope = "global" })
local new_mps = api.nvim_get_option_value("mps", { scope = "global" }) .. ",<:>" ---@type string
api.nvim_set_option_value("mps", new_mps, { scope = "global" })
api.nvim_set_option_value("sel", "old", { scope = "global" })
api.nvim_set_option_value("so", Scrolloff, { scope = "global" })
api.nvim_set_option_value("fen", false, { scope = "global" })

api.nvim_set_option_value("ic", true, { scope = "global" })
api.nvim_set_option_value("scs", true, { scope = "global" })
api.nvim_set_option_value("is", false, { scope = "global" })

api.nvim_set_option_value("sb", true, { scope = "global" })
api.nvim_set_option_value("spr", true, { scope = "global" })
-- For some reason, uselast needs to be manually set globally
api.nvim_set_option_value("swb", "useopen,uselast", { scope = "global" })

-- https://github.com/neovim/neovim/pull/35536
-- https://github.com/neovim/neovim/issues/35575
-- Issue is better after this pull request, but not resolved. In this file I can see some
-- global scope settings still whited out.
-- For fts where opt_local wrap is true
-- TODO: Test this again
-- api.nvim_set_option_value("wrap", false, { scope = "global" })
api.nvim_set_option_value("breakindent", true, { scope = "global" })
api.nvim_set_option_value("linebreak", true, { scope = "global" })

api.nvim_set_option_value("ts", 4, { scope = "global" })
api.nvim_set_option_value("sts", 4, { scope = "global" })
api.nvim_set_option_value("sw", 4, { scope = "global" })
api.nvim_set_option_value("et", true, { scope = "global" })
api.nvim_set_option_value("sr", true, { scope = "global" })

vim.filetype.add({ filename = { [".bashrc_custom"] = "sh" } })

local dict = vim.fn.expand("~/.local/bin/words/words_alpha.txt") ---@type string
api.nvim_set_option_value("dictionary", dict, { scope = "global" })
api.nvim_set_option_value("spell", false, { scope = "global" })
api.nvim_set_option_value("spelllang", "en_us", { scope = "global" })

local new_shm = api.nvim_get_option_value("shm", { scope = "global" }) .. "asIW"
api.nvim_set_option_value("shm", new_shm, { scope = "global" })

local blink_setting = "blinkon1-blinkoff1" ---@type string
local norm_cursor = "n:block" .. blink_setting ---@type string
local ver_cursor = "i-sm-c-ci-t:ver100-" .. blink_setting ---@type string
local hor_cursor = "o-v-ve-r-cr:hor100-" .. blink_setting ---@type string
local gcr = norm_cursor .. "," .. ver_cursor .. "," .. hor_cursor ---@type string
api.nvim_set_option_value("gcr", gcr, { scope = "global" })

api.nvim_set_option_value("fcs", "eob: ", { scope = "global" })
api.nvim_set_option_value("ru", false, { scope = "global" })

local set_group = api.nvim_create_augroup("set-group", {})

---@param event string|string[]
---@param opt string
---@param val any
local function autoset_winopt(event, opt, val)
    api.nvim_create_autocmd(event, {
        group = set_group,
        callback = function()
            api.nvim_set_option_value(opt, val, { win = api.nvim_get_current_win() })
        end,
    })
end

api.nvim_set_option_value("cul", true, { scope = "global" })
autoset_winopt("WinEnter", "cul", true)
autoset_winopt("WinLeave", "cul", false)

api.nvim_set_option_value("list", true, { scope = "global" })
local new_lcs = "tab:<->,extends:»,precedes:«,nbsp:␣,trail:⣿" ---@type string
api.nvim_set_option_value("lcs", new_lcs, { scope = "global" })
autoset_winopt("InsertEnter", "list", false)
autoset_winopt("InsertLeave", "list", true)

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
api.nvim_set_option_value("nu", true, { scope = "global" })
api.nvim_set_option_value("rnu", true, { scope = "global" })
api.nvim_set_option_value("cc", "100", { scope = "global" })
api.nvim_set_option_value("nuw", 5, { scope = "global" })
api.nvim_set_option_value("scl", "yes:1", { scope = "global" })

autoset_winopt({ "WinLeave" }, "rnu", false)
autoset_winopt({ "WinEnter", "CmdlineLeave" }, "rnu", true)
api.nvim_create_autocmd("CmdlineEnter", {
    group = set_group,
    callback = function()
        api.nvim_set_option_value("rnu", false, { win = api.nvim_get_current_win() })
        if not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype) then vim.cmd("redraw") end
    end,
})

-- :h fo-table
-- Since multiple runtime ftplugin files set formatoptions, correct here
api.nvim_create_autocmd({ "FileType" }, {
    group = set_group,
    pattern = "*",
    callback = function(ev)
        local fo = api.nvim_get_option_value("fo", { buf = ev.buf }) ---@type string
        local new_fo = string.gsub(fo, "o", "") ---@type string
        api.nvim_set_option_value("fo", new_fo, { buf = ev.buf })
    end,
})

-- vim.opt.lazyredraw = false -- Causes unpredictable problems
-- vim.opt.startofline = false -- Makes gg/G feel weird
-- vim.opt.winborder = "single" -- Sets arbitrary border around Zen mode display

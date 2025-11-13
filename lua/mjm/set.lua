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

api.nvim_set_option_value("fileformats", "unix,dos", {})
api.nvim_set_option_value("sd", [[<0,'100,/0,:1000,h]], {})

api.nvim_set_option_value("swapfile", false, {})
api.nvim_set_option_value("undofile", true, {})
api.nvim_set_option_value("updatetime", 300, {})

local new_cpo = api.nvim_get_option_value("cpo", {}) .. "WZ" ---@type string
api.nvim_set_option_value("cpo", new_cpo, {})
api.nvim_set_option_value("jop", "stack,clean,view", {})
api.nvim_set_option_value("mls", 1, {})

api.nvim_set_option_value("bs", "indent,eol,nostop", {})
api.nvim_set_option_value("mouse", "", {})
local new_mps = api.nvim_get_option_value("mps", {}) .. ",<:>" ---@type string
api.nvim_set_option_value("mps", new_mps, {})
api.nvim_set_option_value("sel", "old", {})
api.nvim_set_option_value("so", Mjm_Scrolloff, {})
api.nvim_set_option_value("fen", false, {})

api.nvim_set_option_value("ic", true, {})
api.nvim_set_option_value("scs", true, {})
api.nvim_set_option_value("is", false, {})

api.nvim_set_option_value("sb", true, {})
api.nvim_set_option_value("spr", true, {})
-- For some reason, uselast needs to be manually set globally
api.nvim_set_option_value("swb", "useopen,uselast", {})

-- https://github.com/neovim/neovim/pull/35536
-- https://github.com/neovim/neovim/issues/35575
-- Issue is better after this pull request, but not resolved. In this file I can see some
-- global scope settings still whited out.
-- For fts where opt_local wrap is true
-- TODO: Test this again
-- api.nvim_set_option_value("wrap", false, {  })
api.nvim_set_option_value("breakindent", true, {})
-- TODO: Try formatlistpat for making bulleted lists in markdown. This would interface I think
-- with breakindentopt
api.nvim_set_option_value("linebreak", true, {})

api.nvim_set_option_value("ts", 4, {})
api.nvim_set_option_value("sts", 4, {})
api.nvim_set_option_value("sw", 4, {})
api.nvim_set_option_value("et", true, {})
api.nvim_set_option_value("sr", true, {})

vim.filetype.add({ filename = { [".bashrc_custom"] = "sh" } })

local dict = vim.fn.expand("~/.local/bin/words/words_alpha.txt") ---@type string
api.nvim_set_option_value("dictionary", dict, {})
api.nvim_set_option_value("spell", false, {})
api.nvim_set_option_value("spelllang", "en_us", {})

local new_shm = api.nvim_get_option_value("shm", {}) .. "asIW"
api.nvim_set_option_value("shm", new_shm, {})

local blink_setting = "blinkon1-blinkoff1" ---@type string
local norm_cursor = "n:block" .. blink_setting ---@type string
local ver_cursor = "i-sm-c-ci-t:ver100-" .. blink_setting ---@type string
local hor_cursor = "o-v-ve-r-cr:hor100-" .. blink_setting ---@type string
local gcr = norm_cursor .. "," .. ver_cursor .. "," .. hor_cursor ---@type string
api.nvim_set_option_value("gcr", gcr, {})

api.nvim_set_option_value("fcs", "eob: ", {})
api.nvim_set_option_value("ru", false, {})

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

api.nvim_set_option_value("cul", true, {})
autoset_winopt("WinEnter", "cul", true)
autoset_winopt("WinLeave", "cul", false)

api.nvim_set_option_value("list", true, {})
local new_lcs = "tab:<->,extends:»,precedes:«,nbsp:␣,trail:⣿" ---@type string
api.nvim_set_option_value("lcs", new_lcs, {})
autoset_winopt("InsertEnter", "list", false)
autoset_winopt("InsertLeave", "list", true)

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
api.nvim_set_option_value("nu", true, {})
api.nvim_set_option_value("rnu", true, {})
api.nvim_set_option_value("cursorlineopt", "both", {})
-- LOW: Could set this as default "" then set it on filetype to prevent it from showing in
-- empty buffers. Low value for complexity though
api.nvim_set_option_value("cc", "100", {})
api.nvim_set_option_value("nuw", 5, {})
api.nvim_set_option_value("scl", "yes:1", {})

autoset_winopt({ "WinLeave" }, "rnu", false)
autoset_winopt({ "WinEnter", "BufWinEnter", "CmdlineLeave" }, "rnu", true)
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

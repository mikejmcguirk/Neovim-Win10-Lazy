local api = vim.api
local getopt = api.nvim_get_option_value
local set_opt = api.nvim_set_option_value

-- api.nvim_set_var("no_plugin_maps", 1)
-- api.nvim_set_var("omni_sql_no_default_maps", 1)

-- TODO: This makes the intro screen not show
-- Or rather, it shows then flickers off
-- Would need to first test with a config that only enables ui2. If that works, then I need to
-- figure out what other thing in combination with this is causing the issue. Is that an issue
-- then of my config being over-elaborate or a problem in ui2?
-- :h ui2
require("vim._core.ui2").enable()

-------------
-- OPTIONS --
-------------

local global_scope = { scope = "global" }

set_opt("fileformats", "unix,dos", global_scope)
set_opt("shada", [[<0,'100,/0,:1000,h]], global_scope)

set_opt("swf", false, global_scope)
set_opt("udf", true, global_scope)
set_opt("ut", 300, global_scope)

mjm.opt.flag_add("cpoptions", { "W", "Z" }, global_scope)
set_opt("jop", "stack,clean,view", global_scope)
set_opt("mls", 1, global_scope)

set_opt("bs", "indent,eol,nostop", global_scope)
set_opt("mouse", "", global_scope)
local new_mps = getopt("mps", global_scope) .. ",<:>" ---@type string
set_opt("mps", new_mps, global_scope)
set_opt("sel", "old", global_scope)
set_opt("so", 6, global_scope)
set_opt("fen", false, global_scope)

set_opt("ic", true, global_scope)
set_opt("scs", true, global_scope)
set_opt("is", false, global_scope)

set_opt("sb", true, global_scope)
set_opt("spr", true, global_scope)
-- For some reason, uselast needs to be manually set globally
set_opt("swb", "useopen,uselast", global_scope)

set_opt("wrap", false, global_scope)
set_opt("bri", true, global_scope)
set_opt("lbr", true, global_scope)

set_opt("ts", mjm.v.shiftwidth, global_scope)
set_opt("sts", mjm.v.shiftwidth, global_scope)
set_opt("sw", mjm.v.shiftwidth, global_scope)
set_opt("et", true, global_scope)
set_opt("sr", true, global_scope)

vim.filetype.add({ filename = { [".bashrc_custom"] = "sh" } })

local dict = vim.fn.expand("~/.local/bin/words/words_alpha.txt") ---@type string
set_opt("dict", dict, global_scope)
set_opt("spell", false, global_scope)
set_opt("spelllang", "en_us", global_scope)

mjm.opt.flag_add("shortmess", { "a", "s", "W" }, global_scope)
set_opt("report", 9999, { scope = "global" })

local blink = "-blinkon1-blinkoff1"
local blk = "n:block"
local ver = "i-sm-c-ci-t:ver100"
local hor = "o-v-ve-r-cr:hor100"
local gcr = table.concat({ blk, blink, ",", ver, blink, ",", hor, blink }, "")
set_opt("guicursor", gcr, global_scope)

set_opt("fcs", "eob: ", global_scope)
set_opt("ru", false, global_scope)
set_opt("winborder", "single", global_scope)

local set_group = api.nvim_create_augroup("set-group", {})

---@param event string|string[]
---@param opt string
---@param val any
local function autoset_winopt(event, opt, val)
    api.nvim_create_autocmd(event, {
        group = set_group,
        callback = function()
            set_opt(opt, val, { win = 0 })
        end,
    })
end

set_opt("cul", true, global_scope)
autoset_winopt("WinEnter", "cul", true)
autoset_winopt("WinLeave", "cul", false)

set_opt("list", true, global_scope)
set_opt("lcs", mjm.v.lcs, global_scope)
autoset_winopt("InsertEnter", "list", false)
autoset_winopt("InsertLeave", "list", true)

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
set_opt("nu", true, global_scope)
set_opt("rnu", true, global_scope)
set_opt("cursorlineopt", "both", global_scope)
set_opt("cc", "80,100", global_scope)
set_opt("nuw", 5, global_scope)
set_opt("scl", "yes:1", global_scope)

-- :h fo-table
-- Since multiple runtime ftplugin files set formatoptions, correct here
api.nvim_create_autocmd({ "FileType" }, {
    group = set_group,
    pattern = "*",
    callback = function(ev)
        mjm.opt.flag_rm("fo", { "o" }, { buf = ev.buf })
    end,
})

-- NON:
-- lz:
-- - Makes plugin dev harder because you can't see standard redraw timings
-- - Causes unpredictable problems
-- sol: Makes gg/G feel weird

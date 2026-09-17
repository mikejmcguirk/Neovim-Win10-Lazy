local api = vim.api

local scope_global_append = { operation = "append", scope = "global" }
local scope_global_rm = { operation = "remove", scope = "global" }
local scope_global = { scope = "global" }

-- :h ui2
require("vim._core.ui2").enable()

-----------------------------
-- MARK: Backend/Internals --
-----------------------------

api.nvim_set_option_value("shada", [[<0,'100,/0,:1000,h]], scope_global)
api.nvim_set_option_value("swf", false, scope_global)
api.nvim_set_option_value("udf", true, scope_global)
api.nvim_set_option_value("ut", 300, scope_global)
api.nvim_set_option_value("ffs", "unix,dos", scope_global)

vim.filetype.add({ filename = { [".bashrc_custom"] = "sh" } })

--------------------------------
-- MARK: Global Nvim Behavior --
--------------------------------

api.nvim_set_option_value("cpo", "WZ", scope_global_append)
api.nvim_set_option_value("jop", "stack,clean,view", scope_global)
api.nvim_set_option_value("mls", 1, scope_global)

api.nvim_set_option_value("sb", true, scope_global)
api.nvim_set_option_value("spr", true, scope_global)
-- For some reason, uselast needs to be manually set globally
api.nvim_set_option_value("swb", "useopen,uselast", scope_global)

local dict = vim.fn.expand("~/.local/bin/words/words_alpha.txt")
api.nvim_set_option_value("dict", dict, scope_global)
api.nvim_set_option_value("spell", false, scope_global)
api.nvim_set_option_value("spelllang", "en_us", scope_global)

--------------
-- MARK: UI --
--------------

api.nvim_set_option_value("fen", false, scope_global)
api.nvim_set_option_value("so", 6, scope_global)

api.nvim_set_option_value("bs", "indent,eol,nostop", scope_global)
api.nvim_set_option_value("mouse", "", scope_global)
api.nvim_set_option_value("mps", "<:>", scope_global_append)
api.nvim_set_option_value("sel", "old", scope_global)

api.nvim_set_option_value("ic", true, scope_global)
api.nvim_set_option_value("is", false, scope_global)
api.nvim_set_option_value("pvp", "height:21,width:107,border:bold")
api.nvim_set_option_value("scs", true, scope_global)

api.nvim_set_option_value("et", true, scope_global)
api.nvim_set_option_value("sr", true, scope_global)
api.nvim_set_option_value("sts", 0, scope_global)
api.nvim_set_option_value("sw", mjm.v.shiftwidth, scope_global)
api.nvim_set_option_value("ts", mjm.v.shiftwidth, scope_global)

-------------------
-- MARK: Display --
-------------------

api.nvim_set_option_value("wrap", false, scope_global)
api.nvim_set_option_value("bri", true, scope_global)
api.nvim_set_option_value("lbr", true, scope_global)
-- So that '"...bar."' stays on one line. Doing these individually is necessary for some reason.
api.nvim_set_option_value("brk", ".", scope_global_rm)
api.nvim_set_option_value("brk", "?", scope_global_rm)
api.nvim_set_option_value("brk", "*", scope_global_rm)
-- So `@param` is not broken up between two lines.
api.nvim_set_option_value("brk", "@", scope_global_rm)

api.nvim_set_option_value("shm", "asuW", { operation = "append", scope = "global" })
api.nvim_set_option_value("report", 9999, { scope = "global" })

local blink = "-blinkon1-blinkoff1"
local blk = "n:block"
local ver = "i-sm-c-ci-t:ver100"
local hor = "o-v-ve-r-cr:hor100"
local gcr = blk .. blink .. "," .. ver .. blink .. "," .. hor .. blink
api.nvim_set_option_value("guicursor", gcr, scope_global)

api.nvim_set_option_value("fcs", "eob: ", scope_global)
api.nvim_set_option_value("ru", false, scope_global)
api.nvim_set_option_value("winborder", "single", scope_global)

-- MID: Is this a problem in non-lcs wins?
api.nvim_set_option_value("list", true, scope_global)

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
api.nvim_set_option_value("cc", "80,100", scope_global)
api.nvim_set_option_value("cul", true, scope_global)
api.nvim_set_option_value("culopt", "both", scope_global)
api.nvim_set_option_value("nu", true, scope_global)
api.nvim_set_option_value("nuw", 5, scope_global)
api.nvim_set_option_value("rnu", true, scope_global)
api.nvim_set_option_value("scl", "yes:1", scope_global)

------------------------
-- MARK: Autoset Opts --
------------------------

local set_group = api.nvim_create_augroup("set-group", {})

---@param event vim.api.keyset.events
---@param opt string
---@param val any
local function autoset_winopt(event, opt, val)
    api.nvim_create_autocmd(event, {
        group = set_group,
        callback = function()
            api.nvim_set_option_value(opt, val, { win = 0 })
        end,
    })
end

autoset_winopt("WinEnter", "cul", true)
autoset_winopt("WinLeave", "cul", false)

-- :h fo-table
-- Since multiple runtime ftplugin files set formatoptions, correct here
api.nvim_create_autocmd({ "FileType" }, {
    group = set_group,
    pattern = "*",
    callback = function(ev)
        api.nvim_set_option_value("fo", "o", { buf = ev.buf, operation = "remove" })
    end,
})

---Lcs indent guides have gaps on blank lines. After using them for a few months, they still
---catch my attention. Use a plugin for indent guides instead.
---@param buf uinteger
local function lcs_get_and_set(buf)
    local lcs_tbl = {}
    lcs_tbl[#lcs_tbl + 1] = "extends:»,precedes:«,nbsp:␣,trail:⣿"
    if api.nvim_get_option_value("et", { buf = buf }) == true then
        lcs_tbl[#lcs_tbl + 1] = "tab:<->"
    else
        lcs_tbl[#lcs_tbl + 1] = "lead:⣿"
        lcs_tbl[#lcs_tbl + 1] = "tab:   "
    end

    api.nvim_set_option_value("lcs", table.concat(lcs_tbl, ","), { scope = "local" })
end

local lcs_group_name = "mjm.lcs"
local lcs_group = api.nvim_create_augroup(lcs_group_name, {})
api.nvim_create_autocmd("FileType", {
    group = lcs_group,
    -- Schedule wrap to let other filetype options set.
    callback = vim.schedule_wrap(function(ev)
        local buf = ev.buf
        -- In case this fired on a temporary buffer.
        if not api.nvim_buf_is_valid(buf) then
            return
        end

        if api.nvim_get_option_value("bt", { buf = buf }) ~= "" then
            return
        end

        lcs_get_and_set(buf)
    end),
})

-- MID: Instead of InsertEnter/InsertLeave, do it based on ModeChanged.
-- - Would prevent leading/trailing spacechars from appearing in `ni` mode.
api.nvim_create_autocmd("InsertEnter", {
    group = lcs_group,
    callback = function()
        local win = api.nvim_get_current_win()
        api.nvim_set_option_value("lcs", "trail:⣿", { operation = "remove", win = win })
    end,
})

api.nvim_create_autocmd("InsertLeave", {
    group = lcs_group,
    callback = function()
        local win = api.nvim_get_current_win()
        api.nvim_set_option_value("lcs", "trail:⣿", { operation = "append", win = win })
    end,
})

local api = vim.api

local getopt = api.nvim_get_option_value
local setopt = api.nvim_set_option_value

-------------
-- OPTIONS --
-------------

setopt("fileformats", "unix,dos", {})
setopt("sd", [[<0,'100,/0,:1000,h]], {})

setopt("swf", false, {})
setopt("udf", true, {})
setopt("ut", 300, {})

local new_cpo = getopt("cpo", {}) .. "WZ" ---@type string
setopt("cpo", new_cpo, {})
setopt("jop", "stack,clean,view", {})
setopt("mls", 1, {})

setopt("bs", "indent,eol,nostop", {})
setopt("mouse", "", {})
local new_mps = getopt("mps", {}) .. ",<:>" ---@type string
setopt("mps", new_mps, {})
setopt("sel", "old", {})
setopt("so", 6, {})
setopt("fen", false, {})

setopt("ic", true, {})
setopt("scs", true, {})
setopt("is", false, {})

setopt("sb", true, {})
setopt("spr", true, {})
-- For some reason, uselast needs to be manually set globally
setopt("swb", "useopen,uselast", {})

setopt("wrap", false, {})
setopt("breakindent", true, {})
setopt("linebreak", true, {})

setopt("ts", Mjm_Sw, {})
setopt("sts", Mjm_Sw, {})
setopt("sw", Mjm_Sw, {})
setopt("et", true, {})
setopt("sr", true, {})

vim.filetype.add({ filename = { [".bashrc_custom"] = "sh" } })

local dict = vim.fn.expand("~/.local/bin/words/words_alpha.txt") ---@type string
setopt("dict", dict, {})
setopt("spell", false, {})
setopt("spelllang", "en_us", {})

local new_shm = getopt("shm", {}) .. "asIW" ---@type string
setopt("shm", new_shm, { scope = "global" })
setopt("report", 9999, { scope = "global" })

local blink_setting = "blinkon1-blinkoff1" ---@type string
local norm_cursor = "n:block" .. blink_setting ---@type string
local ver_cursor = "i-sm-c-ci-t:ver100-" .. blink_setting ---@type string
local hor_cursor = "o-v-ve-r-cr:hor100-" .. blink_setting ---@type string
local gcr = norm_cursor .. "," .. ver_cursor .. "," .. hor_cursor ---@type string
setopt("gcr", gcr, {})

setopt("fcs", "eob: ", {})
setopt("ru", false, {})
setopt("winborder", "single", {})

local set_group = api.nvim_create_augroup("set-group", {})

---@param event string|string[]
---@param opt string
---@param val any
local function autoset_winopt(event, opt, val)
    api.nvim_create_autocmd(event, {
        group = set_group,
        callback = function()
            setopt(opt, val, { win = api.nvim_get_current_win() })
        end,
    })
end

setopt("cul", true, {})
autoset_winopt("WinEnter", "cul", true)
autoset_winopt("WinLeave", "cul", false)

setopt("list", true, {})
setopt("lcs", Mjm_Lcs, {})
autoset_winopt("InsertEnter", "list", false)
autoset_winopt("InsertLeave", "list", true)

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
setopt("nu", true, {})
setopt("rnu", true, {})
setopt("cursorlineopt", "both", {})
setopt("cc", "80,100", {})
setopt("nuw", 5, {})
setopt("scl", "yes:1", {})

autoset_winopt({ "WinLeave" }, "rnu", false)
autoset_winopt({ "WinEnter", "BufWinEnter", "CmdlineLeave" }, "rnu", true)
api.nvim_create_autocmd("CmdlineEnter", {
    group = set_group,
    callback = function()
        setopt("rnu", false, { win = api.nvim_get_current_win() })
        if not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype) then
            vim.cmd("redraw")
        end
    end,
})

-- :h fo-table
-- Since multiple runtime ftplugin files set formatoptions, correct here
api.nvim_create_autocmd({ "FileType" }, {
    group = set_group,
    pattern = "*",
    callback = function(ev)
        mjm.opt.str_rm("fo", "o", { buf = ev.buf })
    end,
})

-- vim.o.lazyredraw = false -- Causes unpredictable problems
-- vim.o.startofline = false -- Makes gg/G feel weird

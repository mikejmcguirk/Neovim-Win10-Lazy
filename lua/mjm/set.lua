-- LOW: SSH clipboard config
-- https://github.com/tjdevries/config.nvim/blob/master/plugin/clipboard.lua
-- MAYBE: vim.g.deprecation_warnings = true -- Pre-silence deprecation warnings

local set_group = Augroup("set-group", { clear = true })
local global_scope = { scope = "global" }
local noremap = { noremap = true }

-------------------
--- Global Vars ---
-------------------

Gset("no_plugin_maps", 1)

--- :h standard-plugin-list
--- Disabling these has a non-trivial effect on startup time
--- LOW: No need to change now, but the 2html plugin appears to have been re-written in Lua, and
--- on load only creates an autocmd. Might be useful
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

Map({ "n", "x" }, "<Space>", "<Nop>")
Gset("mapleader", " ")
Gset("maplocalleader", " ")

-----------------------
-- Internal Behavior --
-----------------------

SetOpt("fileformats", "unix,dos", global_scope)
SetOpt("jop", "clean,view", global_scope)

SetOpt("swapfile", false, global_scope)
SetOpt("undofile", true, global_scope)
SetOpt("updatetime", 300, global_scope)

-- :h 'sd'
SetOpt("sd", [[<0,'100,/0,:1000,h]], global_scope)

-- Unsimplify mappings
-- See :h <tab> and https://github.com/neovim/neovim/pull/17932
-- NOTE: For this to work in Tmux, that config has to be handled separately
ApiMap("n", "<C-i>", "<C-i>", noremap)
ApiMap("n", "<tab>", "<tab>", noremap)
ApiMap("n", "<C-m>", "<C-m>", noremap)
ApiMap("n", "<cr>", "<cr>", noremap)
ApiMap("n", "<C-[>", "<C-[>", noremap)
ApiMap("n", "<esc>", "<esc>", noremap)

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
-- TODO: Test this again with a minimal config
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
autoset_winopt("InsertEnter", "list", true)
autoset_winopt("InsertLeave", "list", false)

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
        if not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype) then
            vim.cmd("redraw")
        end
    end,
})

-- LOW: Would this work with BufWinEnter instead?
-- Need BufLeave/BufEnter for this to work when going into help
autoset_winopt({ "WinLeave", "BufLeave" }, "rnu", false)
autoset_winopt({ "WinEnter", "CmdlineLeave", "BufEnter" }, "rnu", true)

----------------------
-- Autocmd Controls --
----------------------

Autocmd("BufWinEnter", {
    group = set_group,
    desc = "Go to the last location when opening a buffer",
    callback = function(ev)
        local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
        local line_count = vim.api.nvim_buf_line_count(ev.buf)
        if mark[1] < 1 or mark[1] > line_count then
            return
        end

        Cmd({ cmd = "normal", args = { 'g`"zz' } }, {})
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
        vim.cmd.nohlsearch()
    end),
})

----------------

-- vim.opt.lazyredraw = false -- Causes unpredictable problems
-- vim.opt.startofline = false -- Makes gg/G feel weird
-- vim.opt.winborder = "single" -- Sets arbitrary border around Zen mode display

-------------------
--- Colorscheme ---
-------------------

Cmd({ cmd = "hi", args = { "clear" } }, {})
if vim.g.syntax_on == 1 then
    Cmd({ cmd = "syntax", args = { "reset" } }, {})
end

-- NOTE: This is a bespoke version of Fluoromachine.nvim's delta theme
-- https://www.sessions.edu/color-calculator/
local black = "#000000" --- @type string
local fg = "#EFEFFD" --- @type string
local l_cyan = "#98FFFB" --- @type string
local cyan = "#558396" --- @type string
local l_green = "#C0FF98" --- @type string
local green = "#579964" --- @type string
local l_orange = "#FFD298" --- @type string
local orange = "#967A55" --- @type string
local orange_fg = "#FFF0E0" --- @type string
local l_pink = "#FF67D4" --- @type string
local pink = "#613852" --- @type string
local l_purple = "#D598FF" --- @type string
local purple = "#925393" --- @type string
local bold_purple = "#492949" --- @type string
local d_purple = "#251d2b" --- @type string
-- local d_purple_two = "#2b2233" --- @type string
-- Darkened from dark purple
local d_purple_three = "#18131c" --- @type string
local l_red = "#FF98B3" --- @type string
local l_yellow = "#EDFF98" --- @type string

--- @param old_hl string
--- @param cfg_ext table
local function hl_extend(old_hl, cfg_ext)
    local old_cfg = GetHl(0, { name = old_hl })
    return vim.tbl_extend("force", old_cfg, cfg_ext)
end

----------------------------
-- Diagnostics and Status --
----------------------------

SetHl(0, "DiagnosticError", { fg = l_red })
SetHl(0, "DiagnosticWarn", { fg = l_orange })
SetHl(0, "DiagnosticInfo", { fg = l_green })
SetHl(0, "DiagnosticHint", { fg = l_cyan })
SetHl(0, "DiagnosticUnnecessary", { underdashed = true }) -- Default link: Comment

SetHl(0, "DiagnosticUnderlineError", hl_extend("DiagnosticError", { underline = true }))
SetHl(0, "DiagnosticUnderlineWarn", hl_extend("DiagnosticWarn", { underline = true }))
SetHl(0, "DiagnosticUnderlineInfo", hl_extend("DiagnosticInfo", { underline = true }))
SetHl(0, "DiagnosticUnderlineHint", hl_extend("DiagnosticHint", { underline = true }))

-- Same here
SetHl(0, "DiffAdd", { fg = black, bg = l_green })
SetHl(0, "DiffChange", { fg = black, bg = l_orange })
SetHl(0, "DiffDelete", { fg = black, bg = l_red })

SetHl(0, "Added", { link = "DiagnosticInfo" }) -- (Default self-definition)
SetHl(0, "Changed", { link = "DiagnosticWarn" }) -- (Default self-definition)
SetHl(0, "Removed", { link = "DiagnosticError" }) -- (Default self-definition)

SetHl(0, "Error", { link = "DiagnosticError" }) --- (Default self-definition)
SetHl(0, "ErrorMsg", { link = "DiagnosticError" }) --- (Default self-definition)
SetHl(0, "WarningMsg", { link = "DiagnosticWarn" }) -- (Default self-definition)
SetHl(0, "MoreMsg", { link = "DiagnosticInfo" }) -- (Default self-definition)
SetHl(0, "Question", { link = "DiagnosticInfo" }) -- (Default self-definition)

SetHl(0, "SpellBad", { link = "DiagnosticError" }) -- (Default self-definition)
SetHl(0, "SpellLocal", { link = "DiagnosticWarn" }) -- (Default self-definition)
SetHl(0, "SpellCap", { link = "DiagnosticInfo" }) -- (Default self-definition)
SetHl(0, "SpellRare", { link = "DiagnosticHint" }) -- (Default self-definition)

---------------
-- Normal/Fg --
---------------

SetHl(0, "Normal", { fg = fg })

SetHl(0, "Delimiter", {})
SetHl(0, "Identifier", {})
SetHl(0, "NormalFloat", {}) -- Default self-definition
SetHl(0, "NormalNC", {}) -- Causes performance issues (default setting)

SetHl(0, "@variable", {}) --- Default self-definition
-- Meaningless without an LSP to determine scope
SetHl(0, "@variable.paramter", {}) --- Default self-definition
SetHl(0, "@variable.property", {}) --- Default self-definition

-- Can't eliminate at the token level because builtins and globals depend on it
SetHl(0, "@lsp.type.variable", {})

--------------------
--- Special Text ---
--------------------

SetHl(0, "Comment", { fg = purple, italic = true })
SetHl(0, "Conceal", { link = "Comment" }) -- (Default self-definition)

SetHl(0, "LspCodeLens", { fg = cyan })

SetHl(0, "NonText", { fg = pink })
SetHl(0, "SpecialKey", { link = "NonText" }) --- Default self-definition

SetHl(0, "Folded", { fg = purple, bg = bold_purple })

SetHl(0, "LspInlayHint", { fg = green, italic = true })

SetHl(0, "EndOfBuffer", {}) -- (Default link: Non-text)

----------------------------------
--- Builtins/Constants/Globals ---
----------------------------------

--- LOW: The "self" keyword should be italicized since it is an alias for the current object

SetHl(0, "Constant", { fg = l_red })

SetHl(0, "@constant.builtin", { link = "Constant" }) -- No default
SetHl(0, "@variable.builtin", { link = "Constant" }) -- No default

SetHl(0, "@lsp.typemod.function.global", { link = "Constant" }) -- Default @lsp
SetHl(0, "@lsp.typemod.variable.defaultLibrary", { link = "Constant" }) -- Default @lsp
SetHl(0, "@lsp.typemod.variable.global", { link = "Constant" }) -- Default @lsp

-----------------
--- Functions ---
-----------------

SetHl(0, "Function", { fg = l_yellow })

SetHl(0, "@function.builtin", { link = "Function" }) -- Default link to Special

--------------------------------------
--- Numbers/Booleans/Chars/Modules ---
--------------------------------------

SetHl(0, "Number", { fg = l_cyan }) -- (Default link: Constant)

SetHl(0, "Boolean", { link = "Number" }) -- (Default link: Constant)
SetHl(0, "Character", { link = "Number" }) -- (Default link: Constant)

SetHl(0, "@module", { link = "Number" }) -- (Default link: Type)

SetHl(0, "@lsp.type.namespace", { link = "Number" }) -- (Default link: Type)
SetHl(0, "@lsp.typemod.boolean.injected", { link = "Boolean" }) -- Default @lsp

SetHl(0, "@lsp.type.enumMember", hl_extend("Number", { italic = true })) -- (Default link: Type)

-------------------------------------------
--- Operators/PreProc/Statement/Special ---
-------------------------------------------

SetHl(0, "Operator", { fg = l_pink })

SetHl(0, "@lsp.typemod.arithmetiinjected", { link = "Operator" }) --- Default link @lsp
SetHl(0, "@lsp.typemod.comparison.injected", { link = "Operator" }) --- Default link @lsp

SetHl(0, "PreProc", { fg = l_pink, italic = true })

SetHl(0, "@function.macro", { link = "PreProc" }) -- Default link: Function
SetHl(0, "@preproc", { link = "PreProc" }) -- Custom TS Query

SetHl(0, "@lsp.type.macro", { link = "PreProc" }) -- (Default link: Constant)
SetHl(0, "@lsp.typemod.derive.macro", { link = "PreProc" }) -- (Default link: @lsp)
SetHl(0, "@lsp.typemod.lifetime.injected", { link = "PreProc" }) -- (Default link: @lsp)

SetHl(0, "Special", { fg = l_pink })

SetHl(0, "@lsp.typemod.attributeBracket.injected", { link = "Special" }) --- Default link @lsp

SetHl(0, "Statement", { fg = l_pink })

------------------
--- Parameters ---
------------------

SetHl(0, "@variable.parameter", { link = "@lsp.type.parameter" })

SetHl(0, "@lsp.type.parameter", { fg = l_orange }) -- Default link: Identifier

--------------
--- String ---
--------------

SetHl(0, "String", { fg = l_purple })

SetHl(0, "@string.escape", { fg = l_purple, italic = true })

SetHl(0, "@lsp.type.formatSpecifier", { link = "@string.escape" })

-------------
--- Types ---
-------------

SetHl(0, "Type", { fg = l_green })

SetHl(0, "@type.builtin", { link = "Type" }) -- Default link Special

SetHl(0, "@lsp.type.builtinType", { link = "Type" }) -- Default link @lsp

SetHl(0, "@lsp.type.typeAlias", hl_extend("Type", { italic = true }))

SetHl(0, "@lsp.type.selfTypeKeyword", { link = "@lsp.type.typeAlias" }) -- Default link @lsp

----------
--- UI ---
----------

SetHl(0, "CurSearch", { fg = black, bg = l_orange })
SetHl(0, "IncSearch", { fg = l_green })
SetHl(0, "Search", { fg = orange_fg, bg = orange })

SetHl(0, "QuickFixLine", { bg = bold_purple })

SetHl(0, "Visual", { bg = bold_purple })

SetHl(0, "CursorLineNr", { fg = l_green })
SetHl(0, "Directory", { fg = l_green })
SetHl(0, "LineNr", { fg = purple }) -- rnu
SetHl(0, "Title", { fg = l_green })
SetHl(0, "Todo", { fg = l_green })

SetHl(0, "MatchParen", { underline = true })

SetHl(0, "Pmenu", { fg = fg })
SetHl(0, "PmenuSel", { bg = bold_purple })
SetHl(0, "PmenuThumb", { bg = l_cyan })

SetHl(0, "ColorColumn", { bg = d_purple })
SetHl(0, "CursorLine", { link = "ColorColumn" }) -- (Default self-definition)
SetHl(0, "CursorColumn", { link = "ColorColumn" }) -- (Default self-definition)

SetHl(0, "WinSeparator", { fg = purple }) -- (Default link: Normal)
SetHl(0, "FloatBorder", { link = "WinSeparator" }) -- (Default link: NormalFloat)

SetHl(0, "StatusLine", { fg = fg, bg = d_purple_three })
SetHl(0, "StatusLineNC", { link = "StatusLine" }) -- (Default self-definition)
SetHl(0, "Tabline", { link = "StatusLine" }) -- (Default self-definition)

--- (Default self-definition. I have reverse video cursor set in the terminal)
SetHl(0, "Cursor", {})
--- (Default self-definition. I have reverse video cursor set in the terminal)
SetHl(0, "lCursor", {})
SetHl(0, "SignColumn", {}) -- Default self-definition

--------------
--- Markup ---
--------------

-- LOW: Lifted from Fluoromachine because they look familiar, but I've put no thought into
-- the actual reasoning behind these
SetHl(0, "@markup.environment", { fg = l_purple })
SetHl(0, "@markup.heading", { link = "Title" })
SetHl(0, "@markup.italic", { fg = l_green, italic = true })
SetHl(0, "@markup.link", { fg = l_cyan })
SetHl(0, "@markup.link.label", { fg = l_cyan })
SetHl(0, "@markup.link.url", { fg = purple })
SetHl(0, "@markup.list", { fg = l_pink })
SetHl(0, "@markup.list.checked", { fg = l_green })
SetHl(0, "@markup.math", { link = "Operator" })
SetHl(0, "@markup.quote", { link = "Comment" })
SetHl(0, "@markup.raw", { link = "Comment" })
SetHl(0, "@markup.raw.block", { link = "Comment" })
SetHl(0, "@markup.strikethrough", { fg = l_yellow, strikethrough = true })
SetHl(0, "@markup.strong", { fg = l_green, bold = true })
SetHl(0, "@markup.underline", { link = "Underlined" })

local function darken_hex(color, pct)
    local r = tonumber(color:sub(2, 3), 16)
    local g = tonumber(color:sub(4, 5), 16)
    local b = tonumber(color:sub(6, 7), 16)

    r = math.max(0, math.floor(r * (1 - pct / 100)))
    g = math.max(0, math.floor(g * (1 - pct / 100)))
    b = math.max(0, math.floor(b * (1 - pct / 100)))

    return string.format("#%02X%02X%02X", r, g, b)
end

local function lighten_hex(color, percent)
    local r = tonumber(color:sub(2, 3), 16)
    local g = tonumber(color:sub(4, 5), 16)
    local b = tonumber(color:sub(6, 7), 16)

    r = math.min(255, math.floor(r * (1 + percent / 100)))
    g = math.min(255, math.floor(g * (1 + percent / 100)))
    b = math.min(255, math.floor(b * (1 + percent / 100)))

    return string.format("#%02X%02X%02X", r, g, b)
end

Gset("terminal_color_0", black)
Gset("terminal_color_1", l_red)
Gset("terminal_color_2", l_purple)
Gset("terminal_color_3", l_orange)
Gset("terminal_color_4", l_cyan)
Gset("terminal_color_5", l_green)
Gset("terminal_color_6", l_yellow)
Gset("terminal_color_7", fg)
Gset("terminal_color_8", lighten_hex(black, 30))
Gset("terminal_color_9", darken_hex(l_red, 30))
Gset("terminal_color_10", darken_hex(l_purple, 30))
Gset("terminal_color_11", darken_hex(l_orange, 30))
Gset("terminal_color_12", darken_hex(l_cyan, 30))
Gset("terminal_color_13", darken_hex(l_green, 30))
Gset("terminal_color_14", darken_hex(l_yellow, 30))
Gset("terminal_color_15", darken_hex(fg, 30))

Gset("colors_name", "SimpleDelta")

Map("n", "gT", function()
    vim.api.nvim_cmd({ cmd = "Inspect" }, {})
end)

Gset("c_syntax_for_h", true)

local function darken_24bit(color, pct)
    local r = bit.band(bit.rshift(color, 16), 0xFF)
    local g = bit.band(bit.rshift(color, 8), 0xFF)
    local b = bit.band(color, 0xFF)

    r = math.max(0, math.floor(r * (1 - pct / 100)))
    g = math.max(0, math.floor(g * (1 - pct / 100)))
    b = math.max(0, math.floor(b * (1 - pct / 100)))

    return bit.bor(bit.lshift(r, 16), bit.lshift(g, 8), b)
end

SetHl(0, "stl_a", { link = "String" })
local s_fg = GetHl(0, { name = "String" }).fg
SetHl(0, "stl_b", { fg = s_fg, bg = darken_24bit(s_fg, 50) })
SetHl(0, "stl_c", { link = "Normal" })

--- @param hl_query vim.treesitter.Query
--- @return nil
local ts_nop_all = function(hl_query)
    -- Doesn't capture injections, so just sits on top of comment
    hl_query.query:disable_capture("comment.documentation")

    -- Allow to default to normal
    hl_query.query:disable_capture("punctuation.delimiter")
    hl_query.query:disable_capture("variable")
    hl_query.query:disable_capture("variable.member")

    -- Extraneous without an LSP to analyze scope
    hl_query.query:disable_capture("variable.parameter")
end

---------
-- Lua --
---------

-- Can't disable at the token level because it's the root of function globals
SetHl(0, "@lsp.type.function.lua", {})

-- MAYBE: Disable the default highlight constants and use a custom query so we aren't grabbing
-- stuff like require
Autocmd("FileType", {
    group = vim.api.nvim_create_augroup("lua-disable-captures", { clear = true }),
    pattern = "lua",
    once = true,
    callback = function()
        --- @type vim.treesitter.Query?
        local hl_query = vim.treesitter.query.get("lua", "highlights")
        if not hl_query then
            return
        end

        ts_nop_all(hl_query)

        hl_query.query:disable_capture("function") -- Confusing when functions are used as vars
        -- Don't need to distinguish function builtins
        hl_query.query:disable_capture("function.builtin")
        hl_query.query:disable_capture("module.builtin")
        hl_query.query:disable_capture("property")
        hl_query.query:disable_capture("punctuation.bracket")

        vim.api.nvim_del_augroup_by_name("lua-disable-captures")
    end,
})

local token_nop_lua = {
    "comment", -- Treesitter handles
    "method", -- Treesitter handles
    -- TODO: Check this with a class like the TSHighlighter
    "property", -- Can just be fg
} --- @type string[]

------------
-- Python --
------------

Autocmd("FileType", {
    group = vim.api.nvim_create_augroup("python-disable-captures", { clear = true }),
    pattern = "python",
    once = true,
    callback = function()
        --- @type vim.treesitter.Query?
        local hl_query = vim.treesitter.query.get("python", "highlights")
        if not hl_query then
            return
        end

        ts_nop_all(hl_query)
        hl_query.query:disable_capture("punctuation.bracket")
        hl_query.query:disable_capture("string.documentation") -- Just masks string
    end,
})

----------
-- Rust --
----------

Autocmd("FileType", {
    group = vim.api.nvim_create_augroup("rust-disable-captures", { clear = true }),
    pattern = "rust",
    once = true,
    callback = function()
        --- @type vim.treesitter.Query?
        local hl_query = vim.treesitter.query.get("rust", "highlights")
        if not hl_query then
            return
        end

        ts_nop_all(hl_query)
        -- Have to keep punctuation.bracket to mask operator highlights
        hl_query.query:disable_capture("type.builtin") -- Don't need to distinguish this

        vim.api.nvim_del_augroup_by_name("rust-disable-captures")
    end,
})

Autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("rust-disable-captures-lsp", { clear = true }),
    callback = function(ev)
        if vim.api.nvim_get_option_value("filetype", { buf = ev.buf }) ~= "rust" then
            return
        end

        --- @type vim.treesitter.Query?
        local hl_query = vim.treesitter.query.get("rust", "highlights")
        if not hl_query then
            return
        end

        -- rust_analyzer contains built-in highlights for multiple types that should be
        -- left active for doc comments. If an LSP attaches, disable the TS queries
        hl_query.query:disable_capture("constant.builtin")
        hl_query.query:disable_capture("function")
        hl_query.query:disable_capture("function.call")
        hl_query.query:disable_capture("function.macro")
        hl_query.query:disable_capture("_identifier")
        hl_query.query:disable_capture("keyword.debug")
        hl_query.query:disable_capture("keyword.exception")
        hl_query.query:disable_capture("string")
        hl_query.query:disable_capture("type")

        vim.api.nvim_del_augroup_by_name("rust-disable-captures-lsp")
    end,
})

local token_nop_rust = {
    "comment",
    "const",
    "namespace", --- Handle with custom TS queries
    "selfKeyword",
    "property", --- Default to Normal
} --- @type string[]

------------
-- vimdoc --
------------

-- I'm not sure this was actually useful
-- Run eagerly to avoid inconsistent preview window appearance
-- local vimdoc_query = vim.treesitter.query.get("vimdoc", "highlights")
-- if vimdoc_query then ts_nop_all(vimdoc_query) end

----------------------------
-- Semantic Token Removal --
----------------------------

local token_filter = {
    ["lua_ls"] = token_nop_lua,
    ["rust_analyzer"] = token_nop_rust,
} --- @type {string: string[]}

Autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("token-filter", { clear = true }),
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id) --- @type vim.lsp.Client?
        if (not client) or not client.server_capabilities.semanticTokensProvider then
            return
        end

        local found_client_name = false
        for k, _ in pairs(token_filter) do
            if k == client.name then
                found_client_name = true
                break
            end
        end

        if not found_client_name then
            return
        end

        --- @type lsp.SemanticTokensLegend
        local legend = client.server_capabilities.semanticTokensProvider.legend
        local new_tokenTypes = {} --- @type string[]

        for _, typ in ipairs(legend.tokenTypes) do
            if not vim.tbl_contains(token_filter[client.name], typ) then
                table.insert(new_tokenTypes, typ)
            else
                -- The builtin semantic token handler checks the token names for truthiness
                -- Set to false to return a falsy value and skip position calculation, without
                -- mis-aligning the legend indexing
                table.insert(new_tokenTypes, false)
            end
        end

        legend.tokenTypes = new_tokenTypes
        vim.lsp.semantic_tokens.force_refresh(ev.buf)
    end,
})

------------------------------
--- Treesitter Interaction ---
------------------------------

-- TODO: When treesitter is on, [s]s work for some buffers but not others. This feels like
-- intended behavior, but how to modify?

Map("n", "gtt", function()
    if vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] then
        vim.treesitter.stop()
    else
        vim.treesitter.start()
    end
end)

Map("n", "gti", function()
    vim.api.nvim_cmd({ cmd = "InspectTree" }, {})
end)

Map("n", "gtee", function()
    vim.api.nvim_cmd({ cmd = "EditQuery" }, {})
end)

--- @param query_group string
--- @return nil
--- Lifted from the old TS Master Branch
local function edit_query_file(query_group)
    local lang = vim.api.nvim_get_option_value("filetype", { buf = 0 })
    local files = vim.treesitter.query.get_files(lang, query_group, nil)
    if #files == 0 then
        vim.api.nvim_echo({ { "No query file found", "" } }, false, {})
        return
    elseif #files == 1 then
        require("mjm.utils").open_buf({ file = files[1] }, { open = "vsplit" })
    else
        vim.ui.select(files, { prompt = "Select a file:" }, function(file)
            if file then
                require("mjm.utils").open_buf({ file = file }, { open = "vsplit" })
            end
        end)
    end
end

Map("n", "gteo", function()
    edit_query_file("folds")
end)

Map("n", "gtei", function()
    edit_query_file("highlights")
end)

Map("n", "gten", function()
    edit_query_file("indents")
end)

Map("n", "gtej", function()
    edit_query_file("injections")
end)

Map("n", "gtex", function()
    edit_query_file("textobjects")
end)

---------------------------------------------------
-- Various utils lifted from Fluoromachine.nvim --
---------------------------------------------------

-- function M.decimal_to_hash(decimal_value)
--     local hex_value = string.format("%x", decimal_value)
--     hex_value = string.format("%06s", hex_value)
--
--     return hex_value
-- end

-- local function hex_to_rgb(hex)
--     -- Remove the "#" character if present
--     hex = hex:gsub("#", "")
--
--     -- Split the hex code into separate red, green, and blue components
--     local r = tonumber(hex:sub(1, 2), 16)
--     local g = tonumber(hex:sub(3, 4), 16)
--     local b = tonumber(hex:sub(5, 6), 16)
--
--     -- Return the color values as three separate integers
--     return { r, g, b }
-- end

-- local function rgb_to_hex(red, green, blue)
--     return string.format("#%02X%02X%02X", red, green, blue)
-- end

-------------------
--- Diagnostics ---
-------------------

local diag_main_cfg = {
    float = { source = true, border = Border },
    severity_sort = true,
} ---@type table

local virt_text_cfg = {
    virtual_lines = false,
    virtual_text = {
        current_line = true,
    },
} ---@type table

local virt_lines_cfg = {
    virtual_lines = { current_line = true },
    virtual_text = false,
} ---@type table

local diag_text_cfg = vim.tbl_extend("force", diag_main_cfg, virt_text_cfg)
local diag_lines_cfg = vim.tbl_extend("force", diag_main_cfg, virt_lines_cfg)
vim.diagnostic.config(diag_text_cfg)

ApiMap("n", "\\d", "<nop>", {
    noremap = true,
    callback = function()
        vim.diagnostic.enable(not vim.diagnostic.is_enabled())
    end,
})

-- TODO: map to show err only or top severity only
-- TODO: map to show config status. should apply to other \ maps as well
Map("n", "\\D", function()
    local cur_cfg = vim.diagnostic.config() or {}
    vim.diagnostic.config((not cur_cfg.virtual_lines) and diag_lines_cfg or diag_text_cfg)
end)

local function on_bufreadpre()
    -- TODO: Is it possible to get out of the current top_severity function? The problem is it
    -- doesn't actually save us a diagnostic_get in this case

    Map("n", "[<C-d>", function()
        vim.diagnostic.jump({
            count = -vim.v.count1,
            severity = require("mjm.utils").get_top_severity({ buf = 0 }),
        })
    end)

    Map("n", "]<C-d>", function()
        vim.diagnostic.jump({
            count = vim.v.count1,
            severity = require("mjm.utils").get_top_severity({ buf = 0 }),
        })
    end)

    -- For whatever reason, [D/]D on my computer cause Neovim to lock up. Even when just using
    -- large numbers for count, they don't reliably find the top and bottom diag. Instead, just
    -- search for the first/last diag manually and jump to it
    local function get_first_or_last_diag(opts)
        opts = opts or {}
        local diagnostics = opts.severity and vim.diagnostic.get(0, { severity = opts.severity })
            or vim.diagnostic.get(0)

        if #diagnostics == 0 then
            vim.api.nvim_echo({ { "No diagnostics in current buffer", "" } }, false, {})
            return
        end

        table.sort(diagnostics, function(a, b)
            if a.lnum ~= b.lnum then
                return a.lnum < b.lnum
            elseif a.severity ~= b.severity then
                return a.severity < b.severity
            elseif a.end_lnum ~= b.end_lnum then
                return a.end_lnum < b.end_lnum
            elseif a.col ~= b.col then
                return a.col < b.col
            else
                return a.end_col < b.end_col
            end
        end)

        return opts.last and diagnostics[#diagnostics] or diagnostics[1]
    end

    Map("n", "[D", function()
        local diagnostic = get_first_or_last_diag()
        if diagnostic then
            vim.diagnostic.jump({
                diagnostic = diagnostic,
            })
        end
    end)

    Map("n", "]D", function()
        local diagnostic = get_first_or_last_diag({ last = true })
        if diagnostic then
            vim.diagnostic.jump({
                diagnostic = diagnostic,
            })
        end
    end)

    -- TODO: Potentially better case for using the updated severity filtering

    Map("n", "[<M-d>", function()
        local severity = require("mjm.utils").get_top_severity({ buf = 0 })
        local diagnostic = get_first_or_last_diag({ severity = severity })
        if diagnostic then
            vim.diagnostic.jump({
                diagnostic = diagnostic,
            })
        end
    end)

    Map("n", "]<M-d>", function()
        local severity = require("mjm.utils").get_top_severity({ buf = 0 })
        local diagnostic = get_first_or_last_diag({ severity = severity, last = true })
        if diagnostic then
            vim.diagnostic.jump({
                diagnostic = diagnostic,
            })
        end
    end)
end

Autocmd({ "BufReadPre", "BufNewFile" }, {
    group = Augroup("diag-keymap-setup", { clear = true }),
    once = true,
    callback = function()
        on_bufreadpre()
        vim.api.nvim_del_augroup_by_name("diag-keymap-setup")
    end,
})

-----------------
--- LSP Setup ---
-----------------

-- TODO: Consider getting a C lsp for reading code. I think clang is the one everyone uses

-- LOW: Weird Issue where workspace update is triggered due to FzfLua require, and Semantic
-- Tokens do not consistently refresh afterwards

vim.lsp.log.set_level(vim.log.levels.ERROR)

-- No need to map these in non-LSP buffers
-- TODO: mini.operators has a check to see if certain maps exist before deleting them
vim.keymap.del("n", "grn")
vim.keymap.del("n", "gra")
vim.keymap.del("n", "grr")
vim.keymap.del("n", "gri")
vim.keymap.del("n", "grt")
vim.keymap.del("n", "gO")
vim.keymap.del("i", "<C-S>")

-------------------------
-- Compute LSP Keymaps --
-------------------------

-- TODO: Figure out how to open FzfLua outputs in a vsplit

local ok, fzflua = pcall(require, "fzf-lua") --- @type boolean, table
local no_fzflua = function()
    vim.api.nvim_echo({ { "FzfLua not available", "" } }, true, {})
end

--- callHierarchy/incomingCalls ---
local in_call = ok and function()
    fzflua.lsp_incoming_calls({ jump1 = false })
end or vim.lsp.buf.incoming_calls

--- callHierarchy/outgoingCalls ---
local out_call = ok and function()
    fzflua.lsp_incoming_calls({ jump1 = false })
end or vim.lsp.buf.outgoing_calls

--- textDocument/codeAction ---
local code_action = ok and fzflua.lsp_code_actions or vim.lsp.buf.code_action

--- textDocument/declaration ---
local declaration = ok and fzflua.lsp_declarations or vim.lsp.buf.declaration
local peek_declaration = ok
        and function()
            fzflua.lsp_declarations({ jump1 = false })
        end
    or no_fzflua

--- textDocument/definition ---
local definition = ok and fzflua.lsp_definitions or vim.lsp.buf.definition
local peek_definition = ok and function()
    fzflua.lsp_definitions({ jump1 = false })
end or no_fzflua

--- textDocument/documentSymbol ---
local symbols = ok and fzflua.lsp_document_symbols or vim.lsp.buf.document_symbol

--- textDocument/implementation ---
local implementation = ok and fzflua.lsp_implementations or vim.lsp.buf.implementation
local peek_implementation = ok
        and function()
            fzflua.lsp_implementations({ jump1 = false })
        end
    or no_fzflua

--- textDocument/references ---
local references = ok
        and function()
            fzflua.lsp_references({ includeDeclaration = false })
        end
    or function()
        vim.lsp.buf.references({ includeDeclaration = false })
    end

local peek_references = ok
        and function()
            fzflua.lsp_references({ includeDeclaration = false, jump1 = false })
        end
    or no_fzflua

--- textDocument/typeDefinition ---
local typedef = ok and fzflua.lsp_typedefs or vim.lsp.buf.type_definition
local peek_typedef = ok and function()
    fzflua.lsp_typedefs({ jump1 = false })
end or no_fzflua

--- workspace/symbol ---
local workspace = ok and fzflua.lsp_live_workspace_symbols or vim.lsp.buf.workspace_symbol

local function on_lsp_attach(ev)
    if not ev.data.client_id then
        return
    end

    local client = vim.lsp.get_client_by_id(ev.data.client_id) --- @type vim.lsp.Client?
    if not client then
        return
    end

    local buf = ev.buf ---@type integer
    Map("n", "gr", "<nop>", { buffer = buf })

    -- MAYBE: Depending on how these are used, you could put incoming and outgoing calls on
    -- separate mappings and use the capitals for jump1 = false
    --- callHierarchy/incomingCalls ---
    Map("n", "grc", in_call, { buffer = buf })
    --- callHierarchy/outgoingCalls ---
    Map("n", "grC", out_call, { buffer = buf })
    --- textDocument/codeAction ---
    Map("n", "gra", code_action, { buffer = buf })
    --- textDocument/codeLens ---
    if client:supports_method("textDocument/codeLens") then
        -- Lens updates are throttled so only one runs at a time. Updating on text change
        -- increases the likelihood of lenses rendering with stale data
        vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
            buffer = ev.buf,
            group = vim.api.nvim_create_augroup("refresh-lens", { clear = true }),
            -- Bespoke module so I can render the lenses as virtual lines
            callback = function()
                require("mjm.codelens").refresh({ buf = ev.buf })
            end,
        })
    end

    -- Use bespoke module because the lenses are cached there
    Map("n", "grs", require("mjm.codelens").run)
    --- textDocument/declaration ---
    Map("n", "grd", declaration, { buffer = buf })
    if client:supports_method("textDocument/declaration") then
        Map("n", "grD", peek_declaration)
    else
        Map("n", "grD", function()
            local msg = "LSP Server does not have capability textDocument/declaration"
            vim.api.nvim_echo({ { msg, "" } }, true, {})
        end)
    end

    --- textDocument/definition ---
    if client:supports_method("textDocument/definition") then
        Map("n", "gd", definition, { buffer = buf })
        Map("n", "gD", peek_definition)
    else
        Map("n", "gD", function()
            local msg = "LSP Server does not have capability textDocument/definition"
            vim.api.nvim_echo({ { msg, "" } }, true, {})
        end)
    end

    --- textDocument/documentColor ---
    Map("n", "gro", function()
        vim.lsp.document_color.enable(not vim.lsp.document_color.is_enabled())
    end, { buffer = buf })

    Map("n", "grO", vim.lsp.document_color.color_presentation, { buffer = buf })
    --- textDocument/documentHighlight ---
    Map("n", "grh", vim.lsp.buf.document_highlight, { buffer = buf })
    --- textDocument/documentSymbol ---
    Map("n", "gO", symbols, { buffer = buf })
    --- textDocument/hover ---
    Map("n", "K", function()
        vim.lsp.buf.hover({ border = Border })
    end, { buffer = buf })

    --- textDocument/implementation ---
    Map("n", "gri", implementation)
    if client:supports_method("textDocument/implementation") and ok then
        Map("n", "grI", peek_implementation, { buffer = buf })
    else
        Map("n", "grI", function()
            local msg = "LSP Server does not have capability textDocument/implementation"
            vim.api.nvim_echo({ { msg, "" } }, true, {})
        end)
    end

    --- textDocument/inlayHint ---
    Map("n", "grl", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ buffer = buf }))
    end)

    -- textDocument/linkedEditingRange
    -- FUTURE: The docs recommend trying this with html
    -- if client:supports_method("textDocument/linkedEditingRange") then
    --     vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
    -- end

    --- textDocument/references ---
    Map("n", "grr", references, { buffer = buf })
    if client:supports_method("textDocument/references") and ok then
        Map("n", "grR", peek_references, { buffer = buf })
    else
        Map("n", "grR", function()
            local msg = "LSP Server does not have capability textDocument/references"
            vim.api.nvim_echo({ { msg, "" } }, true, {})
        end)
    end

    --- textDocument/rename ---
    Map("n", "grn", function()
        -- LOW: The plugin I'm aware of that does incremental rename is a re-implementation of
        -- the renaming functionality. Don't want to do that. Would want to make something that
        -- gets the rename first then passes to the built-in

        --- @type boolean, string
        local ok_i, input = require("mjm.utils").get_input("Rename: ")
        if not ok_i then
            local msg = input or "Unknown error getting input" --- @type string
            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        elseif #input < 1 then
            return
        elseif string.find(input, "%s") then
            local msg = string.format("'%s' contains spaces", input)
            vim.api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
            return
        end

        vim.lsp.buf.rename(input)
    end, { buffer = buf })

    ApiMap("n", "grN", "<nop>", { noremap = true, callback = vim.lsp.buf.rename })

    --- textDocument/signatureHelp ---
    Map({ "i", "s" }, "<C-S>", function()
        vim.lsp.buf.signature_help({ border = Border })
    end, { buffer = buf })

    --- textDocument/typeDefinition ---
    Map("n", "grt", typedef, { buffer = buf })
    if client:supports_method("textDocument/typeDefinition") and ok then
        Map("n", "grT", peek_typedef, { buffer = buf })
    else
        local msg = "LSP Server does not have capability textDocument/typeDefinition"
        Map("n", "grT", function()
            vim.api.nvim_echo({ { msg, "" } }, true, {})
        end)
    end

    --- workspace/symbol ---
    -- Kickstart mapping
    -- TODO: Think about this one. If we did grw, that gives us grw and grW. kickstart is the
    -- only place I've seen this. Not that widespread?
    Map("n", "gW", workspace, { buffer = buf })

    --- Other ---
    --- LOW: Figure out which method this is behind
    Map("n", "grm", function()
        vim.lsp.semantic_tokens.enable(not vim.lsp.semantic_tokens.is_enabled())
    end, { buffer = buf })

    Map("n", "grf", function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, { buffer = buf })
end

local lsp_group = vim.api.nvim_create_augroup("LSP_Augroup", { clear = true })
Autocmd("LspAttach", {
    group = lsp_group,
    callback = function(ev)
        on_lsp_attach(ev)
    end,
})

Autocmd("LspDetach", {
    group = lsp_group,
    callback = function(ev)
        local buf = ev.buf ---@type integer
        local clients = vim.lsp.get_clients({ bufnr = buf }) ---@type vim.lsp.Client[]
        if not clients or vim.tbl_isempty(clients) then
            return
        end

        for _, client in pairs(clients) do
            local attached_bufs = vim.tbl_filter(function(buf_nbr)
                return buf_nbr ~= buf
            end, vim.tbl_keys(client.attached_buffers)) ---@type unknown[]

            if vim.tbl_isempty(attached_bufs) then
                vim.schedule(function()
                    vim.lsp.stop_client(client.id)
                end)
            end
        end
    end,
})

-- Configs are in after/lsp
vim.lsp.enable({
    --- Bash --
    "bashls",
    --- Go ---
    "golangci_lint_ls",
    "gopls",
    --- HTML/CSS ---
    "cssls",
    "html",
    --- Lua ---
    -- FUTURE: This might be the way
    -- https://old.reddit.com/r/neovim/comments/1mdtr4g/emmylua_ls_is_supersnappy/
    "lua_ls",
    --- Python ---
    -- Ruff is not feature-complete enough to replace pylsp
    "pylsp",
    "ruff",
    --- Rust ---
    "rust_analyzer",
    --- Toml ---
    "taplo",
})

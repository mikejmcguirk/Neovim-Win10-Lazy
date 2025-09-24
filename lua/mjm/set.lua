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

------------------
--- Cursorline ---
------------------

SetOpt("cul", true, global_scope)
Autocmd("WinEnter", {
    group = set_group,
    callback = function()
        SetOpt("cul", true, { win = vim.api.nvim_get_current_win() })
    end,
})

Autocmd("WinLeave", {
    group = set_group,
    callback = function()
        SetOpt("cul", false, { win = vim.api.nvim_get_current_win() })
    end,
})

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
Autocmd("InsertEnter", {
    group = set_group,
    callback = function()
        SetOpt("list", false, { win = vim.api.nvim_get_current_win() })
    end,
})

Autocmd("InsertLeave", {
    group = set_group,
    callback = function()
        SetOpt("list", true, { win = vim.api.nvim_get_current_win() })
    end,
})

------------------
--- Numberline ---
------------------

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
SetOpt("nu", true, global_scope)
SetOpt("rnu", true, global_scope)
SetOpt("cc", "100", global_scope)
SetOpt("nuw", 5, global_scope)
SetOpt("scl", "yes:1", global_scope)

---@param event string|string[]
---@param pattern string
---@param value boolean
---@return nil
local set_rnu = function(event, pattern, value)
    Autocmd(event, {
        group = set_group,
        pattern = pattern,
        callback = function()
            SetOpt("rnu", value, { win = vim.api.nvim_get_current_win() })
        end,
    })
end

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
-- Note: Need BufLeave/BufEnter for this to work when going into help
set_rnu({ "WinLeave", "BufLeave" }, "*", false)
set_rnu({ "WinEnter", "CmdlineLeave", "BufEnter" }, "*", true)

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

-- NOTE: This is a bespoke version of Fluoromachine.nvim's delta theme

local c = {
    -- https://www.sessions.edu/color-calculator/
    black = "#000000",

    fg = "#EFEFFD",

    l_cyan = "#98FFFB",
    cyan = "#558396",

    l_green = "#C0FF98",
    green = "#579964",

    l_orange = "#FFD298",
    orange = "#967A55",
    orange_fg = "#FFF0E0",

    l_pink = "#FF67D4",
    pink = "#613852",

    l_purple = "#D598FF",
    purple = "#925393",
    bold_purple = "#492949",
    d_purple = "#251d2b",
    d_purple_two = "#2b2233",
    d_purple_three = "#18131c", -- Darkened from dark purple

    l_red = "#FF98B3",

    l_yellow = "#EDFF98",
} --- @type {string: string}

--- @type {string: vim.api.keyset.highlight}
local groups = {

    ----------------------------
    -- Diagnostics and Status --
    ----------------------------

    DiagnosticError = { fg = c.l_red },
    DiagnosticWarn = { fg = c.l_orange },
    DiagnosticInfo = { fg = c.l_green },
    DiagnosticHint = { fg = c.l_cyan },
    DiagnosticUnnecessary = { underdashed = true }, -- Default link: Comment

    -- Can't link and add info, so just manually set
    DiagnosticUnderlineError = { fg = c.l_red, underline = true },
    DiagnosticUnderlineWarn = { fg = c.l_orange, underline = true },
    DiagnosticUnderlineInfo = { fg = c.l_green, underline = true },
    DiagnosticUnderlineHint = { fg = c.l_cyan, underline = true },

    -- Same here
    DiffAdd = { fg = c.black, bg = c.l_green },
    DiffChange = { fg = c.black, bg = c.l_orange },
    DiffDelete = { fg = c.black, bg = c.l_red },

    Added = { link = "DiagnosticInfo" }, -- (Default self-definition)
    Changed = { link = "DiagnosticWarn" }, -- (Default self-definition)
    Removed = { link = "DiagnosticError" }, -- (Default self-definition)

    Error = { link = "DiagnosticError" }, --- (Default self-definition)
    ErrorMsg = { link = "DiagnosticError" }, --- (Default self-definition)
    WarningMsg = { link = "DiagnosticWarn" }, -- (Default self-definition)
    MoreMsg = { link = "DiagnosticInfo" }, -- (Default self-definition)
    Question = { link = "DiagnosticInfo" }, -- (Default self-definition)

    SpellBad = { link = "DiagnosticError" }, -- (Default self-definition)
    SpellLocal = { link = "DiagnosticWarn" }, -- (Default self-definition)
    SpellCap = { link = "DiagnosticInfo" }, -- (Default self-definition)
    SpellRare = { link = "DiagnosticHint" }, -- (Default self-definition)

    ---------------
    -- Normal/Fg --
    ---------------

    Normal = { fg = c.fg },

    Delimiter = {},
    Identifier = {},
    NormalFloat = {}, -- Default self-definition
    NormalNC = {}, -- Causes performance issues (default setting)

    ["@variable"] = {}, --- Default self-definition

    --------------------
    --- Special Text ---
    --------------------

    Comment = { fg = c.purple, italic = true },
    Conceal = { link = "Comment" }, -- (Default self-definition)

    LspCodeLens = { fg = c.cyan },

    NonText = { fg = c.pink },
    SpecialKey = { link = "NonText" }, --- Default self-definition

    Folded = { fg = c.purple, bg = c.bold_purple },

    LspInlayHint = { fg = c.green, italic = true },

    EndOfBuffer = {}, -- (Default link: Non-text)

    ----------------------------------
    --- Builtins/Constants/Globals ---
    ----------------------------------

    --- LOW: The "self" keyword should be italicized since it is an alias for the current object

    Constant = { fg = c.l_red },

    ["@constant.builtin"] = { link = "Constant" }, -- No default
    ["@variable.builtin"] = { link = "Constant" }, -- No default

    ["@lsp.typemod.function.global"] = { link = "Constant" }, -- Default @lsp
    ["@lsp.typemod.variable.defaultLibrary"] = { link = "Constant" }, -- Default @lsp
    ["@lsp.typemod.variable.global"] = { link = "Constant" }, -- Default @lsp

    -----------------
    --- Functions ---
    -----------------

    Function = { fg = c.l_yellow },

    ["@function.builtin"] = { link = "Function" }, -- Default link to Special

    --------------------------------------
    --- Numbers/Booleans/Chars/Modules ---
    --------------------------------------

    Number = { fg = c.l_cyan }, -- (Default link: Constant)

    Boolean = { link = "Number" }, -- (Default link: Constant)
    Character = { link = "Number" }, -- (Default link: Constant)

    ["@module"] = { link = "Number" }, -- (Default link: Type)

    ["@lsp.type.namespace"] = { link = "Number" }, -- (Default link: Type)
    ["@lsp.typemod.boolean.injected"] = { link = "Boolean" }, -- Default @lsp

    ["@lsp.type.enumMember"] = { fg = c.l_cyan, italic = true }, -- (Default link: Type)

    -------------------------------------------
    --- Operators/PreProc/Statement/Special ---
    -------------------------------------------

    Operator = { fg = c.l_pink },

    ["@lsp.typemod.arithmetic.injected"] = { link = "Operator" }, --- Default link @lsp
    ["@lsp.typemod.comparison.injected"] = { link = "Operator" }, --- Default link @lsp

    PreProc = { fg = c.l_pink, italic = true },

    ["@function.macro"] = { link = "PreProc" }, -- Default link: Function
    ["@preproc"] = { link = "PreProc" }, -- Custom TS Query

    ["@lsp.type.macro"] = { link = "PreProc" }, -- (Default link: Constant)
    ["@lsp.typemod.derive.macro"] = { link = "PreProc" }, -- (Default link: @lsp)
    ["@lsp.typemod.lifetime.injected"] = { link = "PreProc" }, -- (Default link: @lsp)

    Special = { fg = c.l_pink },

    ["@lsp.typemod.attributeBracket.injected"] = { link = "Special" }, --- Default link @lsp

    Statement = { fg = c.l_pink },

    ------------------
    --- Parameters ---
    ------------------

    ["@variable.parameter"] = { link = "@lsp.type.parameter" },

    ["@lsp.type.parameter"] = { fg = c.l_orange }, -- Default link: Identifier

    --------------
    --- String ---
    --------------

    String = { fg = c.l_purple },

    ["@string.escape"] = { fg = c.l_purple, italic = true },

    ["@lsp.type.formatSpecifier"] = { link = "@string.escape" },

    -------------
    --- Types ---
    -------------

    Type = { fg = c.l_green },

    ["@type.builtin"] = { link = "Type" }, -- Default link Special

    ["@lsp.type.builtinType"] = { link = "Type" }, -- Default link @lsp

    ["@lsp.type.typeAlias"] = { fg = c.l_green, italic = true },

    ["@lsp.type.selfTypeKeyword"] = { link = "@lsp.type.typeAlias" }, -- Default link @lsp

    ----------
    --- UI ---
    ----------

    CurSearch = { fg = c.black, bg = c.l_orange },
    IncSearch = { fg = c.l_green },
    Search = { fg = c.orange_fg, bg = c.orange },

    QuickFixLine = { bg = c.bold_purple },

    Visual = { bg = c.bold_purple },

    CursorLineNr = { fg = c.l_green },
    Directory = { fg = c.l_green },
    LineNr = { fg = c.purple }, -- rnu
    Title = { fg = c.l_green },
    Todo = { fg = c.l_green },

    MatchParen = { underline = true },

    Pmenu = { fg = c.fg },
    PmenuSel = { bg = c.bold_purple },
    PmenuThumb = { bg = c.l_cyan },

    ColorColumn = { bg = c.d_purple },
    CursorLine = { link = "ColorColumn" }, -- (Default self-definition)
    CursorColumn = { link = "ColorColumn" }, -- (Default self-definition)

    WinSeparator = { fg = c.purple }, -- (Default link: Normal)
    FloatBorder = { link = "WinSeparator" }, -- (Default link: NormalFloat)

    StatusLine = { fg = c.fg, bg = c.d_purple_three },
    StatusLineNC = { link = "StatusLine" }, -- (Default self-definition)
    Tabline = { link = "StatusLine" }, -- (Default self-definition)

    Cursor = {}, --- (Default self-definition. I have reverse video cursor set in the terminal)
    lCursor = {}, --- (Default self-definition. I have reverse video cursor set in the terminal)
    SignColumn = {}, -- Default self-definition

    --------------
    --- Markup ---
    --------------

    -- LOW: Lifted from Fluoromachine because they look familiar, but I've put no thought into
    -- the actual reasoning behind these
    ["@markup.environment"] = { fg = c.l_purple },
    ["@markup.heading"] = { link = "Title" },
    ["@markup.italic"] = { fg = c.l_green, italic = true },
    ["@markup.link"] = { fg = c.l_cyan },
    ["@markup.link.label"] = { fg = c.l_cyan },
    ["@markup.link.url"] = { fg = c.purple },
    ["@markup.list"] = { fg = c.l_pink },
    ["@markup.list.checked"] = { fg = c.l_green },
    ["@markup.math"] = { link = "Operator" },
    ["@markup.quote"] = { link = "Comment" },
    ["@markup.raw"] = { link = "Comment" },
    ["@markup.raw.block"] = { link = "Comment" },
    ["@markup.strikethrough"] = { fg = c.l_yellow, strikethrough = true },
    ["@markup.strong"] = { fg = c.l_green, bold = true },
    ["@markup.underline"] = { link = "Underlined" },
}

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

Cmd({ cmd = "hi", args = { "clear" } }, {})
if vim.fn.exists("syntax_on") then
    Cmd({ cmd = "syntax", args = { "reset" } }, {})
end

for k, v in pairs(groups) do
    vim.api.nvim_set_hl(0, k, v)
end

Gset("terminal_color_0", c.black)
Gset("terminal_color_1", c.l_red)
Gset("terminal_color_2", c.l_purple)
Gset("terminal_color_3", c.l_orange)
Gset("terminal_color_4", c.l_cyan)
Gset("terminal_color_5", c.l_green)
Gset("terminal_color_6", c.l_yellow)
Gset("terminal_color_7", c.fg)

Gset("terminal_color_8", lighten_hex(c.black, 30))
Gset("terminal_color_9", darken_hex(c.l_red, 30))
Gset("terminal_color_10", darken_hex(c.l_purple, 30))
Gset("terminal_color_11", darken_hex(c.l_orange, 30))
Gset("terminal_color_12", darken_hex(c.l_cyan, 30))
Gset("terminal_color_13", darken_hex(c.l_green, 30))
Gset("terminal_color_14", darken_hex(c.l_yellow, 30))
Gset("terminal_color_15", darken_hex(c.fg, 30))

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

-- Post-calculating this is a bit dumb, but if I need to turn off the colorscheme for testing, I
-- can just comment out the set calls and let this run without breaking the stl
local s_fg = vim.api.nvim_get_hl(0, { name = "String" }).fg
local bg = vim.api.nvim_get_hl(0, { name = "NonText" }).bg
vim.api.nvim_set_hl(0, "stl_a", { fg = s_fg, bg = bg })
vim.api.nvim_set_hl(0, "stl_b", { fg = s_fg, bg = darken_24bit(s_fg, 50) })
vim.api.nvim_set_hl(0, "stl_c", { fg = vim.api.nvim_get_hl(0, { name = "Normal" }).fg, bg = bg })

local hl_nop_all = {
    -- Irrelevant without the LSP to determine scope
    ["@variable.parameter"] = {},
    -- Can't eliminate at the token level because builtins and globals depend on it
    ["@lsp.type.variable"] = {}, --- Default link to normal
} --- @type {string: vim.api.keyset.highlight}

for k, v in pairs(hl_nop_all) do
    vim.api.nvim_set_hl(0, k, v)
end

--- @param hl_query vim.treesitter.Query
--- @return nil
local ts_nop_all = function(hl_query)
    -- Doesn't capture injections, so just sits on top of comment
    hl_query.query:disable_capture("comment.documentation")

    -- Allow to default to normal
    hl_query.query:disable_capture("punctuation.delimiter")
    hl_query.query:disable_capture("variable")
    hl_query.query:disable_capture("variable.member")

    -- Without the LSP to analyze scope, this hl_group does not add value
    hl_query.query:disable_capture("variable.parameter")
end

---------
-- Lua --
---------

local hl_nop_lua = {
    -- Can't disable at the token level because it's the root of function globals
    ["@lsp.type.function.lua"] = {}, -- Default link to function
} --- @type {string: vim.api.keyset.highlight}

for k, v in pairs(hl_nop_lua) do
    vim.api.nvim_set_hl(0, k, v)
end

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

        -- Have to keep punctuation.bracket to mask operator highlights
        hl_query.query:disable_capture("type.builtin") -- Don't need to distinguish this
    end,
})

Autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("rust-disable-captures-lsp", { clear = true }),
    callback = function(ev)
        if not vim.api.nvim_get_option_value("filetype", { buf = ev.buf }) == "rust" then
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

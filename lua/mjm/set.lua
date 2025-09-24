-- SSH clipboard config
-- https://github.com/tjdevries/config.nvim/blob/master/plugin/clipboard.lua
-- vim.g.deprecation_warnings = true -- Pre-silence deprecation warnings

-----------------------
-- Internal Behavior --
-----------------------

-- Override \r\n on Windows
vim.api.nvim_set_option_value("fileformats", "unix,dos", { scope = "global" })
vim.opt.jumpoptions:append("view")

vim.api.nvim_set_option_value("backup", false, { scope = "global" })
vim.api.nvim_set_option_value("writebackup", false, { scope = "global" })
vim.api.nvim_set_option_value("swapfile", false, { scope = "global" })
vim.api.nvim_set_option_value("undofile", true, { scope = "global" })
vim.api.nvim_set_option_value("updatetime", 300, { scope = "global" })

-- :h 'sd'
local shada = [[<0,'100,/0,:1000,h]]
vim.api.nvim_set_option_value("shada", shada, { scope = "global" })

--------
-- UI --
--------

vim.api.nvim_set_var("no_plugin_maps", 1)

vim.api.nvim_set_option_value("tabstop", 4, { scope = "global" })
vim.api.nvim_set_option_value("softtabstop", 4, { scope = "global" })
vim.api.nvim_set_option_value("shiftwidth", 4, { scope = "global" })
vim.api.nvim_set_option_value("expandtab", true, { scope = "global" })
vim.api.nvim_set_option_value("shiftround", true, { scope = "global" })

vim.api.nvim_set_option_value("backspace", "indent,eol,nostop", { scope = "global" })

vim.opt.cpoptions:append("W") -- Don't overwrite readonly files
vim.opt.cpoptions:append("Z") -- Don't reset readonly with w!

vim.api.nvim_set_option_value("ignorecase", true, { scope = "global" })
vim.api.nvim_set_option_value("smartcase", true, { scope = "global" })
-- Don't want screen shifting while entering search/subsitute patterns
vim.api.nvim_set_option_value("incsearch", false, { scope = "global" })

vim.opt.matchpairs:append("<:>")

vim.api.nvim_set_option_value("mouse", "", { scope = "global" })

vim.api.nvim_set_option_value("modelines", 1, { scope = "global" })

vim.api.nvim_set_option_value("selection", "old", { scope = "global" })
vim.api.nvim_set_option_value("so", Scrolloff_Val, { scope = "global" })

vim.api.nvim_set_option_value("splitbelow", true, { scope = "global" })
vim.api.nvim_set_option_value("splitright", true, { scope = "global" })
-- For some reason, uselast needs to be manually set globally
vim.api.nvim_set_option_value("switchbuf", "useopen,uselast", { scope = "global" })

---------------------
-- Buffer Behavior --
---------------------

-- https://github.com/neovim/neovim/pull/35536
-- https://github.com/neovim/neovim/issues/35575
-- Issue is better after this pull request, but not resolve. In this file I can see some
-- global scope settings still whited out.
-- TODO: Test this again with a minimal config
-- vim.api.nvim_set_option_value("wrap", false, { scope = "global" })
-- For fts where opt_local wrap is true
vim.api.nvim_set_option_value("breakindent", true, { scope = "global" })
vim.api.nvim_set_option_value("linebreak", true, { scope = "global" })
vim.api.nvim_set_option_value("smartindent", true, { scope = "global" })

local dict = vim.fn.expand("~/.local/bin/words/words_alpha.txt")
vim.api.nvim_set_option_value("dictionary", dict, { scope = "global" })
vim.api.nvim_set_option_value("spell", false, { scope = "global" })
vim.api.nvim_set_option_value("spelllang", "en_us", { scope = "global" })

----------------
-- Aesthetics --
----------------

vim.opt.fillchars:append({ eob = " " })

local blink_setting = "blinkon1-blinkoff1"
local norm_cursor = "n:block" .. blink_setting
local ver_cursor = "i-sm-c-ci-t:ver100-" .. blink_setting
local hor_cursor = "o-v-ve-r-cr:hor100-" .. blink_setting
local gcr = norm_cursor .. "," .. ver_cursor .. "," .. hor_cursor
vim.api.nvim_set_option_value("guicursor", gcr, { scope = "global" })

vim.api.nvim_set_option_value("list", true, { scope = "global" })
local listchars = "tab:<->,extends:»,precedes:«,nbsp:␣,trail:⣿"
vim.api.nvim_set_option_value("listchars", listchars, { scope = "global" })

-- On my monitors, for files under 10k lines, a centered vsplit will be on the color column
vim.api.nvim_set_option_value("nu", true, { scope = "global" })
vim.api.nvim_set_option_value("rnu", true, { scope = "global" })
vim.api.nvim_set_option_value("cc", "100", { scope = "global" })
vim.api.nvim_set_option_value("nuw", 5, { scope = "global" })
vim.api.nvim_set_option_value("scl", "yes:1", { scope = "global" })

vim.api.nvim_set_option_value("cursorline", true, { scope = "global" })

vim.opt.shortmess:append("a") --- Abbreviations
vim.opt.shortmess:append("s") --- No search hit top/bottom messages
vim.opt.shortmess:append("I") --- No intro message
vim.opt.shortmess:append("W") --- No "written" notifications

vim.api.nvim_set_option_value("ruler", false, { scope = "global" })

vim.filetype.add({ filename = { [".bashrc_custom"] = "sh" } })

----------------------
-- Autocmd Controls --
----------------------

local set_group = vim.api.nvim_create_augroup("set-group", { clear = true })

vim.api.nvim_create_autocmd("BufWinEnter", {
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

-- See help fo-table
-- Since multiple runtime ftplugin files set formatoptions, correct here
vim.api.nvim_create_autocmd({ "FileType" }, {
    group = set_group,
    pattern = "*",
    callback = function()
        vim.opt.formatoptions:remove("o")
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
        vim.cmd.nohlsearch()
    end),
})

vim.api.nvim_create_autocmd("WinEnter", {
    group = set_group,
    callback = function()
        vim.api.nvim_set_option_value("cul", true, { win = vim.api.nvim_get_current_win() })
    end,
})

vim.api.nvim_create_autocmd("WinLeave", {
    group = set_group,
    callback = function()
        vim.api.nvim_set_option_value("cul", false, { win = vim.api.nvim_get_current_win() })
    end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
    group = set_group,
    callback = function()
        vim.api.nvim_set_option_value("list", false, { win = vim.api.nvim_get_current_win() })
    end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
    group = set_group,
    callback = function()
        vim.api.nvim_set_option_value("list", true, { win = vim.api.nvim_get_current_win() })
    end,
})

---@param event string|string[]
---@param pattern string
---@param value boolean
---@return nil
local set_rnu = function(event, pattern, value)
    vim.api.nvim_create_autocmd(event, {
        group = set_group,
        pattern = pattern,
        callback = function()
            vim.api.nvim_set_option_value("rnu", value, { win = vim.api.nvim_get_current_win() })
        end,
    })
end

vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = set_group,
    callback = function()
        vim.api.nvim_set_option_value("rnu", false, { win = vim.api.nvim_get_current_win() })
        if not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype) then
            vim.cmd("redraw")
        end
    end,
})

-- Note: Need BufLeave/BufEnter for this to work when going into help
set_rnu({ "WinLeave", "BufLeave" }, "*", false)
set_rnu({ "WinEnter", "CmdlineLeave", "BufEnter" }, "*", true)

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

vim.api.nvim_set_var("terminal_color_0", c.black)
vim.api.nvim_set_var("terminal_color_1", c.l_red)
vim.api.nvim_set_var("terminal_color_2", c.l_purple)
vim.api.nvim_set_var("terminal_color_3", c.l_orange)
vim.api.nvim_set_var("terminal_color_4", c.l_cyan)
vim.api.nvim_set_var("terminal_color_5", c.l_green)
vim.api.nvim_set_var("terminal_color_6", c.l_yellow)
vim.api.nvim_set_var("terminal_color_7", c.fg)

vim.api.nvim_set_var("terminal_color_8", lighten_hex(c.black, 30))
vim.api.nvim_set_var("terminal_color_9", darken_hex(c.l_red, 30))
vim.api.nvim_set_var("terminal_color_10", darken_hex(c.l_purple, 30))
vim.api.nvim_set_var("terminal_color_11", darken_hex(c.l_orange, 30))
vim.api.nvim_set_var("terminal_color_12", darken_hex(c.l_cyan, 30))
vim.api.nvim_set_var("terminal_color_13", darken_hex(c.l_green, 30))
vim.api.nvim_set_var("terminal_color_14", darken_hex(c.l_yellow, 30))
vim.api.nvim_set_var("terminal_color_15", darken_hex(c.fg, 30))

vim.g.colors_name = "SimpleDelta"

Map("n", "gT", function()
    vim.api.nvim_cmd({ cmd = "Inspect" }, {})
end)

vim.api.nvim_set_var("c_syntax_for_h", true)

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
vim.api.nvim_create_autocmd("FileType", {
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

vim.api.nvim_create_autocmd("FileType", {
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

vim.api.nvim_create_autocmd("FileType", {
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

vim.api.nvim_create_autocmd("LspAttach", {
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

vim.api.nvim_create_autocmd("LspAttach", {
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

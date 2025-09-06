-- NOTE: This is a bespoke version of Fluoromachine.nvim's delta theme

local c = {
    -- https://www.sessions.edu/color-calculator/
    black = "#000000",

    fg = "#EFEFFD",

    l_cyan = "#98FFFB",

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
}

local groups = {

    ----------------------
    -- Diagnostic Links --
    ----------------------

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

    --------------------------
    -- Other Related/Linked --
    --------------------------

    Normal = { fg = c.fg },
    NormalFloat = { link = "Normal" }, -- Default self-definition
    Delimiter = { link = "Normal" },
    Identifier = { link = "Normal" },

    ["@variable"] = {}, --- Default self-definition

    ColorColumn = { bg = c.d_purple },
    CursorLine = { link = "ColorColumn" }, -- (Default self-definition)
    CursorColumn = { link = "ColorColumn" }, -- (Default self-definition)

    Comment = { fg = c.purple, italic = true },
    Conceal = { link = "Comment" }, -- (Default self-definition)

    Constant = { fg = c.l_red },
    ["@constant.builtin"] = { link = "Constant" }, -- No default
    ["@variable.builtin"] = { link = "Constant" }, -- No default
    ["@lsp.typemod.variable.defaultLibrary"] = { link = "Constant" }, -- Default @lsp
    ["@lsp.typemod.variable.global"] = { link = "Constant" }, -- Default @lsp

    Function = { fg = c.l_yellow },
    ["@function.builtin"] = { link = "Function" }, -- Default link to Special
    ["@lsp.typemod.function.global"] = { link = "Constant" }, -- Default @lsp

    NonText = { fg = c.pink },
    SpecialKey = { link = "NonText" }, --- Default self-definition

    Number = { fg = c.l_cyan }, -- (Default link: Constant)
    Boolean = { link = "Number" }, -- (Default link: Constant)
    Character = { link = "Number" }, -- (Default link: Constant)
    ["@module"] = { link = "Number" }, -- (Default link: Type)
    ["@lsp.type.namespace"] = { link = "Number" }, -- (Default link: Type)
    ["@lsp.typemod.boolean.injected"] = { link = "Boolean" }, -- Default @lsp

    ["@lsp.type.enumMember"] = { fg = c.l_cyan, italic = true }, -- (Default link: Type)

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

    ["@lsp.type.parameter"] = { fg = c.l_orange }, -- Default link: Identifier
    ["@variable.parameter"] = { link = "@lsp.type.parameter" },

    StatusLine = { fg = c.fg, bg = c.d_purple_three },
    StatusLineNC = { link = "StatusLine" }, -- (Default self-definition)
    Tabline = { link = "StatusLine" }, -- (Default self-definition)

    String = { fg = c.l_purple },
    ["@string.escape"] = { fg = c.l_purple, italic = true },
    ["@lsp.type.formatSpecifier"] = { link = "@string.escape" },

    Type = { fg = c.l_green },
    ["@type.builtin"] = { link = "Type" }, -- Default link Special
    ["@lsp.type.builtinType"] = { link = "Type" }, -- Default link @lsp

    ["@lsp.type.typeAlias"] = { fg = c.l_green, italic = true },
    ["@lsp.type.selfTypeKeyword"] = { link = "@lsp.type.typeAlias" }, -- Default link @lsp

    WinSeparator = { fg = c.purple }, -- (Default link: Normal)
    FloatBorder = { link = "WinSeparator" }, -- (Default link: NormalFloat)

    -- LOW: Lifted from Fluoromachine because they look familiar, but I've not no thought into
    -- the actual reasoning behind these
    ["@markup.environment"] = { fg = c.l_purple },
    ["@markup.heading"] = { link = "Title" },
    ["@markup.italic"] = { fg = c.l_green, italic = true },
    ["@markup.link"] = { fg = c.l_cyan },
    ["@markup.link.label"] = { fg = c.l_cyan },
    ["@markup.link.url"] = { fg = c.comment },
    ["@markup.list"] = { fg = c.l_pink },
    ["@markup.list.checked"] = { fg = c.l_green },
    ["@markup.math"] = { link = "Operator" },
    ["@markup.quote"] = { link = "Comment" },
    ["@markup.raw"] = { link = "Comment" },
    ["@markup.raw.block"] = { link = "Comment" },
    ["@markup.strikethrough"] = { fg = c.l_yellow, strikethrough = true },
    ["@markup.strong"] = { fg = c.l_red, bold = true },
    ["@markup.underline"] = { link = "Underlined" },

    -----------------
    -- Other Stuff --
    -----------------

    CurSearch = { fg = c.black, bg = c.l_orange },
    IncSearch = { fg = c.l_green },
    QuickFixLine = { bg = c.bold_purple },
    Search = { fg = c.orange_fg, bg = c.orange },
    Visual = { bg = c.bold_purple },

    CursorLineNr = { fg = c.l_green },
    Directory = { fg = c.l_green },
    LineNr = { fg = c.purple }, -- rnu
    Title = { fg = c.l_green },
    Todo = { fg = c.l_green },

    Folded = { fg = c.purple, bg = c.bold_purple },
    LspInlayHint = { fg = c.green, italic = true },
    MatchParen = { underline = true },

    Pmenu = { fg = c.fg },
    PmenuSel = { bg = c.bold_purple },
    PmenuThumb = { bg = c.l_cyan },

    Cursor = {}, --- (Default self-definition. I have reverse video cursor set in the terminal)
    EndOfBuffer = {}, -- (Default link: Non-text)
    lCursor = {}, --- (Default self-definition. I have reverse video cursor set in the terminal)
    NormalNC = {}, -- Causes performance issues (default setting)
    SignColumn = {}, -- Default self-definition
    -- FoldColumn = {}, -- (Default link: SignColumn)
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
if vim.fn.exists("syntax_on") then Cmd({ cmd = "syntax", args = { "reset" } }, {}) end

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

Map("n", "gT", function() vim.api.nvim_cmd({ cmd = "Inspect" }, {}) end)

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

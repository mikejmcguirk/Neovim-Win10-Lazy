local M = {}

function M.set_highlights()
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

    Gset("colors_name", "SimpleDelta")
end

return M

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

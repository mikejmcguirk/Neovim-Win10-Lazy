-- Bespoke version of Fluoromachine.nvim's delta theme

local api = vim.api

api.nvim_cmd({ cmd = "hi", args = { "clear" } }, {})
if vim.g.syntax_on == 1 then
    api.nvim_cmd({ cmd = "syntax", args = { "reset" } }, {})
end
api.nvim_set_var("c_syntax_for_h", true)
api.nvim_set_var("colors_name", "SimpleDelta")
api.nvim_set_option_value("bg", "dark", {})

-- https://www.sessions.edu/color-calculator/
local black = "#000000" ---@type string
local fg = "#EFEFFD" ---@type string
local l_cyan = "#98FFFB" ---@type string
local cyan = "#558396" ---@type string
local l_green = "#C0FF98" ---@type string
local green = "#579964" ---@type string
local l_orange = "#FFD298" ---@type string
local orange = "#967A55" ---@type string
local orange_fg = "#FFF0E0" ---@type string
local l_pink = "#FF67D4" ---@type string
local pink = "#613852" ---@type string
local l_purple = "#D598FF" ---@type string
local purple = "#925393" ---@type string
local bold_purple = "#492949" ---@type string
local d_purple = "#251d2b" ---@type string
-- local d_purple_two = "#2b2233" ---@type string
-- Darkened from dark purple
local d_purple_three = "#18131c" ---@type string
local l_red = "#FF98B3" ---@type string
local l_yellow = "#EDFF98" ---@type string

---@param old_hl string
---@param cfg_ext table
local function hl_extend(old_hl, cfg_ext)
    local old_cfg = api.nvim_get_hl(0, { name = old_hl })
    return vim.tbl_extend("force", old_cfg, cfg_ext)
end

-- DIAGNOSTICS AND STATUS --

api.nvim_set_hl(0, "DiagnosticError", { fg = l_red })
api.nvim_set_hl(0, "DiagnosticWarn", { fg = l_orange })
api.nvim_set_hl(0, "DiagnosticInfo", { fg = l_green })
api.nvim_set_hl(0, "DiagnosticHint", { fg = l_cyan })
api.nvim_set_hl(0, "DiagnosticUnnecessary", { underdashed = true })

api.nvim_set_hl(0, "DiagnosticUnderlineError", hl_extend("DiagnosticError", { underline = true }))
api.nvim_set_hl(0, "DiagnosticUnderlineWarn", hl_extend("DiagnosticWarn", { underline = true }))
api.nvim_set_hl(0, "DiagnosticUnderlineInfo", hl_extend("DiagnosticInfo", { underline = true }))
api.nvim_set_hl(0, "DiagnosticUnderlineHint", hl_extend("DiagnosticHint", { underline = true }))

api.nvim_set_hl(0, "DiffAdd", { fg = black, bg = l_green })
api.nvim_set_hl(0, "DiffChange", { fg = black, bg = l_orange })
api.nvim_set_hl(0, "DiffDelete", { fg = black, bg = l_red })

api.nvim_set_hl(0, "Added", { link = "DiagnosticInfo" })
api.nvim_set_hl(0, "Changed", { link = "DiagnosticWarn" })
api.nvim_set_hl(0, "Removed", { link = "DiagnosticError" })

api.nvim_set_hl(0, "Error", { link = "DiagnosticError" })
api.nvim_set_hl(0, "ErrorMsg", { link = "DiagnosticError" })
api.nvim_set_hl(0, "WarningMsg", { link = "DiagnosticWarn" })
api.nvim_set_hl(0, "MoreMsg", { link = "DiagnosticInfo" })
api.nvim_set_hl(0, "Question", { link = "DiagnosticInfo" })

api.nvim_set_hl(0, "SpellBad", { link = "DiagnosticError" })
api.nvim_set_hl(0, "SpellLocal", { link = "DiagnosticWarn" })
api.nvim_set_hl(0, "SpellCap", { link = "DiagnosticInfo" })
api.nvim_set_hl(0, "SpellRare", { link = "DiagnosticHint" })

-- SPECIAL TEXT --

api.nvim_set_hl(0, "Comment", { fg = purple, italic = true })
api.nvim_set_hl(0, "Conceal", { link = "Comment" })

api.nvim_set_hl(0, "LspCodeLens", { fg = cyan })

api.nvim_set_hl(0, "NonText", { fg = pink })
api.nvim_set_hl(0, "SpecialKey", { link = "NonText" })

api.nvim_set_hl(0, "Folded", { fg = purple, bg = bold_purple })

api.nvim_set_hl(0, "LspInlayHint", { fg = green, italic = true })

api.nvim_set_hl(0, "EndOfBuffer", {})

-- NORMAL/FG --

api.nvim_set_hl(0, "Normal", { fg = fg })
api.nvim_set_hl(0, "Delimiter", {})
api.nvim_set_hl(0, "Identifier", {})
api.nvim_set_hl(0, "NormalFloat", {})
api.nvim_set_hl(0, "NormalNC", {})

api.nvim_set_hl(0, "@variable", {})
api.nvim_set_hl(0, "@variable.member", {})
api.nvim_set_hl(0, "@variable.property", {})

api.nvim_set_hl(0, "@lsp.type.variable", {})

-- RED --

api.nvim_set_hl(0, "Constant", { fg = l_red })

api.nvim_set_hl(0, "@constant.builtin", { link = "Constant" })
api.nvim_set_hl(0, "@variable.builtin", { link = "Constant" })

api.nvim_set_hl(0, "@lsp.typemod.function.global", { link = "Constant" })
api.nvim_set_hl(0, "@lsp.typemod.variable.defaultLibrary", { link = "Constant" })
api.nvim_set_hl(0, "@lsp.typemod.variable.global", { link = "Constant" })

api.nvim_set_hl(0, "@keyword.self", hl_extend("Constant", { italic = true }))

-- YELLOW --

api.nvim_set_hl(0, "Function", { fg = l_yellow })

api.nvim_set_hl(0, "@function.builtin", { link = "Function" })

-- CYAN --

api.nvim_set_hl(0, "Number", { fg = l_cyan })
api.nvim_set_hl(0, "Boolean", { link = "Number" })
api.nvim_set_hl(0, "Character", { link = "Number" })

api.nvim_set_hl(0, "@module", { link = "Number" })

api.nvim_set_hl(0, "@lsp.type.namespace", { link = "Number" })
api.nvim_set_hl(0, "@lsp.typemod.boolean.injected", { link = "Boolean" })

api.nvim_set_hl(0, "@lsp.type.enumMember", hl_extend("Number", { italic = true }))

-- PINK --

api.nvim_set_hl(0, "Operator", { fg = l_pink })

api.nvim_set_hl(0, "@lsp.typemod.arithmetic.injected", { link = "Operator" })
api.nvim_set_hl(0, "@lsp.typemod.comparison.injected", { link = "Operator" })

api.nvim_set_hl(0, "Special", { fg = l_pink })
api.nvim_set_hl(0, "Statement", { link = "Special" })

api.nvim_set_hl(0, "@lsp.typemod.attributeBracket.injected", { link = "Special" })

api.nvim_set_hl(0, "PreProc", hl_extend("Special", { italic = true }))

api.nvim_set_hl(0, "@function.macro", { link = "PreProc" })
api.nvim_set_hl(0, "@preproc", { link = "PreProc" }) -- Custom TS Query

api.nvim_set_hl(0, "@lsp.type.macro", { link = "PreProc" })
api.nvim_set_hl(0, "@lsp.typemod.derive.macro", { link = "PreProc" })
api.nvim_set_hl(0, "@lsp.typemod.lifetime.injected", { link = "PreProc" })

-- ORANGE --

api.nvim_set_hl(0, "@variable.parameter", { fg = l_orange })

api.nvim_set_hl(0, "@lsp.type.parameter", { link = "@variable.parameter" })

-- PURPLE --

api.nvim_set_hl(0, "String", { fg = l_purple })

api.nvim_set_hl(0, "@string.escape", hl_extend("String", { italic = true }))

api.nvim_set_hl(0, "@lsp.type.formatSpecifier", { link = "@string.escape" })

-- GREEN --

api.nvim_set_hl(0, "Type", { fg = l_green })

api.nvim_set_hl(0, "@type.builtin", { link = "Type" })

api.nvim_set_hl(0, "@lsp.type.builtinType", { link = "Type" })
api.nvim_set_hl(0, "@lsp.type.derive", { link = "Type" })

api.nvim_set_hl(0, "@lsp.type.typeAlias", hl_extend("Type", { italic = true }))
api.nvim_set_hl(0, "@lsp.type.selfTypeKeyword", { link = "@lsp.type.typeAlias" })

-- UI --

api.nvim_set_hl(0, "CurSearch", { fg = black, bg = l_orange })
api.nvim_set_hl(0, "IncSearch", { fg = l_green })
api.nvim_set_hl(0, "Search", { fg = orange_fg, bg = orange })

api.nvim_set_hl(0, "QuickFixLine", { bg = bold_purple })

api.nvim_set_hl(0, "Visual", { bg = bold_purple })

api.nvim_set_hl(0, "CursorLineNr", { fg = l_green })
api.nvim_set_hl(0, "Directory", { fg = l_green })
api.nvim_set_hl(0, "LineNr", { fg = purple }) -- rnu
api.nvim_set_hl(0, "Title", { fg = l_green })
api.nvim_set_hl(0, "Todo", { fg = l_green })

api.nvim_set_hl(0, "MatchParen", { underline = true })

api.nvim_set_hl(0, "Pmenu", { fg = fg })
api.nvim_set_hl(0, "PmenuSel", { bg = bold_purple })
api.nvim_set_hl(0, "PmenuThumb", { bg = l_cyan })

api.nvim_set_hl(0, "ColorColumn", { bg = d_purple })
api.nvim_set_hl(0, "CursorLine", { link = "ColorColumn" })
api.nvim_set_hl(0, "CursorColumn", { link = "ColorColumn" })

api.nvim_set_hl(0, "WinSeparator", { fg = purple })
api.nvim_set_hl(0, "FloatBorder", { link = "WinSeparator" })

api.nvim_set_hl(0, "StatusLine", { fg = fg, bg = d_purple_three })
api.nvim_set_hl(0, "StatusLineNC", { link = "StatusLine" })
api.nvim_set_hl(0, "Tabline", { link = "StatusLine" })

api.nvim_set_hl(0, "Cursor", {}) -- I have reverse video cursor set in the terminal
api.nvim_set_hl(0, "lCursor", {})
api.nvim_set_hl(0, "SignColumn", {})

-- MARKUP --

api.nvim_set_hl(0, "@markup.environment", { fg = l_purple })
api.nvim_set_hl(0, "@markup.heading", { link = "Title" })
api.nvim_set_hl(0, "@markup.italic", { italic = true })
api.nvim_set_hl(0, "@markup.link", { fg = l_cyan })
api.nvim_set_hl(0, "@markup.link.label", { fg = l_cyan })
api.nvim_set_hl(0, "@markup.link.url", { fg = purple })
api.nvim_set_hl(0, "@markup.list", { fg = l_pink })
api.nvim_set_hl(0, "@markup.list.checked", { fg = l_green })
api.nvim_set_hl(0, "@markup.math", { link = "Operator" })
api.nvim_set_hl(0, "@markup.quote", { link = "Comment" })
api.nvim_set_hl(0, "@markup.raw", { link = "Comment" })
api.nvim_set_hl(0, "@markup.raw.block", hl_extend("Normal", { italic = true }))
api.nvim_set_hl(0, "@markup.strikethrough", { strikethrough = true })
api.nvim_set_hl(0, "@markup.strong", { bold = true })
api.nvim_set_hl(0, "@markup.underline", { link = "Underlined" })

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

api.nvim_set_var("terminal_color_0", black)
api.nvim_set_var("terminal_color_1", l_red)
api.nvim_set_var("terminal_color_2", l_purple)
api.nvim_set_var("terminal_color_3", l_orange)
api.nvim_set_var("terminal_color_4", l_cyan)
api.nvim_set_var("terminal_color_5", l_green)
api.nvim_set_var("terminal_color_6", l_yellow)
api.nvim_set_var("terminal_color_7", fg)
api.nvim_set_var("terminal_color_8", lighten_hex(black, 30))
api.nvim_set_var("terminal_color_9", darken_hex(l_red, 30))
api.nvim_set_var("terminal_color_10", darken_hex(l_purple, 30))
api.nvim_set_var("terminal_color_11", darken_hex(l_orange, 30))
api.nvim_set_var("terminal_color_12", darken_hex(l_cyan, 30))
api.nvim_set_var("terminal_color_13", darken_hex(l_green, 30))
api.nvim_set_var("terminal_color_14", darken_hex(l_yellow, 30))
api.nvim_set_var("terminal_color_15", darken_hex(fg, 30))

local function darken_24bit(color, pct)
    local r = bit.band(bit.rshift(color, 16), 0xFF)
    local g = bit.band(bit.rshift(color, 8), 0xFF)
    local b = bit.band(color, 0xFF)
    r = math.max(0, math.floor(r * (1 - pct / 100)))
    g = math.max(0, math.floor(g * (1 - pct / 100)))
    b = math.max(0, math.floor(b * (1 - pct / 100)))

    return bit.bor(bit.lshift(r, 16), bit.lshift(g, 8), b)
end

api.nvim_set_hl(0, "stl_a", { link = "String" })
local s_fg = api.nvim_get_hl(0, { name = "String" }).fg
api.nvim_set_hl(0, "stl_b", { fg = s_fg, bg = darken_24bit(s_fg, 50) })
api.nvim_set_hl(0, "stl_c", { link = "Normal" })

-- LOW: Would be cool if this was a hover menu
vim.keymap.set("n", "zS", function()
    api.nvim_cmd({ cmd = "Inspect" }, {})
end)

-- FUTURE: This issue seems to be helped by not eagly disably captures
-- https://github.com/neovim/neovim/issues/35575
-- NOTE: Don't create a global disable here, as we can't know how it would apply to new languages
-- NOTE: Only disable treesitter captures if they produce bad colors. Squeezing perf out of
-- disabling captures is not worth the maintenance cost
-- LOW: Once we no longer need to tie this code to resolving the nowrap issue, move this out into
-- ftplugin files, since this is filetype specific behavior

api.nvim_create_autocmd("FileType", {
    group = api.nvim_create_augroup("mjm-lua-disable-hl-captures", {}),
    pattern = "lua",
    once = true,
    callback = function()
        api.nvim_set_hl(0, "@lsp.type.function.lua", {})
        api.nvim_set_hl(0, "@lsp.type.method.lua", {})
        api.nvim_set_hl(0, "@lsp.type.property.lua", {})
        api.nvim_set_hl(0, "@lsp.type.variable.lua", {})

        ---@type vim.treesitter.Query?
        local hl_query = vim.treesitter.query.get("lua", "highlights")
        if not hl_query then
            return
        end

        -- Keep constant.builtin because it includes nil
        -- Keep variable.parameter because there are edge cases semantic tokens miss

        hl_query.query:disable_capture("function")
    end,
})

api.nvim_create_autocmd("FileType", {
    group = api.nvim_create_augroup("mjm-rust-disable-hl-captures", {}),
    pattern = "rust",
    once = true,
    callback = function()
        api.nvim_set_hl(0, "@lsp.type.property.rust", {})
        api.nvim_set_hl(0, "@lsp.type.variable.rust", {})
    end,
})

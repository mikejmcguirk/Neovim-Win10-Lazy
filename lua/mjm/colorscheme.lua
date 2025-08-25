-- NOTE: This is a bespoke version of Fluoromachine.nvim's delta theme

-- TODO: I can check this on Cinnamon, but I think some of the display issues I'm having are
-- due to the lack of compositing

-- TODO: For completeness's sake, add in terminal colors. Should be able to match with my
-- ghostty config

local M = {}

function M.darken_24bit(color, pct)
    local r = bit.band(bit.rshift(color, 16), 0xFF)
    local g = bit.band(bit.rshift(color, 8), 0xFF)
    local b = bit.band(color, 0xFF)

    r = math.max(0, math.floor(r * (1 - pct / 100)))
    g = math.max(0, math.floor(g * (1 - pct / 100)))
    b = math.max(0, math.floor(b * (1 - pct / 100)))

    return bit.bor(bit.lshift(r, 16), bit.lshift(g, 8), b)
end

----------------------------------
-- The actual colorscheme setup --
----------------------------------

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
end

-- TODO: The statusline would benefit from some kind of more distinct, maybe darker bg color

local c = {
    -- https://www.sessions.edu/color-calculator/
    black = "#000000",

    fg = "#EFEFFD",

    cyan = "#98FFFB",

    light_green = "#C0FF98",
    green = "#6F9655",

    orange = "#FFD298",
    dark_orange = "#967A55",
    dark_orange_fg = "#FFF0E0",

    pink = "#FF67D4",

    light_purple = "#D598FF",
    purple = "#925393",
    bold_purple = "#492949",
    dark_purple = "#251d2b",
    dark_purple_two = "#2b2233",

    red = "#FF98B3",

    yellow = "#EDFF98",
}

local groups = {

    ----------------------
    -- Diagnostic Links --
    ----------------------

    DiagnosticError = { fg = c.red },
    DiagnosticWarn = { fg = c.orange },
    DiagnosticInfo = { fg = c.light_green },
    DiagnosticHint = { fg = c.cyan },

    -- Can't link and add info, so just manually set
    DiagnosticUnderlineError = { fg = c.red, underline = true },
    DiagnosticUnderlineWarn = { fg = c.orange, underline = true },
    DiagnosticUnderlineInfo = { fg = c.light_green, underline = true },
    DiagnosticUnderlineHint = { fg = c.cyan, underline = true },

    -- Same here
    DiffAdd = { fg = c.black, bg = c.light_green },
    DiffChange = { fg = c.black, bg = c.orange },
    DiffDelete = { fg = c.black, bg = c.red },

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

    ColorColumn = { bg = c.dark_purple },
    CursorLine = { link = "ColorColumn" }, -- (Default self-definition)
    CursorColumn = { link = "CursorLine" }, -- (Default self-definition)

    Comment = { fg = c.purple, italic = true },
    Conceal = { link = "Comment" }, -- (Default self-definition)

    Constant = { fg = c.red },
    ["@lsp.typemod.variable.global"] = { link = "Constant" }, -- Default @lsp
    ["@lsp.typemod.variable.defaultLibrary"] = { link = "Constant" }, -- Default @lsp
    ["@variable.builtin"] = { link = "Constant" }, -- No default

    Delimiter = { fg = c.fg },

    Function = { fg = c.yellow },
    ["@function.builtin"] = { link = "Function" }, -- Default link to Special

    Identifier = { fg = c.fg },
    ["@variable"] = { link = "Identifier" }, --- Default self-definition

    NonText = { fg = c.dark_purple_two },
    SpecialKey = { link = "NonText" }, --- Default self-definition

    Normal = { fg = c.fg },
    NormalFloat = { link = "Normal" }, -- Default self-definition

    Number = { fg = c.cyan }, -- (Default link: Constant)
    Boolean = { link = "Number" }, -- (Default link: Constant)
    ["@lsp.typemod.boolean.injected"] = { link = "Boolean" }, -- Default @lsp
    Character = { link = "Number" }, -- (Default link: Constant)

    ["@module"] = { link = "Number" }, -- (Default link: Type)
    ["@lsp.type.namespace"] = { link = "@module" }, -- (Default link: Type)

    ["@lsp.type.enumMember"] = { fg = c.cyan, italic = true }, -- (Default link: Type)

    Operator = { fg = c.pink },
    ["@lsp.typemod.arithmetic.injected"] = { link = "Operator" }, --- Default link @lsp
    ["@lsp.typemod.comparison.injected"] = { link = "Operator" }, --- Default link @lsp

    PreProc = { fg = c.pink, italic = true },
    ["@function.macro"] = { link = "PreProc" }, -- Default link: Function
    ["@lsp.type.macro"] = { link = "PreProc" }, -- (Default link: Constant)
    ["@lsp.typemod.lifetime.injected"] = { link = "PreProc" }, -- (Default link: @lsp)

    Special = { fg = c.pink },
    ["@lsp.typemod.attributeBracket.injected"] = { link = "Special" }, --- Default link @lsp

    Statement = { fg = c.pink },

    ["@variable.parameter"] = {}, -- Only useful with an LSP to track scope
    ["@lsp.type.parameter"] = { fg = c.orange }, -- Default link: Identifier

    StatusLine = { fg = c.fg, bg = c.dark_purple_two },
    StatusLineNC = { link = "StatusLine" }, -- (Default self-definition)

    String = { fg = c.light_purple },

    Type = { fg = c.light_green },
    ["@lsp.type.builtinType"] = { link = "Type" }, -- Default link @lsp
    --
    ["@lsp.type.typeAlias"] = { fg = c.light_green, italic = true },
    ["@lsp.type.selfTypeKeyword"] = { link = "@lsp.type.typeAlias" }, -- Default link @lsp

    WinSeparator = { fg = c.purple }, -- (Default link: Normal)
    FloatBorder = { link = "WinSeparator" }, -- (Default link: NormalFloat)

    -----------------
    -- Other Stuff --
    -----------------

    CurSearch = { fg = c.black, bg = c.orange },
    IncSearch = { fg = c.light_green },
    QuickFixLine = { bg = c.bold_purple },
    Search = { fg = c.dark_orange_fg, bg = c.dark_orange },
    Visual = { bg = c.bold_purple },

    Directory = { fg = c.light_green },
    CursorLineNr = { fg = c.light_green },
    LineNr = { fg = c.purple }, -- rnu
    Title = { fg = c.light_green },
    Todo = { fg = c.light_green },

    Folded = { fg = c.purple, bg = c.bold_purple },
    LspInlayHint = { fg = c.green, italic = true },
    MatchParen = { underline = true },

    Pmenu = { fg = c.fg },
    PmenuSel = { bg = c.bold_purple },
    PmenuThumb = { bg = c.cyan },

    Cursor = {}, --- (Default self-definition. I have reverse video cursor set in the terminal)
    EndOfBuffer = {}, -- (Default link: Non-text)
    FoldColumn = {}, -- (Default link: SignColumn)
    lCursor = {}, --- (Default self-definition. I have reverse video cursor set in the terminal)
    NormalNC = {}, -- Causes performance issues (default setting)
    SignColumn = {}, -- Default self-definition

    --------------
    -- Personal --
    --------------

    EolSpace = { fg = c.cyan, bg = c.orange },

    ---------
    -- Lua --
    ---------

    ["@comment.documentation.lua"] = {}, -- Treesitter assumes all three-dash comments are docs
    ["@lsp.type.method.lua"] = {}, -- Confusing when functions are used as variables
}

for k, v in pairs(groups) do
    vim.api.nvim_set_hl(0, k, v)
end

-- Fill-in un-recognized constants
vim.api.nvim_create_autocmd("LspTokenUpdate", {
    group = vim.api.nvim_create_augroup("lsp-token-fix", { clear = true }),
    pattern = "*.lua",
    callback = function(ev)
        local token = ev.data.token
        if token.type ~= "variable" or token.modifiers.readonly then
            return
        end

        local text = vim.api.nvim_buf_get_text(
            ev.buf,
            token.line,
            token.start_col,
            token.line,
            token.end_col,
            {}
        )[1]

        if text ~= string.upper(text) then
            return
        end

        vim.lsp.semantic_tokens.highlight_token(token, ev.buf, ev.data.client_id, "Constant")
    end,
})

vim.g.colors_name = "SimpleDelta"

-- Works with the Quickscope plugin. Good hl_groups in general
vim.api.nvim_set_hl(0, "QuickScopePrimary", {
    bg = vim.api.nvim_get_hl(0, { name = "Number" }).fg,
    fg = "#000000",
    ctermbg = 14,
    ctermfg = 0,
})

vim.api.nvim_set_hl(0, "QuickScopeSecondary", {
    bg = vim.api.nvim_get_hl(0, { name = "Statement" }).fg,
    fg = "#000000",
    ctermbg = 207,
    ctermfg = 0,
})

return M

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

-- local function darken_hex(color, pct)
--     local r = tonumber(color:sub(2, 3), 16)
--     local g = tonumber(color:sub(4, 5), 16)
--     local b = tonumber(color:sub(6, 7), 16)
--
--     r = math.max(0, math.floor(r * (1 - pct / 100)))
--     g = math.max(0, math.floor(g * (1 - pct / 100)))
--     b = math.max(0, math.floor(b * (1 - pct / 100)))
--
--     return string.format("#%02X%02X%02X", r, g, b)
-- end
--
-- function M.darken_hex(color, pct)
--     local r = tonumber(color:sub(2, 3), 16)
--     local g = tonumber(color:sub(4, 5), 16)
--     local b = tonumber(color:sub(6, 7), 16)
--
--     r = math.max(0, math.floor(r * (1 - pct / 100)))
--     g = math.max(0, math.floor(g * (1 - pct / 100)))
--     b = math.max(0, math.floor(b * (1 - pct / 100)))
--
--     return string.format("#%02X%02X%02X", r, g, b)
-- end

-- local function lighten_hex(color, percent)
--     local r = tonumber(color:sub(2, 3), 16)
--     local g = tonumber(color:sub(4, 5), 16)
--     local b = tonumber(color:sub(6, 7), 16)
--
--     r = math.min(255, math.floor(r * (1 + percent / 100)))
--     g = math.min(255, math.floor(g * (1 + percent / 100)))
--     b = math.min(255, math.floor(b * (1 + percent / 100)))
--
--     return string.format("#%02X%02X%02X", r, g, b)
-- end

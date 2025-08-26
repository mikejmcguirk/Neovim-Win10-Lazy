-- NOTE: This is a bespoke version of Fluoromachine.nvim's delta theme

-- TODO: I can check this on Cinnamon, but I think some of the display issues I'm having are
-- due to the lack of compositing

-- TODO: For completeness's sake, add in terminal colors. Should be able to match with my
-- ghostty config

local M = {}

local function darken_24bit(color, pct)
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
    -- green = "#6F9655",
    green = "#579964",

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

    Added = { fg = c.light_green }, -- (Default self-definition)
    Changed = { fg = c.orange }, -- (Default self-definition)
    Removed = { fg = c.red }, -- (Default self-definition)

    Error = { fg = c.red }, --- (Default self-definition)
    ErrorMsg = { fg = c.red }, --- (Default self-definition)
    WarningMsg = { fg = c.orange }, -- (Default self-definition)
    MoreMsg = { fg = c.light_green }, -- (Default self-definition)
    Question = { fg = c.light_green }, -- (Default self-definition)

    SpellBad = { fg = c.red }, -- (Default self-definition)
    SpellLocal = { fg = c.orange }, -- (Default self-definition)
    SpellCap = { fg = c.light_green }, -- (Default self-definition)
    SpellRare = { fg = c.cyan }, -- (Default self-definition)

    --------------------------
    -- Other Related/Linked --
    --------------------------

    ColorColumn = { bg = c.dark_purple },
    CursorLine = { bg = c.dark_purple }, -- (Default self-definition)
    CursorColumn = { bg = c.dark_purple }, -- (Default self-definition)

    Comment = { fg = c.purple, italic = true },
    Conceal = { fg = c.purple, italic = true }, -- (Default self-definition)

    Constant = { fg = c.red },
    ["@constant.builtin"] = { fg = c.red }, -- No default
    ["@lsp.typemod.variable.global"] = { fg = c.red }, -- Default @lsp
    ["@lsp.typemod.variable.defaultLibrary"] = { fg = c.red }, -- Default @lsp
    ["@variable.builtin"] = { fg = c.red }, -- No default

    Delimiter = { fg = c.fg },
    Normal = { fg = c.fg },
    NormalFloat = { fg = c.fg }, -- Default self-definition

    Function = { fg = c.yellow },
    ["@function.builtin"] = { fg = c.yellow }, -- Default link to Special

    Identifier = { fg = c.fg },
    ["@variable"] = { fg = c.fg }, --- Default self-definition

    NonText = { fg = c.dark_purple_two },
    SpecialKey = { fg = c.dark_purple_two }, --- Default self-definition

    Number = { fg = c.cyan }, -- (Default link: Constant)
    Boolean = { fg = c.cyan }, -- (Default link: Constant)
    ["@lsp.typemod.boolean.injected"] = { fg = c.cyan }, -- Default @lsp
    Character = { fg = c.cyan }, -- (Default link: Constant)

    ["@module"] = { fg = c.cyan }, -- (Default link: Type)
    ["@lsp.type.namespace"] = { fg = c.cyan }, -- (Default link: Type)

    ["@lsp.type.enumMember"] = { fg = c.cyan, italic = true }, -- (Default link: Type)

    Operator = { fg = c.pink },
    ["@lsp.typemod.arithmetic.injected"] = { fg = c.pink }, --- Default link @lsp
    ["@lsp.typemod.comparison.injected"] = { fg = c.pink }, --- Default link @lsp

    PreProc = { fg = c.pink, italic = true },
    ["@function.macro"] = { fg = c.pink, italic = true }, -- Default link: Function
    ["@lsp.type.macro"] = { fg = c.pink, italic = true }, -- (Default link: Constant)
    ["@lsp.typemod.lifetime.injected"] = { fg = c.pink, italic = true }, -- (Default link: @lsp)

    Special = { fg = c.pink },
    ["@lsp.typemod.attributeBracket.injected"] = { fg = c.pink }, --- Default link @lsp

    Statement = { fg = c.pink },

    ["@variable.parameter"] = {}, -- Only useful with an LSP to track scope
    ["@lsp.type.parameter"] = { fg = c.orange }, -- Default link: Identifier

    StatusLine = { fg = c.fg, bg = c.dark_purple_two },
    StatusLineNC = { fg = c.fg, bg = c.dark_purple_two }, -- (Default self-definition)

    String = { fg = c.light_purple },

    Type = { fg = c.light_green },
    ["@lsp.type.builtinType"] = { fg = c.light_green }, -- Default link @lsp
    --
    ["@lsp.type.typeAlias"] = { fg = c.light_green, italic = true },
    ["@lsp.type.selfTypeKeyword"] = { fg = c.light_green, italic = true }, -- Default link @lsp

    WinSeparator = { fg = c.purple }, -- (Default link: Normal)
    FloatBorder = { fg = c.purple }, -- (Default link: NormalFloat)

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
    ["@lsp.type.variable.lua"] = {}, -- Overwrites function calls
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

local s_fg = vim.api.nvim_get_hl(0, { name = "String" }).fg
local bg = vim.api.nvim_get_hl(0, { name = "NonText" }).bg
local fg = vim.api.nvim_get_hl(0, { name = "Normal" }).fg

vim.api.nvim_set_hl(0, "stl_a", { fg = s_fg, bg = bg })
local b_bg = darken_24bit(s_fg, 50)
vim.api.nvim_set_hl(0, "stl_b", { fg = s_fg, bg = b_bg })
vim.api.nvim_set_hl(0, "stl_c", { fg = fg, bg = bg })

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

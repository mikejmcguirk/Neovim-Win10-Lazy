-- NOTE: This is a bespoke version of Fluoromachine.nvim's delta theme

-- TODO: I can check this on Cinnamon, but I think some of the display issues I'm having are
-- due to the lack of compositing

-- TODO: Offload as much from Semantic tokens as possible. Some stuff like using them to
-- highlight vim as a global will never go away. But treesitter does distinguish, for example,
-- between Rust functions and Rust macros

-- MAYBE: Underline diagnostics again. It felt a bit noisy

local M = {}

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

local function darken_hex(color, percent)
    local r = tonumber(color:sub(2, 3), 16)
    local g = tonumber(color:sub(4, 5), 16)
    local b = tonumber(color:sub(6, 7), 16)

    r = math.max(0, math.floor(r * (1 - percent / 100)))
    g = math.max(0, math.floor(g * (1 - percent / 100)))
    b = math.max(0, math.floor(b * (1 - percent / 100)))

    return string.format("#%02X%02X%02X", r, g, b)
end

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
    fg = "#EFEFFD",

    black = "#000000",

    light_purple = "#D598FF",
    purple = "#925393",
    bold_purple = "#492949",
    dark_purple = "#251d2b",
    dark_purple_two = "#2b2233", -- for indent guides, listchars, and such

    cyan = "#98FFFB",

    aqua = "#98FFB6",
    -- aqua = "#ACFFCA",

    green = "#C0FF98",
    forest_green = "#99CC79",

    orange = "#FFD298",
    dark_orange = darken_hex("#FFD298", 60),

    pink = "#FF67D4",

    red = "#FF98B3",

    yellow = "#EDFF98",

    -- active_blankline = "#607F4C",
}

local groups = {

    ---------------
    -- Built-ins --
    ---------------

    Added = { fg = c.green },
    Boolean = { link = "Number" }, -- (Default link: Constant)
    Changed = { link = "WarningMsg" }, -- (Default self-definition)
    Character = { link = "Number" }, -- (Default link: Constant)
    ColorColumn = { bg = c.dark_purple },
    Comment = { fg = c.purple, italic = true },
    Conceal = { link = "Comment" }, -- (Default self-definition)
    Constant = { fg = c.red },
    CurSearch = { fg = c.black, bg = c.orange },
    Cursor = {}, --- (Default self-definition. I have reverse video cursor set in the terminal)
    lCursor = {}, --- (Default self-definition. I have reverse video cursor set in the terminal)
    CursorLine = { link = "ColorColumn" }, -- (Default self-definition)
    CursorLineNr = { fg = c.pink },
    CursorColumn = { link = "CursorLine" },
    DiagnosticError = { fg = c.red },
    DiagnosticWarn = { fg = c.orange },
    DiagnosticInfo = { fg = c.green },
    DiagnosticHint = { fg = c.aqua },
    -- Neovim's diagnostic publishing doesn't have a "no underline" option so these have to be
    -- changed
    -- PR: Feels like an easy change to make
    DiagnosticUnderlineError = { link = "DiagnosticError" },
    DiagnosticUnderlineWarn = { link = "DiagnosticWarn" },
    DiagnosticUnderlineInfo = { link = "DiagnosticInfo" },
    DiagnosticUnderlineHint = { link = "DiagnosticHint" },
    DiffAdd = { fg = c.black, bg = c.green },
    DiffChange = { fg = c.black, bg = c.orange },
    DiffDelete = { fg = c.black, bg = c.red },
    Delimiter = { fg = c.fg },
    Directory = { fg = c.green },
    EndOfBuffer = {}, -- (Default link: Non-text)
    Error = { link = "DiagnosticError" }, --- (Default self-definition)
    ErrorMsg = { link = "DiagnosticError" }, --- (Default self-definition)
    FloatBorder = { fg = c.purple }, -- (Default link: NormalFloat)
    FoldColumn = {}, -- (Default link: SignColumn)
    Folded = { fg = c.purple, bg = c.bold_purple },
    Function = { fg = c.yellow },
    Identifier = { fg = c.fg },
    IncSearch = { link = "Type" },
    LineNr = { fg = c.purple }, -- rnu
    LspInlayHint = { fg = c.aqua },
    MatchParen = { underline = true },
    MoreMsg = { fg = c.green },
    NonText = { fg = c.dark_purple_two },
    Normal = { fg = c.fg },
    NormalFloat = { fg = c.fg },
    NormalNC = {}, -- Causes performance issues (default behavior)
    Number = { fg = c.cyan }, -- (Default link: Constant)
    Operator = { fg = c.pink },
    Pmenu = { fg = c.fg },
    PmenuSel = { bg = c.bold_purple },
    PmenuThumb = { bg = c.cyan },
    PreProc = { fg = c.pink },
    Question = { fg = c.green },
    QuickFixLine = { bg = c.bold_purple },
    Removed = { link = "ErrorMsg" }, -- (Default self-definition)
    Search = { fg = "#FFFFEE", bg = c.dark_orange },
    SignColumn = { fg = "NONE", bg = "NONE" },
    Special = { fg = c.pink },
    SpecialKey = { link = "NonText" }, --- (Default self-definition)
    SpellBad = { link = "DiagnosticError" }, -- (Default self-definition)
    SpellCap = { link = "DiagnosticInfo" }, -- (Default self-definition)
    SpellLocal = { link = "DiagnosticWarn" }, -- (Default self-definition)
    SpellRare = { link = "DiagnosticHint" }, -- (Default self-definition)
    Statement = { fg = c.pink },
    StatusLine = { fg = c.fg, bg = c.dark_purple_two },
    StatusLineNC = { link = "StatusLine" }, -- (Default self-definition)
    String = { fg = c.light_purple },
    Structure = { link = "Type" },
    Title = { fg = c.green },
    Todo = { fg = c.green },
    Type = { fg = c.green },
    Visual = { bg = c.bold_purple },
    WarningMsg = { link = "DiagnosticWarn" }, -- (Default self-definition)
    WinSeparator = { fg = c.purple }, -- (Default link: Normal)

    --------------
    -- Personal --
    --------------

    EolSpace = { fg = c.cyan, bg = c.orange },

    ----------------
    -- Treesitter --
    ----------------

    -- ["@comment"] = { link = "Comment" },
    -- ["@comment.documentation"] = { link = "Comment" },
    -- ["@comment.error"] = { fg = c.error, bg = "NONE" },
    -- ["@comment.warning"] = { fg = c.warning, bg = "NONE" },
    -- ["@comment.todo"] = { link = "Title" },
    -- ["@comment.note"] = { fg = c.hint, bg = "NONE" },
    -- ["@error"] = { link = "Error" },
    -- ["@operator"] = { link = "Operator" },
    -- ["@punctuation.delimiter"] = { fg = c.fg, bg = "NONE" },
    -- ["@punctuation.bracket"] = { fg = c.fg, bg = "NONE" },
    ["@punctuation.special"] = { fg = c.fg },
    -- ["@string"] = { link = "String" },
    -- ["@string.regex"] = { fg = c.pink, bg = "NONE" },
    -- ["@string.escape"] = { fg = c.pink, bg = "NONE" },
    -- ["@string.special"] = { fg = c.red, bg = "NONE" },
    -- ["@character"] = { link = "@string" },
    -- ["@character.special"] = { fg = c.yellow, bg = "NONE" },
    -- ["@function"] = { link = "Function" },
    -- ["@function.builtin"] = { link = "@function" },
    -- ["@function.call"] = { link = "@function" },
    -- ["@method"] = { link = "@function" },
    -- ["@method.call"] = { link = "@function" },
    -- ["@constructor"] = { fg = c.pink, bg = "NONE" },
    -- ["@constructor.c_sharp"] = { link = "@type" },
    -- ["@constructor.php"] = { link = "@type" },
    -- ["@parameter"] = { fg = c.orange, bg = "NONE", italic = true },
    -- ["@boolean"] = { link = "Boolean" },
    -- ["@number"] = { link = "Number" },
    -- ["@float"] = { link = "Float" },
    -- ["@label.json"] = { fg = c.green, bg = "NONE" },
    -- ["@label.ruby"] = { link = "@variable.builtin" },
    -- ["@exception"] = { link = "Exception" },
    -- ["@type"] = { link = "Type" },
    -- ["@type.dart"] = { link = "@type" },
    -- ["@type.builtin"] = { link = "Type" },
    -- ["@type.builtin.cpp"] = { link = "Type" },
    -- ["@type.definition"] = { link = "Type" },
    -- ["@type.qualifier"] = { fg = c.pink, bg = "NONE" },
    -- ["@storageclass"] = { fg = c.pink, bg = "NONE" },
    -- ["@attribute"] = { fg = c.green, bg = "NONE", italic = true },
    -- ["@field"] = { fg = c.fg, bg = "NONE" },
    -- ["@property"] = { link = "@field" },
    ["@variable"] = { fg = c.fg },
    -- ["@variable.builtin"] = { fg = c.red, bg = "NONE", italic = true },
    -- ["@variable.global.ruby"] = { link = "@constant" },
    -- ["@constant"] = { link = "Constant" },
    -- ["@constant.builtin"] = { link = "Constant" },
    -- ["@constant.macro"] = { link = "Constant" },
    -- ["@namespace"] = { fg = c.cyan, bg = "NONE" },
    -- ["@symbol"] = { fg = c.red, bg = "NONE" },
    -- ["@markup.strong"] = { fg = c.red, bg = "NONE", bold = true },
    -- ["@markup.italic"] = { fg = c.green, bg = "NONE", italic = true },
    -- ["@markup.strikethrough"] = { fg = c.yellow, bg = "NONE", strikethrough = true },
    -- ["@markup.underline"] = { link = "Underlined" },
    -- ["@markup.heading"] = { link = "Title" },
    -- ["@markup.quote"] = { link = "Comment" },
    -- ["@markup.math"] = { link = "Operator" },
    -- ["@markup.environment"] = { fg = c.purple, bg = "NONE" },
    -- ["@markup.link"] = { fg = c.cyan, bg = "NONE" },
    -- ["@markup.link.label"] = { fg = c.cyan, bg = "NONE" },
    -- ["@markup.link.url"] = { fg = c.comment, bg = "NONE" },
    -- ["@markup.raw"] = { link = "Comment" },
    -- ["@markup.raw.block"] = { link = "Comment" },
    -- ["@markup.list"] = { fg = c.pink, bg = "NONE" },
    -- ["@markup.list.checked"] = { fg = c.sign_add, bg = "NONE" },
    -- ["@tag"] = { fg = c.pink, bg = "NONE" },
    -- ["@tag.attribute"] = { link = "@field" },
    -- ["@tag.delimiter"] = { fg = c.fg, bg = "NONE" },

    ---------------------
    -- Treesitter: Lua --
    ---------------------

    -- Treesitter assumes all three-dash comments are documentation. Let Treesitter handle
    -- default comment highlighting, then have semantic tokens fill in the annotations
    ["@comment.documentation.lua"] = {},
    -- Does not properly distinguish between globals and locals
    ["@variable.lua"] = {},

    ---------------------
    -- Semantic Tokens --
    ---------------------

    ["@lsp.type.class"] = { link = "Type" },
    ["@lsp.type.decorator"] = { link = "Function" },
    ["@lsp.type.enum"] = { link = "Type" },
    ["@lsp.type.enumMember"] = { link = "Constant" },
    ["@lsp.type.function"] = { link = "Function" },
    ["@lsp.type.interface"] = { link = "Type" },
    ["@lsp.type.macro"] = { link = "PreProc" },
    ["@lsp.type.method"] = { link = "Function" },
    ["@lsp.type.namespace"] = { link = "Number" },
    ["@lsp.type.parameter"] = { link = "WarningMsg" },
    ["@lsp.type.property"] = { fg = c.fg },
    ["@lsp.type.struct"] = { link = "Structure" },
    ["@lsp.type.type"] = { link = "Type" },
    ["@lsp.type.typeParameter"] = { link = "Type" },
    ["@lsp.type.variable"] = { fg = c.fg },
    ["@lsp.typemod.class.documentation"] = { link = "Type" },
    ["@lsp.typemod.keyword.documentation"] = { link = "Statement" },
    ["@lsp.typemod.property.readonly"] = { link = "Constant" },
    ["@lsp.typemod.variable.defaultLibrary"] = { link = "Constant" },
    ["@lsp.typemod.variable.global"] = { link = "Constant" },
    ["@lsp.typemod.variable.readonly"] = { link = "Constant" },

    --------------------------
    -- Semantic Tokens: Lua --
    --------------------------

    -- General note with Lua - Semantic tokens for keyword, parameter, and so on are used
    -- to highlight comment annotations

    ["@lsp.type.comment.lua"] = {}, -- Treesitter can properly handle basic comments
    ["@lsp.type.method.lua"] = {}, -- Confusing when functions are used as variables
}

for k, v in pairs(groups) do
    vim.api.nvim_set_hl(0, k, v)
end

-- Fill-in un-recognized constants
-- FUTURE: Could this be a TS Query? Though that might be slower since we already have the token
vim.api.nvim_create_autocmd("LspTokenUpdate", {
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

local api = vim.api
local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

require("mjm.utils").set_buf_space_indent(0, 2)

-- "r" in Markdown treats lines like "- some text" as comments and indents them
mjm.opt.str_rm("fo", "r", { scope = "local" })
api.nvim_set_option_value("cc", "", { scope = "local" })
api.nvim_set_option_value("culopt", "number,screenline", { scope = "local" })
api.nvim_set_option_value("siso", 12, { scope = "local" })
api.nvim_set_option_value("spell", true, { scope = "local" })
api.nvim_set_option_value("wrap", true, { scope = "local" })

vim.keymap.set("i", ",", ",<C-g>u", { buffer = 0 })
vim.keymap.set("i", ".", ".<C-g>u", { buffer = 0 })
vim.keymap.set("i", ":", ":<C-g>u", { buffer = 0 })
vim.keymap.set("i", "-", "-<C-g>u", { buffer = 0 })
vim.keymap.set("i", "?", "?<C-g>u", { buffer = 0 })
vim.keymap.set("i", "!", "!<C-g>u", { buffer = 0 })
vim.keymap.set("n", "gK", function()
    ut.check_word_under_cursor()
end, { buffer = 0 })

-- MID: Create a localleader mapping in Conform for prettier, keep this for running on save

vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = 0,
    callback = function(ev)
        ut.fallback_formatter(ev.buf)
    end,
})

-- MID: More reliable method for creating checkboxes in insert mode
-- Basic solution - Make sure creating a checkbox puts the cursor at the end of the line, which
-- needs to happen in normal mode anyway, allowing <C-o>gf to work
-- A hotkey then would work/be helpful. Would be cool if you could double it over vim.bullets
-- promote
-- I think that for namespacing reasons, making <C-o>gf work is preferrable, should only make a
-- special key if it's really needed
-- MID: Should be possible to visually select multiple lines and alter their checkbox status
-- This case comes up more than you'd think
-- Issue is how to handle mixed cases

-- Modified from the obsidian-nvim/obsidian.nvim functions
---Supported checkboxes:
--- - [ ] foo
--- + [ ] foo
--- * [ ] foo
--- 1. [ ] foo
--- 1) [ ] foo

---@param line string
---@return boolean
local function is_checkbox(line)
    if string.match(line, "%s*[-+*]%s+%[.%]") ~= nil then
        return true
    end
    if string.match(line, "%s*%d+[%.%)]%s+%[.%]") ~= nil then
        return true
    end
    return false
end

---@return nil
local function toggle_checkbox()
    if ut.is_in_node_type({ "fenced_code_block", "minus_metadata" }) then
        return
    end
    local row = api.nvim_win_get_cursor(0)[1] ---@type integer
    local line = api.nvim_buf_get_lines(0, row - 1, row, false)[1] ---@type string
    local unchecked = " " ---@type string
    local checked = "x" ---@type string
    local new_line = (function()
        if is_checkbox(line) then
            if string.match(line, "^.*%[[xX]%]") then
                local unchecked_part = "[" .. unchecked .. "]" ---@type string
                return string.gsub(line, "%[[xX]%]", unchecked_part, 1)
            else
                local unchecked_part = "%[" .. unchecked .. "%]" ---@type string
                local checked_part = "[" .. checked .. "]" ---@type string
                return string.gsub(line, unchecked_part, checked_part, 1)
            end
        else
            local unordered_pat = "^(%s*)([-+*]) (.*)" ---@type string
            local ordered_pat = "^(%s*)(%d+[%.%)]) (.*)" ---@type string
            if string.match(line, unordered_pat) then
                return (string.gsub(line, unordered_pat, "%1%2 [ ] %3"))
            elseif string.match(line, ordered_pat) then
                return (string.gsub(line, ordered_pat, "%1%2 [ ] %3"))
            else
                return string.gsub(line, "^(%s*)", "%1- [ ] ")
            end
        end
    end)() ---@type string

    vim.api.nvim_buf_set_lines(0, row - 1, row, true, { new_line })
end

-- Traditional, since the Obsidian plugin uses gf as its multi-function key
-- Since markdown-oxide uses goto definition for link nav, we don't need gf for that purpose
vim.keymap.set("n", "gf", toggle_checkbox)

mjm.lsp.start(vim.lsp.config["markdown_oxide"], { bufnr = 0 })

-- MAYBE: Potential friction point: Bullets overrides autopairs <cr> mapping

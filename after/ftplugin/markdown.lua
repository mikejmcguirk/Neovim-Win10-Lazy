local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

local width = 2
vim.bo.tabstop = width
vim.bo.softtabstop = width
vim.bo.shiftwidth = width

vim.opt_local.colorcolumn = ""
vim.opt_local.cursorlineopt = "screenline"
vim.opt_local.wrap = true
vim.opt_local.sidescrolloff = 12
vim.opt_local.spell = true

-- "r" in Markdown treats lines like "- some text" as comments and indents them
vim.opt.formatoptions:append("r")

vim.keymap.set("i", ",", ",<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", ".", ".<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", ":", ":<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "-", "-<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "?", "?<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "!", "!<C-g>u", { silent = true, buffer = true })

vim.keymap.set("n", "K", function()
    ut.check_word_under_cursor()
end)

vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = vim.api.nvim_get_current_buf(),
    callback = function(ev)
        ut.fallback_formatter(ev.buf)
    end,
})

-- Modified from the obsidian-nvim/obsidian.nvim functions

---Check if a string is a checkbox list item
---
---Supported checboox lists:
--- - [ ] foo
--- - [x] foo
--- + [x] foo
--- * [ ] foo
--- 1. [ ] foo
--- 1) [ ] foo
---
---@param s string
---@return boolean
local function is_checkbox(s)
    -- - [ ] and * [ ] and + [ ]
    if string.match(s, "%s*[-+*]%s+%[.%]") ~= nil then return true end
    -- 1. [ ] and 1) [ ]
    if string.match(s, "%s*%d+[%.%)]%s+%[.%]") ~= nil then return true end
    return false
end

---Toggle the checkbox on the current line.
---
---@param states table|nil Optional table containing checkbox states (e.g., {" ", "x"}).
---@param line_num number|nil Optional line number to toggle the checkbox on. Defaults to the current line.
local function toggle_checkbox(states, line_num)
    if ut.is_in_node_type({ "fenced_code_block", "minus_metadata" }) == true then return end
    line_num = line_num or unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]

    local checkboxes = states or { " ", "x" }

    if is_checkbox(line) then
        for i, check_char in ipairs(checkboxes) do
            if string.match(line, "^.* %[" .. vim.pesc(check_char) .. "%].*") then
                i = i % #checkboxes
                line = string.gsub(
                    line,
                    vim.pesc("[" .. check_char .. "]"),
                    "[" .. checkboxes[i + 1] .. "]",
                    1
                )
                break
            end
        end
    elseif Obsidian.opts.checkbox.create_new then
        local unordered_list_pattern = "^(%s*)[-*+] (.*)"
        if string.match(line, unordered_list_pattern) then
            line = string.gsub(line, unordered_list_pattern, "%1- [ ] %2")
        else
            line = string.gsub(line, "^(%s*)", "%1- [ ] ")
        end
    else
        return
    end

    vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, true, { line })
end

-- Traditional, since the Obsidian plugin uses gf as its multi-function key
-- Since markdown-oxide uses goto definition for link nav, we don't need gf for that purpose
vim.keymap.set("n", "gf", toggle_checkbox)

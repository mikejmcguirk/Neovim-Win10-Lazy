local api = vim.api
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
---Supported checkboxes:
--- - [ ] foo
--- - [x] foo
--- + [x] foo
--- * [ ] foo
--- 1. [ ] foo
--- 1) [ ] foo

---@param line string
---@return boolean
local function is_checkbox(line)
    -- - [ ] and * [ ] and + [ ]
    if string.match(line, "%s*[-+*]%s+%[.%]") ~= nil then return true end
    -- 1. [ ] and 1) [ ]
    if string.match(line, "%s*%d+[%.%)]%s+%[.%]") ~= nil then return true end
    return false
end

---@return nil
local function toggle_checkbox()
    if ut.is_in_node_type({ "fenced_code_block", "minus_metadata" }) == true then return end
    local row, _ = unpack(api.nvim_win_get_cursor(0)) ---@type integer, integer
    local line = api.nvim_buf_get_lines(0, row - 1, row, false)[1] ---@type string
    local checkboxes = { " ", "x" } ---@type string[]
    local new_line = (function()
        if is_checkbox(line) then
            for i, check_char in ipairs(checkboxes) do
                if string.match(line, "^.* %[" .. vim.pesc(check_char) .. "%].*") then
                    i = i % #checkboxes
                    local pre = "%[" .. check_char .. "%]" ---@type string
                    local post = "[" .. checkboxes[i + 1] .. "]" ---@type string
                    return string.gsub(line, pre, post, 1)
                end
            end
        else
            local unordered_list_pat = "^(%s*)[-*+] (.*)" ---@type string
            if string.match(line, unordered_list_pat) then
                return string.gsub(line, unordered_list_pat, "%1- [ ] %2")
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

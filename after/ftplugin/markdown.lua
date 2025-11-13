local api = vim.api
local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

local width = 2
api.nvim_set_option_value("ts", width, { buf = 0 })
api.nvim_set_option_value("sts", width, { buf = 0 })
api.nvim_set_option_value("sw", width, { buf = 0 })

-- "r" in Markdown treats lines like "- some text" as comments and indents them
vim.opt_local.fo:remove("r")
api.nvim_set_option_value("cc", "", { scope = "local" })
api.nvim_set_option_value("culopt", "number,screenline", { scope = "local" })
api.nvim_set_option_value("wrap", true, { scope = "local" })
api.nvim_set_option_value("siso", 12, { scope = "local" })
api.nvim_set_option_value("spell", true, { scope = "local" })

vim.keymap.set("i", ",", ",<C-g>u", { silent = true, buffer = 0 })
vim.keymap.set("i", ".", ".<C-g>u", { silent = true, buffer = 0 })
vim.keymap.set("i", ":", ":<C-g>u", { silent = true, buffer = 0 })
vim.keymap.set("i", "-", "-<C-g>u", { silent = true, buffer = 0 })
vim.keymap.set("i", "?", "?<C-g>u", { silent = true, buffer = 0 })
vim.keymap.set("i", "!", "!<C-g>u", { silent = true, buffer = 0 })

vim.keymap.set("n", "gK", function()
    ut.check_word_under_cursor()
end)

-- TODO: Do we go back to prettier? Good for the README use case. Bad for notes
vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = vim.api.nvim_get_current_buf(),
    callback = function(ev)
        ut.fallback_formatter(ev.buf)
    end,
})

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
    if string.match(line, "%s*[-+*]%s+%[.%]") ~= nil then return true end
    if string.match(line, "%s*%d+[%.%)]%s+%[.%]") ~= nil then return true end
    return false
end

---@return nil
local function toggle_checkbox()
    if ut.is_in_node_type({ "fenced_code_block", "minus_metadata" }) then return end
    local row = api.nvim_win_get_cursor(0)[1] ---@type integer
    local line = api.nvim_buf_get_lines(0, row - 1, row, false)[1] ---@type string
    local unchecked = " " ---@type string
    local checked = "x" ---@type string
    local new_line = (function()
        if is_checkbox(line) then
            if string.match(line, "^.*%[[xX]%]") then
                return string.gsub(line, "%[[xX]%]", "[" .. unchecked .. "]", 1)
            else
                return string.gsub(line, "%[" .. unchecked .. "%]", "[" .. checked .. "]", 1)
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

-- TODO: Add bullets.vim
-- TODO: Markdown files take forever to open. Which plugin(s) are causing this?

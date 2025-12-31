local api = vim.api
local fn = vim.fn

local M = {}
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

-- TODO: The checkbox function should take an opt for which node types to exclude
-- - This would then allow for setting different exclusions by filetype. The docs should show an
-- example of using autocmds to map by ft
-- - One problem with doing it this way is, presumably, the defaults should be by ft to make sure
-- the right node types are being excluded. So let's say you only want to change for one ft. I
-- guess the solution then would have to be to make sure that the plugin's defaults map before the
-- user ftplugin file
-- TODO: Look at the new incremental selection PR to see how nested trees are handled

local function is_in_node_type(types)
    vim.validate("types", types, vim.islist)

    if #types < 1 then
        return false
    end

    local node = vim.treesitter.get_node() ---@type TSNode?
    while node do
        for _, type in ipairs(types) do
            if node:type() == type then
                return true
            end
        end

        node = node:parent()
    end

    return false
end

-- TODO: Creating a checkbox on a blank line should advance the cursor to the end of the line.
-- Could have an opt for if advancing happens, or if insert mode should be entered.

---@return nil
function M.toggle_checkbox()
    if is_in_node_type({ "fenced_code_block", "minus_metadata" }) then
        return
    end

    local row = fn.line(".")
    local line = api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    local unchecked = " "
    local checked = "x"
    local new_line = (function()
        if is_checkbox(line) then
            if string.match(line, "^.*%[[xX]%]") then
                local unchecked_part = "[" .. unchecked .. "]"
                return string.gsub(line, "%[[xX]%]", unchecked_part, 1)
            else
                local unchecked_part = "%[" .. unchecked .. "%]"
                local checked_part = "[" .. checked .. "]"
                return string.gsub(line, unchecked_part, checked_part, 1)
            end
        else
            local unordered_pat = "^(%s*)([-+*]) (.*)"
            local ordered_pat = "^(%s*)(%d+[%.%)]) (.*)"
            if string.match(line, unordered_pat) then
                return (string.gsub(line, unordered_pat, "%1%2 [ ] %3"))
            elseif string.match(line, ordered_pat) then
                return (string.gsub(line, ordered_pat, "%1%2 [ ] %3"))
            else
                return string.gsub(line, "^(%s*)", "%1- [ ] ")
            end
        end
    end)()

    api.nvim_buf_set_lines(0, row - 1, row, true, { new_line })
end

return M

-- TODO: Features to add:
-- - Dictionary/Thesaurus hover
--  - Require wordnet. Check if it's executable. Autoenable if so. Set to gK for dict
-- - Spellcheck picker
-- - Bullets
-- TODO: A semi-interesting question is - How do you configure the defaults. Could actually use
-- ftplugin files, since that guarantees they would act before user files. But that also means
-- the mappings need to be written a lot. But this of course begs the question - Isn't the user
-- then being asked to do the same?

-- This file is for maps and autocommands that don't change functionality, but are
-- simply meant to suppress command line nags

vim.keymap.set("n", "zg", "<cmd>silent norm! zg<cr>", { silent = true }) -- Stop cmd line nag

-- Done as functions because keymap <cmd>'s do not work with v:count1
vim.keymap.set("n", "u", function()
    if not ut.check_modifiable() then
        return
    end
    vim.api.nvim_exec2("silent norm! " .. vim.v.count1 .. "u", {})
end, { silent = true })
vim.keymap.set("n", "<C-r>", function()
    if not ut.check_modifiable() then
        return
    end
    vim.api.nvim_exec2('silent exec "norm! ' .. vim.v.count1 .. '\\<C-r>"', {})
end, { silent = true })

---@param direction string
---@return nil
local visual_indent = function(direction)
    local count = vim.v.count1
    vim.opt_local.cursorline = false
    vim.api.nvim_exec2('exec "silent norm! \\<esc>"', {})
    vim.api.nvim_exec2("silent '<,'> " .. string.rep(direction, count), {})
    vim.api.nvim_exec2("silent norm! gv", {})
    vim.opt_local.cursorline = true
end

vim.keymap.set("x", "<", function()
    visual_indent("<")
end, { silent = true })
vim.keymap.set("x", ">", function()
    visual_indent(">")
end, { silent = true })

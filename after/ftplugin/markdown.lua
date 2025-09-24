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

Map("i", ",", ",<C-g>u", { silent = true, buffer = true })
Map("i", ".", ".<C-g>u", { silent = true, buffer = true })
Map("i", ":", ":<C-g>u", { silent = true, buffer = true })
Map("i", "-", "-<C-g>u", { silent = true, buffer = true })
Map("i", "?", "?<C-g>u", { silent = true, buffer = true })
Map("i", "!", "!<C-g>u", { silent = true, buffer = true })

Map("n", "K", require("mjm.utils").check_word_under_cursor)

vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("md_save", { clear = true }),
    pattern = "*.md",
    callback = function(ev)
        require("mjm.utils").fallback_formatter(ev.buf)
    end,
})

-- FUTURE: For the future migration away from Obsidian
-- vim.opt.listchars:remove("multispace")
--
-- local map = vim.keymap.set
--
-- map("n", "<leader>x", function()
-- 	local line = vim.api.nvim_get_current_line()
--
-- 	if line:find("- [ ]", 1, true) then
-- 		line = line:gsub("- %b[]", "- [x]")
-- 		vim.api.nvim_set_current_line(line)
-- 	elseif line:find("- [x]", 1, true) then
-- 		line = line:gsub("- %b[]", "- [ ]")
-- 		vim.api.nvim_set_current_line(line)
-- 	end
-- end)
--
-- vim.o.foldlevel = 99
--
-- map("n", "~", function()
-- 	local line = vim.api.nvim_get_current_line()
-- 	local new_line
--
-- 	if line:find("~") then
-- 		new_line = line:gsub("~", "")
-- 	else
-- 		new_line = line:gsub("- (.+)", "- ~%1~")
-- 	end
--
-- 	vim.api.nvim_set_current_line(new_line)
-- end, { desc = "Toggle strikethrough" })

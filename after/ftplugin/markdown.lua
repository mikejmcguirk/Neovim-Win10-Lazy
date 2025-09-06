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
    callback = function(ev) require("mjm.utils").fallback_formatter(ev.buf) end,
})

vim.bo.tabstop = 2
vim.bo.softtabstop = 2
vim.bo.shiftwidth = 2

-- local xml_group = vim.api.nvim_create_augroup("xmlGroup", { clear = true })

-- Does not work properly
-- If a carat is present in a property's text, the vim regex will interpret this is the opening
-- of a new tab, and the indentation will be incorrect
-- vim.api.nvim_create_autocmd({ "BufWritePre" }, {
--     group = xml_group,
--     pattern = "*.xml",
--     callback = function()
--         local view = vim.fn.winsaveview()
--
--         vim.cmd([[%s/\s\+$//e]]) -- Remove trailing whitespace
--         vim.cmd([[%s/\n\+\%$//e]]) -- Remove trailing blank lines
--         vim.cmd([[%s/\%^\n\+//e]]) -- Remove leading blank lines
--
--         vim.cmd([[silent! normal! mzgg=G`z]])
--
--         vim.fn.winrestview(view)
--     end,
-- })

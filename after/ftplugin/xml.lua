vim.bo.tabstop = 2
vim.bo.softtabstop = 2
vim.bo.shiftwidth = 2
vim.bo.expandtab = true

local xml_group = vim.api.nvim_create_augroup("xmlGroup", { clear = true })

vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  group = xml_group,
  pattern = "*.xml",
  callback = function()
    local view = vim.fn.winsaveview()

    vim.cmd([[%s/\s\+$//e]])       -- Remove trailing whitespace
    vim.cmd([[%s/\n\+\%$//e]])     -- Remove trailing blank lines
    vim.cmd([[%s/\%^\n\+//e]])     -- Remove leading blank lines

    vim.cmd([[silent! normal! mzgg=G`z]])

    vim.fn.winrestview(view)
  end,
})

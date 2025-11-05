-- The plugin sets locals after filetype. Must schedule here to override
-- PR: Fix this
vim.schedule(function()
    vim.api.nvim_set_option_value("nu", true, { scope = "local" })
    vim.api.nvim_set_option_value("rnu", true, { scope = "local" })
end)

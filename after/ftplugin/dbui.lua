-- The plugin sets locals after filetype. Schedule here to override
-- PR: Fix this
-- TODO: This PR is open
vim.schedule(function()
    vim.api.nvim_set_option_value("nu", true, { scope = "local" })
    vim.api.nvim_set_option_value("rnu", true, { scope = "local" })
end)

-- Prevent ftplugin SQL Completion from mapping, since this causes wait on <C-c>
vim.api.nvim_buf_set_var(0, "did_ftplugin", 1)

-- TODO: Is there code in the SQL ftplugin worth keeping? Is it enough to remap C-c to <esc>ze with
-- nowait?

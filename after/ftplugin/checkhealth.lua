vim.api.nvim_set_option_value("cc", "", { scope = "local" })
vim.keymap.set("n", "q", "<cmd>bwipe<cr>", { buffer = 0 })

-- PR: Setting window opts for health is non-trivially difficult because the _check function does
-- not contain window info for the non-float case
-- Manually setting a q command is trivially easy to do to overwrite the default, rather than
-- submitting a PR to change the close command
-- Better to bundle these changes together into a broader health refactor

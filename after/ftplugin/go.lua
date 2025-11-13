-- TODO: WHy is the listchar three spaces?
-- LOW: This should be based on a global that is also used in the set file, you could use
-- bespoke opt set/replace/remove logic to create consistency

local new_lcs = "tab:   ,extends:»,precedes:«,nbsp:␣,trail:⣿" ---@type string
vim.api.nvim_set_option_value("lcs", new_lcs, { scope = "local" })
vim.api.nvim_set_option_value("et", false, { scope = "local" })
vim.api.nvim_set_option_value("ts", 4, { scope = "local" })
vim.api.nvim_set_option_value("sw", 4, { scope = "local" })
vim.api.nvim_set_option_value("sts", 0, { scope = "local" })

vim.keymap.set("n", "<leader>-e", "oif err!= nil {<cr>}<esc>O//<esc>")

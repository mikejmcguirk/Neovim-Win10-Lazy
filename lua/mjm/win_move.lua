-- local function win_move_wezterm(key, dir)
--     local curwin = vim.fn.winnr()
--     vim.cmd("wincmd " .. key)
--     if curwin == vim.fn.winnr() then
--         vim.fn.system("wezterm cli activate-pane-direction " .. dir)
--     end
-- end

-- TODO: tmux-navigator is simple enough that it can just be done here
-- This should be fixed in the future though, because it IS simple
-- Also, we want to add in special cases, like being in a telescope prompt

-- Because I have not put in enough research yet on how to make window/navigation integration
-- work between Wezterm and Neovim
-- if vim.fn.has("win64") == 1 then
--     vim.keymap.set("n", "<C-h>", function()
--         vim.cmd("wincmd h")
--     end, { silent = true })
--     vim.keymap.set("n", "<C-j>", function()
--         vim.cmd("wincmd j")
--     end, { silent = true })
--     vim.keymap.set("n", "<C-k>", function()
--         vim.cmd("wincmd k")
--     end, { silent = true })
--     vim.keymap.set("n", "<C-l>", function()
--         vim.cmd("wincmd l")
--     end, { silent = true })
-- else
--     vim.keymap.set("n", "<C-h>", function()
--         win_move_wezterm("h", "left")
--     end, { silent = true })
--     vim.keymap.set("n", "<C-j>", function()
--         win_move_wezterm("j", "down")
--     end, { silent = true })
--     vim.keymap.set("n", "<C-k>", function()
--         win_move_wezterm("k", "up")
--     end, { silent = true })
--     vim.keymap.set("n", "<C-l>", function()
--         win_move_wezterm("l", "right")
--     end, { silent = true })
-- end

-- TODO: This should be a different map, but I can't think of a better one
-- Using alt feels like an anti-pattern
vim.keymap.set("n", "<M-j>", "<cmd>resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-k>", "<cmd>resize +2<CR>", { silent = true })
vim.keymap.set("n", "<M-h>", "<cmd>vertical resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-l>", "<cmd>vertical resize +2<CR>", { silent = true })

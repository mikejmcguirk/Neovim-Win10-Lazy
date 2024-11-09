-- TODO: These should be able to tell if you're at the beginning of a line or not and
-- create the proper inputs accordingly
vim.keymap.set("n", "--T", "a---@type", { buffer = true })
vim.keymap.set("n", "--P", "a---@param", { buffer = true })
vim.keymap.set("n", "--R", "a---@return", { buffer = true })
vim.keymap.set("n", "--F", "a---@field", { buffer = true })
vim.keymap.set("n", "--A", "a--[[@as", { buffer = true })

-- local api = vim.api
local keymap = vim.keymap

--------------

require("annotator.plugin")
keymap.set("n", "<leader>-k", "<Plug>(annotator-add-mark)")
keymap.set("n", "<leader>-K", "<Plug>(annotator-add-borders)")
keymap.set("n", "<leader>fnk", "<Plug>(annotator-fzf-lua-grep-curbuf)")
keymap.set("n", "<leader>fnK", "<Plug>(annotator-fzf-lua-grep-cwd)")
keymap.set("n", "<leader>fnm", "<Plug>(annotator-fzf-lua-grep-curbuf-luacats)")
-- keymap.set("n", "<leader>qgk", "<Plug>(annotator-rancher-grep-cwd)")
-- keymap.set("n", "<leader>lgk", "<Plug>(annotator-rancher-grep-curbuf)")

--------------

keymap.set({ "n", "x" }, "y", function()
    return require("specops").yank()
end, { expr = true })

keymap.set({ "n", "x" }, "Y", function()
    return require("specops").yank() .. "$"
end, { expr = true })

keymap.set({ "n", "x" }, "<M-y>", function()
    return '"+' .. require("specops").yank()
end, { expr = true })

keymap.set({ "n", "x" }, "<M-Y>", function()
    return '"+' .. require("specops").yank() .. "$"
end, { expr = true })

-- local api = vim.api
local keymap = vim.keymap

-- local herder = require("qf-herder")
-- herder.config({
--     keymap = {
--         prefix_ll = "gl",
--         prefix_qf = "gq",
--     },
-- })

-- require("qf-herder.plugin")
-- keymap.set({ "n", "x" }, "gw", "gq")
-- keymap.set("n", "gww", "gqq")

-- api.nvim_create_autocmd("FileType", {
--     group = api.nvim_create_augroup("mjm.herder-tmp.ftplugin", {}),
--     callback = function()
--         require("qf-herder.qf").do_ftplugin()
--     end,
-- })

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

keymap.set("x", "p", "P")
keymap.set("x", "P", "p")
keymap.set("n", "<M-p>", '"+p')
keymap.set("n", "<M-P>", '"+P')
keymap.set("x", "<M-p>", '"+P')
keymap.set("x", "<M-P>", '"+p')

keymap.set("n", "[p", '<Cmd>exe "iput! " . v:register<CR>')
keymap.set("n", "]p", '<Cmd>exe "iput "  . v:register<CR>')
keymap.set("n", "[<M-p>", '<Cmd>exe "iput! " . "+"<CR>')
keymap.set("n", "]<M-p>", '<Cmd>exe "iput "  . "+"<CR>')

keymap.set({ "n", "x" }, "<M-d>", '"_d')
keymap.set({ "n", "x" }, "<M-D>", '"_D')
keymap.set({ "n", "x" }, "<M-c>", '"_c')
keymap.set({ "n", "x" }, "<M-C>", '"_C')

----------------

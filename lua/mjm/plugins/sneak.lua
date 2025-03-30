local ut = require("mjm.utils")

return {
    "justinmk/vim-sneak",
    dependencies = { "tpope/vim-repeat" },
    init = function()
        vim.cmd("let g:sneak#label = 1")

        vim.keymap.set("n", "<C-c>", function()
            pcall(function()
                vim.cmd("sneak#cancel()")
            end)

            return ut.clear_clutter()
        end, { expr = true, silent = true })
    end,
}

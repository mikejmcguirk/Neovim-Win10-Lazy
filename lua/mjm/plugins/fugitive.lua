local ut = require("mjm.utils")
return {
    "tpope/vim-fugitive",
    lazy = false,
    config = function()
        vim.keymap.set("n", "<leader>gd", "<cmd>botright Git diff<cr>")
        vim.keymap.set("n", "<leader>gc", function()
            local message = ut.get_input("Enter commit message (no quotes): ")
            if message == "" then
                vim.notify("Git commit aborted")
                return
            end

            vim.cmd('Git commit -a -m "' .. message .. '"')
        end)
    end,
}

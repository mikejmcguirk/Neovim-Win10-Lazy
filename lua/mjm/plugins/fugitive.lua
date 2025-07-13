local ut = require("mjm.utils")
return {
    "tpope/vim-fugitive",
    lazy = false,
    config = function()
        vim.keymap.set("n", "<leader>gd", function()
            for _, w in ipairs(vim.fn.getwininfo()) do
                if vim.api.nvim_get_option_value("filetype", { buf = w.bufnr }) == "git" then
                    return
                end
            end

            ut.close_all_loclists()
            vim.cmd("cclose")
            vim.cmd("botright Git diff")
        end)

        vim.keymap.set("n", "<leader>gc", function()
            local message = ut.get_input("Enter commit message (no quotes): ")
            if message == "" then
                return vim.notify("Git commit aborted")
            end

            vim.cmd('Git commit -a -m "' .. message .. '"')
        end)
    end,
}

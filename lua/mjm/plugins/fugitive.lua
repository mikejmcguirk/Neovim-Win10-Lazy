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

        vim.keymap.set("n", "<leader>gp", "<cmd>Git push<cr>")
        vim.keymap.set("n", "<leader>gca", function()
            local message = ut.get_input("Committing all. Enter message (no quotes): ")
            if message == "" then
                return vim.notify("Git commit aborted")
            end

            vim.cmd('Git commit -a -m "' .. message .. '"')
        end)

        vim.keymap.set("n", "<leader>gch", function()
            local message = ut.get_input("Committing staged hunks. Enter message (no quotes): ")
            if message == "" then
                return vim.notify("Git commit aborted")
            end

            vim.cmd('Git commit -m "' .. message .. '"')
        end)
    end,

    -- Various git commands:
    --- git reset -p | opens interactive mode for unstaging staged hunks
    --- git add -p | interactive mode for staging hunks
    --- git reset | unstage everything
    --- git reset [<file>] | unstage a file
    --- git reset --mixed HEAD~1 | undo last unpushed commit. use 2 and so on to go deeper
}

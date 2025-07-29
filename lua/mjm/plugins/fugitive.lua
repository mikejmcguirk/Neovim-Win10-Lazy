local ut = require("mjm.utils")

local function open_diff(opts)
    for _, w in ipairs(vim.fn.getwininfo()) do
        if vim.api.nvim_get_option_value("filetype", { buf = w.bufnr }) == "git" then
            return
        end
    end

    ut.close_all_loclists()
    vim.cmd("cclose")

    opts = opts or {}
    if opts.staged then
        vim.cmd("botright Git diff --staged")
    else
        vim.cmd("botright Git diff")
    end
end

vim.keymap.set("n", "<leader>gdd", function()
    open_diff()
end)

vim.keymap.set("n", "<leader>gds", function()
    open_diff({ staged = true })
end)

vim.keymap.set("n", "<leader>gp", "<cmd>Git push<cr>")
vim.keymap.set("n", "<leader>gca", function()
    local msg = ut.get_input("Committing all. Enter message (no quotes): ")
    if msg == "" then
        return vim.notify("Commit aborted: empty message")
    end

    local escaped_msg = vim.fn.escape(msg, '"\\')
    vim.cmd('Git commit -a -m "' .. escaped_msg .. '"')
end)

vim.keymap.set("n", "<leader>gch", function()
    local msg = ut.get_input("Committing staged hunks. Enter message: ")
    if msg == "" then
        return vim.notify("Git commit aborted")
    end

    local escaped_msg = vim.fn.escape(msg, '"\\')
    vim.cmd('Git commit -m "' .. escaped_msg .. '"')
end)

vim.keymap.set("n", "<leader>gcb", function()
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" then
        return vim.notify("No file in current buffer")
    end

    local msg = ut.get_input("Committing current buffer. Enter message: ")
    if msg == "" then
        return vim.notify("Commit aborted: empty message")
    end

    local escaped_msg = vim.fn.escape(msg, '"\\')
    local escaped_file = vim.fn.fnameescape(file)
    vim.cmd(string.format('Git commit -m "%s" -- %s', escaped_msg, escaped_file))
end)

-- Various git commands:
--- git reset -p | opens interactive mode for unstaging staged hunks
--- git add -p | interactive mode for staging hunks
--- git reset | unstage everything
--- git reset [<file>] | unstage a file
--- git reset --mixed HEAD~1 | undo last unpushed commit. use 2 and so on to go deeper

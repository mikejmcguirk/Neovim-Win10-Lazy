local ut = require("mjm.utils")

vim.cmd.packadd({ vim.fn.escape("vim-fugitive", " "), bang = true, magic = { file = false } })

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("git-diff-ts", { clear = true }),
    pattern = "git",
    callback = function()
        vim.api.nvim_cmd({ cmd = "set", args = { "filetype=diff" } }, {})
    end,
})

vim.keymap.set("n", "<leader>gcam", function()
    local msg = ut.get_input("Commit message (All): ")
    if msg == "" then
        return
    end

    vim.api.nvim_cmd({ cmd = "Git", args = { 'commit -a -m "' .. msg .. '"' } }, {})
end)

vim.keymap.set("n", "<leader>gcan", function()
    vim.api.nvim_cmd({ cmd = "Git", args = { "commit -a" } }, {})
end)

vim.keymap.set("n", "<leader>gchm", function()
    local msg = ut.get_input("Commit message: ")
    if msg == "" then
        return
    end

    vim.api.nvim_cmd({ cmd = "Git", args = { 'commit -m "' .. msg .. '"' } }, {})
end)

vim.keymap.set("n", "<leader>gchn", function()
    vim.api.nvim_cmd({ cmd = "Git", args = { "commit" } }, {})
end)

local function open_diffs(staged)
    for _, w in ipairs(vim.fn.getwininfo()) do
        if vim.api.nvim_get_option_value("filetype", { buf = w.bufnr }) == "diff" then
            return
        end
    end

    ut.close_all_loclists()
    vim.api.nvim_cmd({ cmd = "ccl" }, {})

    local mods = { split = "botright" }
    if staged then
        --- @diagnostic disable: missing-fields
        vim.api.nvim_cmd({ cmd = "Git", args = { "diff --staged" }, mods = mods }, {})
    else
        vim.api.nvim_cmd({ cmd = "Git", args = { "diff" }, mods = mods }, {})
    end
end

vim.keymap.set("n", "<leader>gdd", function()
    open_diffs()
end)

vim.keymap.set("n", "<leader>gds", function()
    open_diffs(true)
end)

vim.keymap.set("n", "<leader>ghU", function()
    local cur_buf = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
    vim.system({ "git", "restore", "--staged", cur_buf }, nil)
end)

vim.keymap.set("n", "<leader>gp", function()
    vim.api.nvim_cmd({ cmd = "Git", args = { "push" } }, {})
end)

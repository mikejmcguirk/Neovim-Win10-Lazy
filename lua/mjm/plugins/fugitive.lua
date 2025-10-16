--- TODO: Move to gg mappings

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("git-diff-ts", { clear = true }),
    pattern = "git",
    callback = function()
        vim.api.nvim_cmd({ cmd = "set", args = { "filetype=gitdiff" } }, {})
    end,
})

Map("n", "<leader>gcam", function()
    --- @type boolean, string
    local ok, result = require("mjm.utils").get_input("Commit message (All): ")
    if not ok then
        local msg = result or "Unknown error getting input" --- @type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    elseif result == "" then
        return
    end

    vim.api.nvim_cmd({ cmd = "Git", args = { 'commit -a -m "' .. result .. '"' } }, {})
end)

local commit_all = function()
    vim.api.nvim_cmd({ cmd = "Git", args = { "commit -a" } }, {})
end

Map("n", "<leader>gcan", commit_all)
Map("n", "<leader>gchm", function()
    local ok, result = require("mjm.utils").get_input("Commit message: ") --- @type boolean, string
    if not ok then
        local msg = result or "Unknown error getting input" --- @type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    elseif result == "" then
        return
    end

    vim.api.nvim_cmd({ cmd = "Git", args = { 'commit -m "' .. result .. '"' } }, {})
end)

Map("n", "<leader>gchn", function()
    vim.api.nvim_cmd({ cmd = "Git", args = { "commit" } }, {})
end)

local function open_diffs(staged)
    for _, w in ipairs(vim.fn.getwininfo()) do
        if vim.api.nvim_get_option_value("filetype", { buf = w.bufnr }) == "diff" then return end
    end

    local mods = { split = "botright" }
    if staged then
        --- @diagnostic disable: missing-fields
        vim.api.nvim_cmd({ cmd = "Git", args = { "diff --staged" }, mods = mods }, {})
    else
        vim.api.nvim_cmd({ cmd = "Git", args = { "diff" }, mods = mods }, {})
    end
end

Map("n", "<leader>gdd", function()
    open_diffs()
end)

Map("n", "<leader>gds", function()
    open_diffs(true)
end)

Map("n", "<leader>ghU", function()
    local cur_buf = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
    vim.system({ "git", "restore", "--staged", cur_buf }, nil)
end)

Map("n", "<leader>gp", function()
    vim.api.nvim_cmd({ cmd = "Git", args = { "push" } }, {})
end)

-- git reset --soft HEAD~1

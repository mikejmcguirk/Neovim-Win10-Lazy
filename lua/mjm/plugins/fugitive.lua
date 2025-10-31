local api = vim.api
local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

---@param all boolean
local function commit(all, msg)
    local args = "commit" .. (all and " -a" or "") ---@type string
    if msg then
        local prompt = "Commit message" .. (all and " (ALL)" or "") .. ": " ---@type string
        local ok, result = ut.get_input(prompt) ---@type boolean, string
        if not ok then
            ---@type [string, string|integer?]
            local chunk = { (result or "Unknown error getting input"), "ErrorMsg" }
            vim.api.nvim_echo({ chunk }, true, { err = true })
            return
        elseif result == "" then
            return
        end

        args = args .. ' -m "' .. result .. '"'
    end

    api.nvim_cmd({ cmd = "Git", args = { args } }, {})
end

vim.keymap.set("n", "<leader>gcam", function()
    commit(true, true)
end)

vim.keymap.set("n", "<leader>gcan", function()
    commit(true, false)
end)

vim.keymap.set("n", "<leader>gchm", function()
    commit(false, true)
end)

vim.keymap.set("n", "<leader>gchn", function()
    commit(false, false)
end)

local function open_diffs(staged)
    local tabpage = api.nvim_get_current_tabpage() ---@type integer
    local tabpage_wins = api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
    for _, win in ipairs(tabpage_wins) do
        local win_buf = api.nvim_win_get_buf(win) ---@type integer
        if api.nvim_get_option_value("filetype", { buf = win_buf }) == "diff" then return end
    end

    local ok, window = pcall(require, "qf-rancher.window") ---@type boolean, QfrWins?
    if ok and window then
        window.close_loclist(api.nvim_get_current_win())
        window.close_qflist()
    else
        vim.cmd("lclose | cclose")
    end

    local args = { "diff" .. (staged and " --staged" or "") } ---@type string[]
    ---@diagnostic disable-next-line: missing-fields
    vim.api.nvim_cmd({ cmd = "Git", args = args, mods = { split = "botright" } }, {})
end

vim.keymap.set("n", "<leader>gdd", function()
    open_diffs()
end)

vim.keymap.set("n", "<leader>gds", function()
    open_diffs(true)
end)

vim.keymap.set("n", "<leader>gp", function()
    vim.api.nvim_cmd({ cmd = "Git", args = { "push" } }, {})
end)

vim.keymap.set("n", "<leader>gR", function()
    local ok, input = ut.get_input("reset --soft HEAD~1 ? [y/n]: ") ---@type boolean, string
    if not ok then
        ---@type [string, string|integer?]
        local chunk = { (input or "Unknown error getting input"), "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return
    elseif input == "" then
        return
    end

    input = string.sub(string.lower(input), 1, 1)
    if input ~= "y" then return end
    api.nvim_cmd({ cmd = "Git", args = { "reset --soft HEAD~1" } }, {})
end)

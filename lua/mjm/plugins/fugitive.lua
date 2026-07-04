local api = vim.api
local set = vim.keymap.set

---@param all boolean
local function commit(all, msg)
    local args = "commit" .. (all and " -a" or "")
    if msg then
        local prompt = "Commit message" .. (all and " (ALL)" or "") .. ": "
        local ok, result = require("nvim-tools.ui").input({ prompt = prompt })
        if not ok then
            local chunks = { (result or "Unknown error getting input"), "ErrorMsg" }
            api.nvim_echo({ chunks }, true, { err = true })
            return
        elseif result == "" then
            return
        end

        args = args .. ' -m "' .. result .. '"'
    end

    api.nvim_cmd({ cmd = "Git", args = { args } }, {})
end

---@param staged boolean?
---@return nil
local function open_diffs(staged)
    local tabpage = api.nvim_get_current_tabpage()
    local tabpage_wins = api.nvim_tabpage_list_wins(tabpage)
    for _, win in ipairs(tabpage_wins) do
        local win_buf = api.nvim_win_get_buf(win) ---@type integer
        if api.nvim_get_option_value("filetype", { buf = win_buf }) == "diff" then
            return
        end
    end

    local ok, window = pcall(require, "qf-rancher.window")
    if ok and window then
        window.close_ll_win(api.nvim_get_current_win())
        window.close_qf_win()
    else
        vim.cmd("lclose | cclose")
    end

    local args = { "diff" .. (staged and " --staged" or "") }
    ---@diagnostic disable-next-line: missing-fields
    api.nvim_cmd({ cmd = "Git", args = args, mods = { split = "botright" } }, {})
end

---@return nil
local function setup_fugitive()
    set("n", "<leader>gcam", function()
        commit(true, true)
    end)

    set("n", "<leader>gcan", function()
        commit(true, false)
    end)

    set("n", "<leader>gchm", function()
        commit(false, true)
    end)

    set("n", "<leader>gchn", function()
        commit(false, false)
    end)

    set("n", "<leader>gdd", function()
        open_diffs()
    end)

    set("n", "<leader>gds", function()
        open_diffs(true)
    end)

    set("n", "<leader>gp", function()
        api.nvim_cmd({ cmd = "Git", args = { "push" } }, {})
    end)

    set("n", "<leader>gR", function()
        local ntu = require("nvim-tools.ui")
        ---@type boolean, string
        local ok, input = ntu.input({ prompt = "reset --soft HEAD~1 ? [y/n]: " })
        if not ok then
            local err = input or "Unknown error getting input"
            api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
            return
        elseif input == "" then
            return
        end

        input = string.sub(string.lower(input), 1, 1)
        if input ~= "y" then
            return
        end
        api.nvim_cmd({ cmd = "Git", args = { "reset --soft HEAD~1" } }, {})
    end)
end

return {
    "tpope/vim-fugitive",
    config = function()
        setup_fugitive()
    end,
}

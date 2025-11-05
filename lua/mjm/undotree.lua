local api = vim.api

vim.api.nvim_cmd({ cmd = "packadd", args = { "nvim.undotree" }, bang = true }, {})

vim.keymap.set("n", "<leader>u", function()
    local win_width = api.nvim_win_get_width(api.nvim_get_current_win()) ---@type integer
    local open_width = math.floor(win_width * 0.3) ---@type integer
    open_width = math.max(open_width, 30) ---@type integer
    local command = open_width .. "vnew" ---@type string

    require("undotree").open({ command = command })
end)

local api = vim.api

-- MID: Need to run without bang because otherwise lazy doesn't allow the plugin file to source
api.nvim_cmd({ cmd = "packadd", args = { "nvim.undotree" } }, {})
vim.keymap.set("n", "<leader>u", function()
    local width = api.nvim_win_get_width(0) ---@type integer
    local partial_width = math.floor(width * 0.3) ---@type integer
    local capped_width = math.max(partial_width) ---@type integer
    local cmd = capped_width .. "vnew" ---@type string
    require("undotree").open({ command = cmd })
end)

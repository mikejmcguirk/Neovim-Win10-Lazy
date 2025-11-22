local api = vim.api

-- TODO: Need to run without bang because otherwise lazy doesn't allow the plugin file to source
api.nvim_cmd({ cmd = "packadd", args = { "nvim.undotree" } }, {})
vim.keymap.set("n", "<leader>u", function()
    local width = api.nvim_win_get_width(api.nvim_get_current_win()) ---@type integer
    require("undotree").open({ command = math.max(math.floor(width * 0.3), 30) .. "vnew" })
end)

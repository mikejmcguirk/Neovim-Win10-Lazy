local api = vim.api

api.nvim_cmd({ cmd = "packadd", args = { "nvim.undotree" }, bang = true }, {})
vim.keymap.set("n", "<leader>u", function()
    local width = api.nvim_win_get_width(api.nvim_get_current_win()) ---@type integer
    require("undotree").open({ command = math.max(math.floor(width * 0.3), 30) .. "vnew" })
end)

-- PR: The nvim_is_undotree b:var seems unnecessary with the nvim-undotree filetype
-- PR: The open function returns true in a couple places, but not at the end, and no annotation

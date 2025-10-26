vim.api.nvim_set_var("db_ui_use_nerd_fonts", 1)

vim.api.nvim_set_var("qs_highlight_on_keys", { "f", "F", "t", "T" })
vim.api.nvim_set_var("qs_max_chars", 9999)
vim.api.nvim_set_hl(0, "QuickScopePrimary", { reverse = true })
vim.api.nvim_set_hl(0, "QuickScopeSecondary", { undercurl = true })

vim.keymap.set("n", "<leader>u", function()
    local win_width = vim.api.nvim_win_get_width(vim.api.nvim_get_current_win()) ---@type integer
    local open_width = math.floor(win_width * 0.3) ---@type integer
    open_width = math.max(open_width, 30) ---@type integer
    local command = open_width .. "vnew" ---@type string

    ---@diagnostic disable-next-line: missing-fields
    require("undotree").open({ command = command })
end)

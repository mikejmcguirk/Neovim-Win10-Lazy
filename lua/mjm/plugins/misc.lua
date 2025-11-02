local api = vim.api

api.nvim_set_var("db_ui_use_nerd_fonts", 1)

api.nvim_set_var("qs_highlight_on_keys", { "f", "F", "t", "T" })
api.nvim_set_var("qs_max_chars", 9999)
api.nvim_set_hl(0, "QuickScopePrimary", { reverse = true })
api.nvim_set_hl(0, "QuickScopeSecondary", { undercurl = true })

vim.keymap.set("n", "<leader>u", function()
    local win_width = api.nvim_win_get_width(api.nvim_get_current_win()) ---@type integer
    local open_width = math.floor(win_width * 0.3) ---@type integer
    open_width = math.max(open_width, 30) ---@type integer
    local command = open_width .. "vnew" ---@type string

    require("undotree").open({ command = command })
end)

api.nvim_set_var("qfr_debug_assertions", true)
api.nvim_set_var("qfr_preview_debounce", 50)
api.nvim_set_var("qfr_preview_show_title", false)

vim.keymap.set("n", "[<M-q>", "<Plug>(qfr-qf-older)")
vim.keymap.set("n", "]<M-q>", "<Plug>(qfr-qf-newer)")
vim.keymap.set("n", "[<M-l>", "<Plug>(qfr-ll-older)")
vim.keymap.set("n", "]<M-l>", "<Plug>(qfr-ll-newer)")

api.nvim_set_var("matchup_mappings_enabled", 0)
api.nvim_set_var("matchup_mouse_enabled", 0)
api.nvim_set_var("matchup_text_obj_enabled", 0)
api.nvim_set_var("matchup_delim_nomids", 1)
api.nvim_set_var("matchup_matchparen_nomode", "i")
api.nvim_set_var("matchup_matchparen_offscreen", {})
api.nvim_set_var("matchup_treesitter_disable_virtual_text", true)
vim.keymap.set({ "n", "x" }, "%", "<plug>(matchup-%)")

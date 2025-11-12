-- MAYBE: One strike - Had InsertLeave autocmd error
return {
    "andymass/vim-matchup",
    event = { "BufNewFile", "BufReadPre" },
    init = function()
        vim.api.nvim_set_var("matchup_delim_nomids", 1)
        vim.api.nvim_set_var("matchup_mappings_enabled", 0)
        vim.api.nvim_set_var("matchup_matchparen_nomode", "i")
        vim.api.nvim_set_var("matchup_matchparen_offscreen", {})
        vim.api.nvim_set_var("matchup_mouse_enabled", 0)
        vim.api.nvim_set_var("matchup_text_obj_enabled", 0)
        vim.api.nvim_set_var("matchup_treesitter_disable_virtual_text", true)

        vim.keymap.set({ "n", "x" }, "%", "<plug>(matchup-%)")
    end,
}

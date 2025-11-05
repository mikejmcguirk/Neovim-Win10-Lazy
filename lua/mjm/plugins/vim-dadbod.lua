return {
    "tpope/vim-dadbod",
    dependencies = { "kristijanhusak/vim-dadbod-ui" },
    init = function()
        vim.api.nvim_set_var("db_ui_use_nerd_fonts", 1)
    end,
}

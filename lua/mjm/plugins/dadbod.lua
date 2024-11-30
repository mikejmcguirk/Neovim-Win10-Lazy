return {
    {
        "kristijanhusak/vim-dadbod-ui",
        dependencies = { "tpope/vim-dadbod" },
        lazy = true,
        cmd = {
            "DBUI",
            "DBUIToggle",
            "DBUIAddConnection",
            "DBUIFindBuffer",
        },
        init = function()
            -- TODO: Set dadbod UI so that it has rnu set in all its windows by default
            vim.g.db_ui_use_nerd_fonts = 1
        end,
    },
}

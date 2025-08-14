vim.api.nvim_create_user_command("Dadbod", function()
    vim.cmd("tabnew")
    vim.cmd("DBUI")
    vim.cmd("set rnu")
end, {})

vim.api.nvim_create_user_command("DBUI", function()
    vim.api.nvim_del_user_command("DBUI")

    vim.g.db_ui_use_nerd_fonts = 1

    require("mjm.pack").post_load("vim-dadbod")
    require("mjm.pack").post_load("vim-dadbod-ui")
    require("mjm.pack").post_load("vim-dadbod-completion")

    vim.cmd("DBUI")
end, {})

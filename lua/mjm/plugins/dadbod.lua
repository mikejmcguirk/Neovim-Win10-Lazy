vim.g.db_ui_use_nerd_fonts = 1

vim.api.nvim_create_user_command("Dadbod", function()
    vim.cmd("tabnew")
    vim.cmd("DBUI")
    vim.cmd("set rnu")
end, {})

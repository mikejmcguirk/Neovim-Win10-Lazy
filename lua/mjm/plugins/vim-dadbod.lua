local api = vim.api
local fn = vim.fn

return {
    "tpope/vim-dadbod",
    dependencies = { "kristijanhusak/vim-dadbod-ui" },
    init = function()
        api.nvim_set_var("db_ui_use_nerd_fonts", 1)
        api.nvim_create_user_command("Dadbod", function()
            -- This cannot be a scratch buf per se, as DBUI will not use it as a query window.
            -- - Do not set scratchbuf == true in nvim_create_buf
            -- - Setting buftype to nofile also seems to create the [Scratch] labeling
            -- DBUI query buffers must be saveable (buftype cannot be nofile).
            local ntb = require("nvim-tools.buf")
            local db_buf = ntb.create_temp_buf("hide", true, "", "", false)
            local db_opt = { buf = db_buf }
            api.nvim_set_option_value("bufhidden", "wipe", db_opt)
            api.nvim_set_option_value("swapfile", false, db_opt)
            api.nvim_set_option_value("undofile", false, db_opt)

            api.nvim_open_tabpage(db_buf, true, { after = fn.tabpagenr("$") })
            api.nvim_cmd({ cmd = "DBUI" }, {})
        end, {})
    end,
}
-- MID: You cannot use "q" to exit the results window, instead needing "gq". Why is this? Re-enable
-- q if possible.

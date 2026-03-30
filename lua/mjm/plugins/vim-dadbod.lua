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
            local db_buf = api.nvim_create_buf(true, false)
            api.nvim_set_option_value("bufhidden", "wipe", { buf = db_buf })
            api.nvim_set_option_value("swapfile", false, { buf = db_buf })
            api.nvim_set_option_value("undofile", false, { buf = db_buf })

            api.nvim_open_tabpage(db_buf, true, { after = fn.tabpagenr("$") })
            api.nvim_cmd({ cmd = "DBUI" }, {})
        end, {})
    end,
}

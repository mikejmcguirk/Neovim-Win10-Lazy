local config = require("session_manager.config")
local path = require("plenary.path")

require("session_manager").setup({
    sessions_dir = path:new(vim.fn.stdpath("data"), "sessions"),
    autoload_mode = config.AutoloadMode.Disabled,
    -- autoload_mode = config.AutoloadMode.LastSession,
    autosave_last_session = true,
    autosave_ignore_not_normal = true,
    autosave_ignore_dirs = {},
    autosave_ignore_filetypes = {
        "gitcommit",
        "gitrebase",
    },
    autosave_ignore_buftypes = {},
    autosave_only_in_session = false,
    max_path_length = 0,
    load_include_current = false,
})

vim.keymap.set("n", "g\\ss", function()
    require("session_manager").save_current_session()
end)

vim.keymap.set("n", "g\\sl", function()
    require("session_manager").load_current_dir_session(false)
end)

vim.keymap.set("n", "g\\sd", function()
    require("session_manager").delete_session()
end)

-- TODO: This plugin uses the deprecated nvim_buf_set_option function

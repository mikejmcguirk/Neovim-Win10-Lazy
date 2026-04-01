local api = vim.api
local set = vim.keymap.set

local buf_0 = { buf = 0 }
-- Now that I have omni_sql_no_default_maps set, letting default ftplugin run again
-- vim.api.nvim_set_option_value("comments", ":--", { buf = 0 })
-- vim.api.nvim_set_option_value("commentstring", "-- %s", { buf = 0 })

set("n", mjm.v.fmt_lhs, function()
    require("mjm.utils").fallback_formatter(0)
end, buf_0)

api.nvim_create_autocmd("BufWritePre", {
    buffer = 0,
    callback = function(ev)
        require("mjm.utils").fallback_formatter(ev.buf)
    end,
})

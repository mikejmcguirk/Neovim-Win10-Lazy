local api = vim.api
local fn = vim.fn

vim.keymap.set("n", "q", "<cmd>lua require('undotree').open()<cr>", { buffer = true })
-- PR: The undotree plugin should provide a hook to do this. Do so in the open opts I think
-- PR: Slightly better would be - The module should know the buf the tree is attached to, and we
-- should be able to use win_findbuf() rather than a bespoke iteration
-- PR: Navigating the tree adds a lot of entries to the undolist. Possible way to mitigate?
api.nvim_create_autocmd("CursorMoved", {
    buffer = 0,
    callback = function()
        for i = 1, fn.winnr("$") do
            local win = fn.win_getid(i) ---@type integer
            if vim.b[api.nvim_win_get_buf(win)].nvim_undotree then
                api.nvim_win_call(win, function()
                    local cur_line = fn.line(".") ---@type integer
                    if not (fn.line("w0") <= cur_line and cur_line <= fn.line("w$")) then
                        api.nvim_cmd({ cmd = "norm", args = { "zz" }, bang = true }, {})
                    end
                end)
            end
        end
    end,
})

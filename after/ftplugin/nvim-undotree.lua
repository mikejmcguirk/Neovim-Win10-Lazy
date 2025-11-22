local api = vim.api
local fn = vim.fn

vim.keymap.set("n", "q", "<cmd>lua require('undotree').open()<cr>", { buffer = true })
api.nvim_create_autocmd("CursorMoved", {
    buffer = 0,
    callback = function()
        for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
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

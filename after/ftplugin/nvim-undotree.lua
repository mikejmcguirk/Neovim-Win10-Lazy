local api = vim.api
local fn = vim.fn

vim.keymap.set("n", "q", "<cmd>lua require('undotree').open()<cr>", { buffer = 0 })

-- MAYBE: Could cache this, but don't see a perf issue in practice
api.nvim_create_autocmd("CursorMoved", {
    buffer = 0,
    callback = function()
        local wins = api.nvim_tabpage_list_wins(0) ---@type integer[]
        for _, win in ipairs(wins) do
            local buf = api.nvim_win_get_buf(win) ---@type integer
            if vim.b[buf].nvim_undotree then
                api.nvim_win_call(win, function()
                    local cur_line = fn.line(".") ---@type integer
                    local top = fn.line("w0") ---@type integer
                    local bot = fn.line("w$") ---@type integer
                    if not (top <= cur_line and cur_line <= bot) then
                        api.nvim_cmd({ cmd = "norm", args = { "zz" }, bang = true }, {})
                    end
                end)
            end
        end
    end,
})

local api = vim.api

local mjm_group = api.nvim_create_augroup("mjm-group", {})
api.nvim_create_autocmd("BufWinEnter", {
    group = mjm_group,
    callback = function(ev)
        local win = api.nvim_get_current_win()
        local config = api.nvim_win_get_config(win)
        if (config.relative and #config.relative > 0) or config.hide then
            return
        end

        local bt = api.nvim_get_option_value("bt", { buf = ev.buf }) ---@type string
        if bt ~= "" then
            return
        end

        local cursor = api.nvim_win_get_cursor(win)
        if not (cursor[1] == 1 and cursor[2] == 0) then
            return
        end

        local mark = api.nvim_buf_get_mark(ev.buf, '"')
        if mark[1] == 1 and mark[2] == 0 then
            return
        end

        require("nvim-tools.win").protected_set_cursor(win, mark)
        api.nvim_win_call(win, function()
            api.nvim_cmd({ cmd = "norm", args = { "zz" }, bang = true }, {})
        end)
    end,
})

api.nvim_create_autocmd("TextYankPost", {
    group = mjm_group,
    callback = function()
        vim.hl.hl_op({ higroup = "IncText", timeout = 175 })
    end,
})

api.nvim_create_autocmd("TextPutPost", {
    group = mjm_group,
    callback = function()
        vim.hl.hl_op({ higroup = "Number", timeout = 175 })
    end,
})

api.nvim_create_autocmd("VimLeavePre", {
    group = mjm_group,
    callback = function()
        vim.fn.setreg("/", "")
    end,
})

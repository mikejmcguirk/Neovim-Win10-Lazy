local api = vim.api

local mjm_group = api.nvim_create_augroup("mjm-group", {})

local clear_conditions = {
    "BufEnter",
    "CmdlineEnter",
    "InsertEnter",
    "RecordingEnter",
    "TabLeave",
    "TabNewEntered",
    "WinEnter",
    "WinLeave",
} ---@type string[]

api.nvim_create_autocmd(clear_conditions, {
    group = mjm_group,
    pattern = "*",
    -- The highlight state is saved and restored when autocmds are triggered, so
    -- schedule_wrap is used to trigger nohlsearch aftewards
    -- See nohlsearch() help
    callback = vim.schedule_wrap(function()
        api.nvim_cmd({ cmd = "nohlsearch" }, {})
    end),
})

api.nvim_create_autocmd("BufWinEnter", {
    group = mjm_group,
    callback = function(ev)
        local win = api.nvim_get_current_win() ---@type integer
        local config = api.nvim_win_get_config(win) ---@type vim.api.keyset.win_config_ret
        if config.relative and #config.relative > 0 then
            return
        end

        local bt = api.nvim_get_option_value("bt", { buf = ev.buf }) ---@type string
        if bt ~= "" then
            return
        end

        local cursor = api.nvim_win_get_cursor(win) ---@type { [1]:integer, [2]:integer }
        if not (cursor[1] == 1 and cursor[2] == 0) then
            return
        end

        local mark = api.nvim_buf_get_mark(ev.buf, '"') ---@type { [1]:integer, [2]:integer }
        if mark[1] == 1 and mark[2] == 0 then
            return
        end

        mjm.protected_set_cursor(mark, { win = win })
        api.nvim_win_call(win, function()
            api.nvim_cmd({ cmd = "norm", args = { "zz" }, bang = true }, {})
        end)
    end,
})

-- MAYBE: Add a an autocmd to automatically chmod+x bash scripts

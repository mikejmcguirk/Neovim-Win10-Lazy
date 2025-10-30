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
    desc = "Go to the last cursor position when opening a buffer",
    callback = function(ev)
        local mark = api.nvim_buf_get_mark(ev.buf, '"')
        if mark[1] < 1 or mark[1] > api.nvim_buf_line_count(ev.buf) then return end
        api.nvim_cmd({ cmd = "normal", args = { 'g`"zz' }, bang = true }, {})
    end,
})

-- MAYBE: Add a an autocmd to automatically chmod+x bash scripts

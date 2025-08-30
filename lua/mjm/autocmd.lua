-- FUTURE: It would be good to have an autocmd where, if the file was last opened within the
-- past week, you go to where you left off, but after that it just goes fresh to the top
-- FUTURE: https://github.com/ibhagwan/nvim-lua/blob/main/lua/autocmd.lua
-- autocmd for smart yank over SSH

-- vim.api.nvim_create_autocmd("TextYankPost", {
--     group = vim.api.nvim_create_augroup("yank_highlight", { clear = true }),
--     pattern = "*",
--     callback = function()
--         -- vim.hl.on_yank({
--         --     higroup = "IncSearch",
--         --     timeout = Highlight_Time,
--         -- })
--         -- vim.fn.confirm("we yanked")
--     end,
-- })

local mjm_group = vim.api.nvim_create_augroup("mjm", { clear = true })
vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group = mjm_group,
    pattern = ".bashrc_custom",
    callback = function()
        vim.api.nvim_cmd({ cmd = "set", args = { "filetype=sh" } }, {})
    end,
})

local clear_conditions = {
    "BufEnter",
    "CmdlineEnter",
    -- "InsertEnter",
    "RecordingEnter",
    "TabLeave",
    "TabNewEntered",
    "WinEnter",
    "WinLeave",
} ---@type string[]

vim.api.nvim_create_autocmd(clear_conditions, {
    group = mjm_group,
    pattern = "*",
    -- The highlight state is saved and restored when autocmds are triggered, so
    -- schedule_wrap is used to trigger nohlsearch aftewards
    -- See nohlsearch() help
    callback = vim.schedule_wrap(function()
        vim.cmd.nohlsearch()
    end),
})

-- Buffer local option
-- See help fo-table
vim.api.nvim_create_autocmd({ "FileType" }, {
    group = mjm_group,
    pattern = "*",
    callback = function(ev)
        vim.opt.formatoptions:remove("o")

        if not ev.match == "markdown" then
            -- "r" in Markdown treats lines like "- some text" as comments and indents them
            vim.opt.formatoptions:append("r")
        end
    end,
})

vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    group = mjm_group,
    pattern = "*",
    callback = function()
        vim.fn.setreg("/", nil)
    end,
})

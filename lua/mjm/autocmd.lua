-- FUTURE: It would be good to have an autocmd where, if the file was last opened within the
-- past week, you go to where you left off, but after that it just goes fresh to the top
-- FUTURE: https://github.com/ibhagwan/nvim-lua/blob/main/lua/autocmd.lua
-- autocmd for smart yank over SSH

vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("yank_highlight", { clear = true }),
    pattern = "*",
    callback = function()
        vim.hl.on_yank({
            higroup = "IncSearch",
            timeout = Highlight_Time,
        })
    end,
})

local match_control = vim.api.nvim_create_augroup("match_control", { clear = true })
local no_match = {
    "TelescopePrompt",
    "git",
    "fzflua_backdrop",
    "help",
    "fzf",
    "query",
}
-- When doing vim.fn.matchadd, the scopes seem to get mixed up between different windows
-- By using the cmd, the highlights disappear on WinLeave as they should

vim.api.nvim_create_autocmd({ "WinNew", "WinEnter" }, {
    group = match_control,
    pattern = "*",
    callback = function(ev)
        local is_insert = string.match(vim.fn.mode(), "i") -- Don't match in blink windows
        local is_no_match_buf = vim.tbl_contains(no_match, vim.bo[ev.buf].filetype)
        if is_insert or is_no_match_buf then
            return
        end
        vim.cmd([[match EolSpace /\s\+$/]])
    end,
})

vim.api.nvim_create_autocmd("WinLeave", {
    group = match_control,
    pattern = "*",
    callback = function()
        for _, match in ipairs(vim.fn.getmatches()) do
            if match.group == "EolSpace" then
                vim.fn.matchdelete(match.id)
                return
            end
        end
    end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
    group = match_control,
    pattern = "*:n",
    callback = function(ev)
        if vim.tbl_contains(no_match, vim.bo[ev.buf].filetype) then
            return
        end
        vim.cmd([[match EolSpace /\s\+$/]])
    end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
    group = match_control,
    pattern = "n:*",
    callback = function()
        for _, match in ipairs(vim.fn.getmatches()) do
            if match.group == "EolSpace" then
                vim.fn.matchdelete(match.id)
                return
            end
        end
    end,
})

local mjm_group = vim.api.nvim_create_augroup("mjm", { clear = true })
vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group = mjm_group,
    pattern = ".bashrc_custom",
    command = "set filetype=sh",
})

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

        if not vim.api.nvim_get_option_value("filetype", { buf = ev.buf }) == "markdown" then
            -- "r" in Markdown treats "- some text" as a comment and indents them
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

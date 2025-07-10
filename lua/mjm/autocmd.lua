vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("yank_highlight", { clear = true }),
    pattern = "*",
    callback = function()
        vim.hl.on_yank({
            higroup = "IncSearch",
            timeout = 175,
        })
    end,
})

local match_control = vim.api.nvim_create_augroup("match_control", { clear = true })
local no_match = { "TelescopePrompt", "git" }
-- When doing vim.fn.matchadd, the scopes seem to get mixed up between different windows
-- By using the cmd, the highlights disappear on WinLeave as they should

vim.api.nvim_create_autocmd({ "WinNew", "WinEnter" }, {
    group = match_control,
    pattern = "*",
    callback = function()
        if not vim.tbl_contains(no_match, vim.bo.filetype) then
            vim.cmd([[match EolSpace /\s\+$/]])
        end
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
    callback = function()
        if not vim.tbl_contains(no_match, vim.bo.filetype) then
            vim.cmd([[match EolSpace /\s\+$/]])
        end
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
}

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
    callback = function()
        vim.opt.formatoptions:remove("o")
        vim.opt.formatoptions:append("r")
    end,
})

vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    group = mjm_group,
    pattern = "*",
    callback = function()
        vim.fn.setreg("/", nil)
    end,
})

-- TODO: This should check the last file read date and just go to the beginning of the file
-- if it was a week or so ago
vim.api.nvim_create_autocmd("BufReadPost", {
    group = mjm_group,
    desc = "Go to the last location when opening a buffer",
    callback = function(ev)
        local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
        if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
            vim.cmd('normal! g`"zz')
        end
    end,
})

-- From MariasolOs
vim.api.nvim_create_autocmd(
    { "BufEnter", "FocusGained", "InsertLeave", "CmdlineLeave", "WinEnter" },
    {
        group = mjm_group,
        desc = "Toggle relative line numbers on",
        callback = function()
            if vim.wo.nu and not vim.startswith(vim.api.nvim_get_mode().mode, "i") then
                vim.wo.relativenumber = true
            end
        end,
    }
)

vim.api.nvim_create_autocmd(
    { "BufLeave", "FocusLost", "InsertEnter", "CmdlineEnter", "WinLeave" },
    {
        group = mjm_group,
        desc = "Toggle relative line numbers off",
        callback = function(args)
            if vim.wo.nu then
                vim.wo.relativenumber = false
            end

            -- Redraw here to avoid having to first write something for the line numbers to update.
            if args.event == "CmdlineEnter" then
                if not vim.tbl_contains({ "@", "-" }, vim.v.event.cmdtype) then
                    vim.cmd("redraw")
                end
            end
        end,
    }
)

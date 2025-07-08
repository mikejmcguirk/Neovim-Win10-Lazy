vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("yank_aesthetic", { clear = true }),
    pattern = "*",
    callback = function()
        vim.cmd("echo ''")
        vim.hl.on_yank({
            higroup = "IncSearch",
            timeout = 150,
        })
    end,
})

local match_control = vim.api.nvim_create_augroup("match_control", { clear = true })

vim.api.nvim_create_autocmd("WinNew", {
    group = match_control,
    pattern = "*",
    callback = function()
        if vim.bo.filetype ~= "TelescopePrompt" then
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

vim.api.nvim_create_autocmd("ModeChanged", {
    group = match_control,
    pattern = "*:n",
    callback = function()
        if vim.bo.filetype ~= "TelescopePrompt" then
            vim.cmd([[match EolSpace /\s\+$/]])
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
    -- schedule_warp is used to trigger nohlsearch aftewards
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
    end,
})

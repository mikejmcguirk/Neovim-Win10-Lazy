local yankGroup = vim.api.nvim_create_augroup("HighlightYank", { clear = true })
local mjmGroup = vim.api.nvim_create_augroup("mjm", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
    group = yankGroup,
    pattern = "*",
    callback = function()
        vim.highlight.on_yank({
            higroup = "IncSearch",
            timeout = 200,
        })
    end,
})

vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = mjmGroup,
    pattern = "*",
    callback = function()
        -- if vim.bo.filetype == "xml" then -- Controlled through ftplugin file
        --     return
        -- end

        vim.cmd([[normal! mz]])

        vim.cmd([[%s/\s\+$//e]])   -- Remove trailing whitespace
        vim.cmd([[%s/\n\+\%$//e]]) -- Remove trailing blank lines
        vim.cmd([[%s/\%^\n\+//e]]) -- Remove leading blank lines

        vim.cmd([[silent! normal! `z]])
    end,
})

-- Auto-removes boilerplate status messages from the command line
vim.api.nvim_create_autocmd({ "TextYankPost", "BufWritePost", "TextChanged", }, {
    group = mjmGroup,
    pattern = "*",
    callback = function()
        vim.cmd([[normal! :<esc>]])
    end,
})

-- Removes executed commands from the command line
-- Uses print() to avoid a bug where <cmd><backspace> exits vim without saving
vim.api.nvim_create_autocmd({ "CmdlineLeave" }, {
    group = mjmGroup,
    pattern = "*",
    callback = function()
        print(" ")
    end,
})

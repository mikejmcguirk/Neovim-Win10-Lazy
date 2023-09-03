local augroup = vim.api.nvim_create_augroup

local yankGroup = augroup("HighlightYank", { clear = true })
local aleGroup = vim.api.nvim_create_augroup("aleGroup", { clear = true })
local mjmGroup = augroup("mjm", { clear = true })

local autocmd = vim.api.nvim_create_autocmd

autocmd("TextYankPost", {
    group = yankGroup,
    pattern = "*",
    callback = function()
        vim.highlight.on_yank({
            higroup = "IncSearch",
            timeout = 200,
        })
    end,
})


-- autocmd({"BufWritePre"}, {
--     group = aleGroup,
--     pattern = { "*.md", "*.json"},
--     callback = function()
--         vim.cmd([[ALEFix]])
--     end,
-- })

autocmd({"BufWritePre"}, {
    group = mjmGroup,
    pattern = "*",
    callback = function()
        -- The winsaveview() code handles edge cases where the view is reset to the top of the file
        local l = vim.fn.winsaveview()
        vim.cmd([[normal! mz]])

        vim.cmd([[%s/\s\+$//e]]) -- Remove trailing whitespace
        vim.cmd([[%s/\n\+\%$//e]]) -- Remove trailing blank lines
        vim.cmd([[%s/\%^\n\+//e]]) -- Remove leading blank lines

        vim.cmd([[silent! normal! `z]])
        vim.fn.winrestview(l)
    end,
})

-- Removes executed commands and boilerplate status messages from the command line
autocmd({'TextYankPost', 'BufWritePost', 'TextChanged', 'CmdlineLeave'}, {
    group = mjmGroup,
    pattern = '*',
    callback = function()
        vim.cmd([[normal! :<esc>]])
    end,
})

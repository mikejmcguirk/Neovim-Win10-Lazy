local yank_group = vim.api.nvim_create_augroup("HighlightYank", { clear = true })
local mjm_group = vim.api.nvim_create_augroup("mjm", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
    group = yank_group,
    pattern = "*",
    callback = function()
        vim.highlight.on_yank({
            higroup = "IncSearch",
            timeout = 200,
        })
    end,
})

vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = mjm_group,
    pattern = "*",
    callback = function(ev)
        if vim.bo.readonly then
            return
        end

        local clients = vim.lsp.buf_get_clients(ev.bufnr)

        for _, client in pairs(clients) do
            if client.name ~= "copilot" then
                return
            end
        end

        vim.cmd([[normal! mz]])

        vim.cmd([[%s/\s\+$//e]]) -- Remove trailing whitespace
        vim.cmd([[%s/\n\+\%$//e]]) -- Remove trailing blank lines
        vim.cmd([[%s/\%^\n\+//e]]) -- Remove leading blank lines

        vim.cmd([[silent! normal! `z]])
    end,
})

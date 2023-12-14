vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("HighlightYank", { clear = true }),
    pattern = "*",
    callback = function()
        vim.highlight.on_yank({
            higroup = "IncSearch",
            timeout = 200,
        })
    end,
})

local mjm_group = vim.api.nvim_create_augroup("mjm", { clear = true })

vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = mjm_group,
    pattern = "*",
    callback = function(ev)
        if vim.bo.readonly then
            return
        end

        local clients = vim.lsp.get_active_clients({ bufnr = ev.bufnr })

        for _, client in pairs(clients) do
            if client.name ~= "copilot" and client.name ~= "taplo" then
                return
            end
        end

        local shiftwidth = vim.api.nvim_buf_get_option(ev.bufnr, "shiftwidth")
        local expandtab = vim.api.nvim_buf_get_option(ev.bufnr, "expandtab")

        if expandtab then
            vim.api.nvim_buf_set_option(ev.bufnr, "tabstop", shiftwidth)
            vim.api.nvim_buf_set_option(ev.bufnr, "softtabstop", shiftwidth)
            vim.api.nvim_command("retab")
        end

        vim.cmd([[normal! mz]])

        vim.cmd([[%s/\s\+$//e]]) -- Remove trailing whitespace
        vim.cmd([[%s/\n\+\%$//e]]) -- Remove trailing blank lines
        vim.cmd([[%s/\%^\n\+//e]]) -- Remove leading blank lines

        vim.cmd([[silent! normal! `z]])
    end,
})

-- Does not work if set with other options
vim.api.nvim_create_autocmd({ "FileType" }, {
    group = mjm_group,
    pattern = "*",
    callback = function()
        vim.opt.formatoptions:remove("o")
    end,
})

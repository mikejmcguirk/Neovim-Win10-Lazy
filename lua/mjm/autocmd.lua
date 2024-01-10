vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("HighlightYank", { clear = true }),
    pattern = "*",
    callback = function()
        vim.highlight.on_yank({
            higroup = "IncSearch",
            timeout = 175,
        })
    end,
})

local mjm_group = vim.api.nvim_create_augroup("mjm", { clear = true })

vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = mjm_group,
    pattern = "*",
    callback = function(ev)
        local conformed = false

        local status, result = pcall(function()
            conformed = require("conform").format({
                bufnr = ev.buf,
                lsp_fallback = false,
                async = false,
                timeout_ms = 1000,
            })
        end)

        if not status and type(result) == "string" then
            vim.api.nvim_err_writeln(result)
        elseif not status then
            vim.api.nvim_err_writeln("Unknown error occurred while formatting with Conform")
        end

        if status and conformed then
            return
        end

        local clients = vim.lsp.get_active_clients({ bufnr = ev.buf })
        local mode = vim.api.nvim_get_mode().mode
        local method = nil

        if mode == "v" or mode == "V" then
            method = "textDocument/rangeFormatting"
        else
            method = "textDocument/formatting"
        end

        clients = vim.tbl_filter(function(client)
            return client.supports_method(method)
        end, clients)

        if #clients >= 0 then
            status, result = pcall(vim.lsp.buf.format, { bufnr = ev.buf, async = false })

            if not status and type(result) == "string" then
                vim.api.nvim_err_writeln(result)
            elseif not status then
                vim.api.nvim_err_writeln("Unknown error occurred while formatting with LSP")
            end

            if status then
                return
            end
        end

        local shiftwidth = vim.api.nvim_buf_get_option(ev.buf, "shiftwidth")
        local expandtab = vim.api.nvim_buf_get_option(ev.buf, "expandtab")

        if expandtab then
            vim.api.nvim_buf_set_option(ev.buf, "tabstop", shiftwidth)
            vim.api.nvim_buf_set_option(ev.buf, "softtabstop", shiftwidth)
            vim.api.nvim_exec2(ev.buf .. "bufdo retab", {})
        end

        local buf_wins = vim.fn.win_findbuf(ev.buf)
        local saved_cursors = {}

        for _, win in pairs(buf_wins) do
            local win_cursor = vim.api.nvim_win_get_cursor(win)
            table.insert(saved_cursors, win_cursor)
        end

        local remove_trailing_whitespace = ev.buf .. [[bufdo %s/\s\+$//e]]
        vim.api.nvim_exec2(remove_trailing_whitespace, {})
        local remove_leading_blank_lines = ev.buf .. [[bufdo %s/\%^\n\+//e]]
        vim.api.nvim_exec2(remove_leading_blank_lines, {})
        local fix_threeplus_newlines = ev.buf .. [[bufdo %s/\n\{3,}/\r\r/e]]
        vim.api.nvim_exec2(fix_threeplus_newlines, {})
        local remove_trailing_blank_lines = ev.buf .. [[bufdo %s/\n\+\%$//e]]
        vim.api.nvim_exec2(remove_trailing_blank_lines, {})

        for _, win in pairs(buf_wins) do
            vim.api.nvim_win_set_cursor(win, saved_cursors[_])
        end
    end,
})

-- Does not work as a global option
-- Prevents automatic creation of comment syntax when pressing o or O in a comment
vim.api.nvim_create_autocmd({ "FileType" }, {
    group = mjm_group,
    pattern = "*",
    callback = function()
        vim.opt.formatoptions:remove("o")
    end,
})

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

-- Does not work as a global option
-- Prevents automatic creation of comment syntax when pressing o or O in a comment
vim.api.nvim_create_autocmd({ "FileType" }, {
    group = mjm_group,
    pattern = "*",
    callback = function()
        vim.opt.formatoptions:remove("o")
    end,
})

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

        local expandtab = vim.api.nvim_buf_get_option(ev.buf, "expandtab")

        if expandtab then
            local shiftwidth = vim.api.nvim_buf_get_option(ev.buf, "shiftwidth")

            if shiftwidth == 0 then
                shiftwidth = vim.api.nvim_buf_get_option(ev.buf, "tabstop")
            else
                vim.api.nvim_buf_set_option(ev.buf, "tabstop", shiftwidth)
            end

            vim.api.nvim_buf_set_option(ev.buf, "softtabstop", shiftwidth)
            vim.api.nvim_exec2(ev.buf .. "bufdo retab", {})
        end

        local leading_blanks = true

        while leading_blanks do
            local top_line = vim.api.nvim_buf_get_lines(ev.buf, 0, 1, true)[1]

            if top_line == "" then
                vim.api.nvim_buf_set_lines(ev.buf, 0, 1, false, {})
            else
                leading_blanks = false
            end
        end

        local trailing_blanks = true

        while trailing_blanks do
            local bottom_line = vim.api.nvim_buf_get_lines(ev.buf, -2, -1, true)[1]

            if bottom_line == "" then
                vim.api.nvim_buf_set_lines(ev.buf, -2, -1, false, {})
            else
                trailing_blanks = false
            end
        end

        local total_lines = vim.api.nvim_buf_line_count(ev.buf)
        local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, total_lines, true)

        local consecutive_blanks = 0
        local lines_removed = 0

        for i, line in ipairs(lines) do
            local is_blank = line:match("^%s*$")

            if line == "" or is_blank then
                consecutive_blanks = consecutive_blanks + 1
                local row = i - lines_removed - 1

                if consecutive_blanks > 1 then
                    vim.api.nvim_buf_set_lines(ev.buf, row, row + 1, false, {})
                    lines_removed = lines_removed + 1
                elseif is_blank then
                    vim.api.nvim_buf_set_text(ev.buf, row, 0, row, #line, {})
                end
            else
                consecutive_blanks = 0

                local line_length = #line
                local row = i - 1 - lines_removed
                local last_non_blank, _ = line:find("(%S)%s*$")

                if last_non_blank and last_non_blank ~= line_length then
                    vim.api.nvim_buf_set_text(ev.buf, row, last_non_blank, row, line_length, {})
                end
            end
        end
    end,
})

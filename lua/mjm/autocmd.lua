vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("yank_aesthetic", { clear = true }),
    pattern = "*",
    callback = function()
        vim.highlight.on_yank({
            higroup = "IncSearch",
            timeout = 150,
        })

        vim.api.nvim_exec2("echo ''", {})
    end,
})

vim.api.nvim_create_autocmd("TextChanged", {
    group = vim.api.nvim_create_augroup("delete_clear", { clear = true }),
    pattern = "*",
    callback = function()
        if vim.v.operator == "d" then
            vim.api.nvim_exec2("echo ''", {})
        end
    end,
})
vim.api.nvim_create_autocmd("InsertEnter", {
    group = vim.api.nvim_create_augroup("change_clear", { clear = true }),
    pattern = "*",
    callback = function()
        if vim.v.operator == "c" then
            vim.api.nvim_exec2("echo ''", {})
        end
    end,
})

local mjm_group = vim.api.nvim_create_augroup("mjm", { clear = true })

vim.api.nvim_create_autocmd({ "InsertEnter", "CmdlineEnter" }, {
    group = mjm_group,
    pattern = "*",
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

-- TODO: Try using an autocommand when leaving Nvim to clear search registers

vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = mjm_group,
    pattern = "*",
    callback = function(ev)
        local buf = ev.buf

        if not vim.api.nvim_get_option_value("modifiable", { buf = ev.buf }) then
            vim.api.nvim_err_writeln("E21: Cannot make changes, 'modifiable' is off")
            return
        end

        local conformed = false
        local status, result = pcall(function()
            conformed = require("conform").format({
                bufnr = buf,
                lsp_fallback = false,
                async = false,
                timeout_ms = 1000,
            })
        end)

        if status and conformed then
            return
        elseif type(result) == "string" then
            vim.api.nvim_err_writeln(result)
        elseif not status then
            vim.api.nvim_err_writeln("Unknown error occurred while formatting with Conform")
        end

        local clients = vim.lsp.get_clients({ bufnr = buf })
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

        if #clients > 0 then
            status, result = pcall(vim.lsp.buf.format, { bufnr = buf, async = false })
            if status then
                return
            elseif type(result) == "string" then
                vim.api.nvim_err_writeln(result)
            else
                vim.api.nvim_err_writeln("Unknown error occurred while formatting with LSP")
            end
        end

        local shiftwidth = vim.api.nvim_get_option_value("shiftwidth", { buf = buf })
        if shiftwidth == 0 then
            shiftwidth = vim.api.nvim_get_option_value("tabstop", { buf = buf })
        else
            vim.api.nvim_set_option_value("tabstop", shiftwidth, { buf = buf })
        end

        local expandtab = vim.api.nvim_get_option_value("expandtab", { buf = buf })
        if expandtab then
            vim.api.nvim_set_option_value("softtabstop", shiftwidth, { buf = buf })
            vim.api.nvim_exec2(buf .. "bufdo retab", {})
        end

        ---@param start_idx number
        ---@param end_idx number
        ---@return nil
        local function fix_bookend_blanks(start_idx, end_idx)
            local line = vim.api.nvim_buf_get_lines(buf, start_idx, end_idx, true)[1]
            local blank_line = (line == "") or line:match("^%s*$")
            local last_line = vim.api.nvim_buf_line_count(buf) == 1

            if last_line or not blank_line then
                return
            end

            vim.api.nvim_buf_set_lines(buf, start_idx, end_idx, false, {})
            fix_bookend_blanks(start_idx, end_idx)
        end

        fix_bookend_blanks(0, 1)
        fix_bookend_blanks(-2, -1)

        local total_lines = vim.api.nvim_buf_line_count(buf)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, total_lines, true)

        local consecutive_blanks = 0
        local lines_removed = 0

        ---@param iter number
        ---@param line string
        ---@return nil
        local format_line = function(iter, line)
            local empty_line = line == ""
            local whitespace_line = line:match("^%s*$")
            local blank_line = empty_line or whitespace_line
            if blank_line then
                consecutive_blanks = consecutive_blanks + 1
            end

            local row = iter - lines_removed - 1
            if blank_line and consecutive_blanks > 1 then
                vim.api.nvim_buf_set_lines(buf, row, row + 1, false, {})
                lines_removed = lines_removed + 1

                return
            end

            if whitespace_line then
                vim.api.nvim_buf_set_text(buf, row, 0, row, #line, {})
                return
            end

            consecutive_blanks = 0

            local line_length = #line
            local last_non_blank, _ = line:find("(%S)%s*$")
            if last_non_blank and last_non_blank ~= line_length then
                vim.api.nvim_buf_set_text(buf, row, last_non_blank, row, line_length, {})
            end

            local first_non_blank, _ = line:find("%S") or 1, nil
            first_non_blank = first_non_blank - 1
            local extra_spaces = first_non_blank % shiftwidth
            if extra_spaces == 0 or not expandtab then
                return
            end

            local half_shiftwidth = shiftwidth * 0.5
            local round_up = extra_spaces >= half_shiftwidth
            if round_up then
                local new_spaces = shiftwidth - extra_spaces
                local spaces = string.rep(" ", new_spaces)
                vim.api.nvim_buf_set_text(buf, row, 0, row, 0, { spaces })
            else
                vim.api.nvim_buf_set_text(buf, row, 0, row, extra_spaces, {})
            end
        end

        for i, line in ipairs(lines) do
            format_line(i, line)
        end
    end,
})

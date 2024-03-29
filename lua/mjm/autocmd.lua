vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("HighlightYank", { clear = true }),
    pattern = "*",
    callback = function()
        vim.highlight.on_yank({
            higroup = "IncSearch",
            timeout = 150,
        })

        vim.api.nvim_exec2("echo ''", {})
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
        local ff = require("mjm.format_funcs")
        local buf = ev.buf

        -- Even after mark restoration is moved into the Nvim release branch,
        -- this should be kept for Conform or LSP formatting, as
        -- the official version of these functions does not save system or global marks
        local saved_marks = ff.get_marks(buf)

        if ff.try_conform(buf) then
            ff.restore_marks(buf, saved_marks)
            return
        end

        if ff.try_lsp_format(buf) then
            ff.restore_marks(buf, saved_marks)
            return
        end

        local expandtab = vim.api.nvim_buf_get_option(buf, "expandtab")
        local shiftwidth = vim.api.nvim_buf_get_option(buf, "shiftwidth")

        if shiftwidth == 0 then
            shiftwidth = vim.api.nvim_buf_get_option(buf, "tabstop")
        else
            vim.api.nvim_buf_set_option(buf, "tabstop", shiftwidth)
        end

        if expandtab then
            vim.api.nvim_buf_set_option(buf, "softtabstop", shiftwidth)
            vim.api.nvim_exec2(buf .. "bufdo retab", {})
        end

        ff.fix_bookend_blanks(buf)

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

        ff.restore_marks(buf, saved_marks)
    end,
})

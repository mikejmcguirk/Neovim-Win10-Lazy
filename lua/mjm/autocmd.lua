local ut = require("mjm.utils")

vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("yank_aesthetic", { clear = true }),
    pattern = "*",
    callback = function()
        vim.hl.on_yank({
            higroup = "IncSearch",
            timeout = 150,
        })

        vim.api.nvim_exec2("echo ''", {})
    end,
})

-- Done using the cmd because the lua function is buffer specific
vim.cmd([[match EolSpace /\s\+$/]])

local match_control = vim.api.nvim_create_augroup("match_control", { clear = true })

-- TODO: This should also turn off when entering cmd mode. Should be possible using the mode
-- change event and extracting the proper mode changes
vim.api.nvim_create_autocmd("InsertEnter", {
    group = match_control,
    pattern = "*",
    callback = function()
        local get_match_id = function(match_group)
            for _, match in ipairs(vim.fn.getmatches()) do
                if match.group == match_group then
                    return match.id
                end
            end
        end

        local match_id = get_match_id("EolSpace")
        if not match_id then
            return
        end

        vim.fn.matchdelete(match_id)
    end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
    group = match_control,
    pattern = "*",
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

-- TODO: In general this is bad because it's a lot of highly coupled behavior
-- TODO: Try using an autocommand when leaving Nvim to clear search registers
-- TODO: Outline this into its own file
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = mjm_group,
    pattern = "*",
    callback = function(ev)
        local buf = ev.buf

        if not ut.check_modifiable(buf) then
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
            vim.api.nvim_echo({ { result } }, true, { err = true })
        elseif not status then
            vim.api.nvim_echo(
                { { "Unknown error occurred while formatting with Conform" } },
                true,
                { err = true }
            )
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
            end

            vim.api.nvim_echo(
                { { result or "Unknown error occurred while formatting with LSP" } },
                true,
                { err = true }
            )
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

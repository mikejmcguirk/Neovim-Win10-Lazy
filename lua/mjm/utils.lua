local M = {}

---@param prompt string
---@return string
M.get_input = function(prompt)
    local pattern = nil ---@type string
    local _, result = pcall(function()
        pattern = vim.fn.input(prompt)
    end) ---@type boolean, unknown|nil

    vim.cmd("echo ''")
    if pattern then
        return pattern
    end

    if result == "Keyboard interrupt" then
        return ""
    end

    local err_msg = result or "Failed to get user input, unknown error"
    vim.api.nvim_echo({ { err_msg } }, true, { err = true })
    return ""
end

---@param bufnr? integer
---@return boolean
M.check_modifiable = function(bufnr)
    if vim.api.nvim_get_option_value("modifiable", { buf = bufnr or 0 }) then
        return true
    else
        local err_msg = "E21: Cannot make changes, 'modifiable' is off"
        vim.api.nvim_echo({ { err_msg } }, true, { err = true })
        return false
    end
end

---@param line_num number -- One indexed
---@return integer
M.get_indent = function(line_num)
    -- If Treesitter indent is enabled, the indentexpr will be set to
    -- nvim_treesitter#indent(), so that will be captured here
    local indentexpr = vim.bo.indentexpr
    if indentexpr == "" then
        local prev_nonblank = vim.fn.prevnonblank(line_num - 1)
        local prev_nonblank_indent = vim.fn.indent(prev_nonblank)

        if prev_nonblank_indent <= 0 then
            return 0
        else
            return prev_nonblank_indent
        end
    end

    -- Most indent expressions in the Nvim runtime do not take an argument
    --
    -- However, a few of them do take v:lnum
    -- v:lnum is not updated when nvim_exec2 is called, so it must be updated here
    --
    -- A couple of the runtime expressions take '.' as an argument
    -- This is already updated before nvim_exec2 is called
    --
    -- Other indentexpr arguments are not guaranteed to be handled properly
    vim.v.lnum = line_num
    local indentexpr_out = nil
    -- pcall in case treesitter errors due to a null node
    local ok, err = pcall(function()
        -- Must run nvim_exec2 explicitly to properly capture output table and avoid
        -- printing to cmdline
        indentexpr_out = vim.api.nvim_exec2("echo " .. indentexpr, { output = true })
    end)

    if ok then
        return tonumber(indentexpr_out.output) or 0
    end

    vim.api.nvim_echo({ { err or "Unknown error getting indent" } }, true, { err = true })
    return 0
end

---@param buf number
---@param start_idx number
---@param end_idx number
---@return nil
local function fix_bookend_blanks(buf, start_idx, end_idx)
    local line = vim.api.nvim_buf_get_lines(buf, start_idx, end_idx, true)[1]
    local blank_line = (line == "") or line:match("^%s*$")
    local last_line = vim.api.nvim_buf_line_count(buf) == 1

    if last_line or not blank_line then
        return
    end

    vim.api.nvim_buf_set_lines(buf, start_idx, end_idx, false, {})
    fix_bookend_blanks(buf, start_idx, end_idx)
end

M.fallback_formatter = function(buf)
    local shiftwidth = vim.api.nvim_get_option_value("shiftwidth", { buf = buf })
    if shiftwidth == 0 then
        shiftwidth = vim.api.nvim_get_option_value("tabstop", { buf = buf })
    else
        vim.api.nvim_set_option_value("tabstop", shiftwidth, { buf = buf })
    end

    local expandtab = vim.api.nvim_get_option_value("expandtab", { buf = buf })
    if expandtab then
        vim.api.nvim_set_option_value("softtabstop", shiftwidth, { buf = buf })
        vim.cmd(buf .. "bufdo retab")
    end

    fix_bookend_blanks(buf, 0, 1)
    fix_bookend_blanks(buf, -2, -1)

    local total_lines = vim.api.nvim_buf_line_count(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, total_lines, true)

    local consecutive_blanks = 0
    local lines_removed = 0

    ---@param iter number
    ---@param line string
    ---@return nil
    local format_line = function(iter, line)
        local row_0 = iter - lines_removed - 1
        local line_len = #line
        local empty_line = line == ""
        local whitespace_line = line:match("^%s+$")
        local blank_line = empty_line or whitespace_line

        if blank_line then
            consecutive_blanks = consecutive_blanks + 1
        else
            consecutive_blanks = 0
        end

        if blank_line and consecutive_blanks > 1 then
            vim.api.nvim_buf_set_lines(buf, row_0, row_0 + 1, false, {})
            lines_removed = lines_removed + 1

            return
        end

        if whitespace_line then
            vim.api.nvim_buf_set_text(buf, row_0, 0, row_0, line_len, {})
            return
        end

        local last_non_blank, _ = line:find("(%S)%s*$")
        if last_non_blank and last_non_blank ~= line_len then
            vim.api.nvim_buf_set_text(buf, row_0, last_non_blank, row_0, line_len, {})
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
            vim.api.nvim_buf_set_text(buf, row_0, 0, row_0, 0, { spaces })
        else
            vim.api.nvim_buf_set_text(buf, row_0, 0, row_0, extra_spaces, {})
        end
    end

    for i, line in ipairs(lines) do
        format_line(i, line)
    end
end

---@return boolean
M.loc_list_closer = function()
    for _, win in ipairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 and win.loclist == 1 then
            vim.api.nvim_win_close(win.winid, false)
            return true
        end
    end

    return false
end

return M

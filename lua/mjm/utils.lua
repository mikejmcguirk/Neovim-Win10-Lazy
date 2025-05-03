local M = {}

---@param prompt string
---@return string
M.get_input = function(prompt)
    local pattern = nil ---@type string
    local _, result = pcall(function()
        pattern = vim.fn.input(prompt)
    end) ---@type boolean, unknown|nil

    vim.api.nvim_exec2("echo ''", {})
    if pattern then
        return pattern
    end

    if result == "Keyboard interrupt" then
        do
        end
    else
        vim.api.nvim_echo(
            { { result or "Failed to get user input, unknown error" } },
            true,
            { err = true }
        )
    end
    return ""
end

---@param width integer
---@return nil
M.adjust_tab_width = function(width)
    vim.bo.tabstop = width
    vim.bo.softtabstop = width
    vim.bo.shiftwidth = width
end

---@param buf? integer
---@return boolean
M.check_modifiable = function(buf)
    buf = buf or 0

    if vim.api.nvim_get_option_value("modifiable", { buf = buf }) then
        return true
    else
        vim.api.nvim_echo(
            { { "E21: Cannot make changes, 'modifiable' is off" } },
            true,
            { err = true }
        )
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
    -- pcall in case treesitter errors out due to a null node
    local status, expr_indent_tbl = pcall(function()
        vim.api.nvim_exec2("echo " .. indentexpr, { output = true })
    end)

    if status and expr_indent_tbl then
        return tonumber(expr_indent_tbl.output) or 0
    end

    return 0
end

M.norm_toggle_semicolon = function()
    local line_num = vim.api.nvim_win_get_cursor(0)[1] - 1 ---@type integer
    local line = vim.api.nvim_get_current_line() ---@type string

    -- Check for trailing whitespace and remove it
    local trail_start, trail_end = line:find("%s+$") ---@type integer|nil, integer|nil
    if trail_start and trail_end then
        vim.api.nvim_buf_set_text(0, line_num, trail_start - 1, line_num, trail_end, {})
        line = vim.api.nvim_get_current_line()
    end

    if line:sub(-1) == ";" then
        vim.api.nvim_buf_set_text(0, line_num, #line - 1, line_num, #line, {})
    elseif line:sub(-1) ~= ";" then
        vim.api.nvim_buf_set_text(0, line_num, #line, line_num, #line, { ";" })
    end
end

M.ins_add_semicolon = function()
    vim.cmd("stopinsert")
    local line_num = vim.api.nvim_win_get_cursor(0)[1] ---@type integer
    local line = vim.api.nvim_get_current_line() ---@type string
    vim.api.nvim_buf_set_text(0, line_num - 1, #line, line_num - 1, #line, { ";" })

    line = vim.api.nvim_get_current_line() ---@type string
    vim.api.nvim_win_set_cursor(0, { line_num, #line })
end

---@return string
M.clear_clutter = function()
    vim.api.nvim_exec2("echo ''", {})
    vim.api.nvim_exec2("noh", {})
    vim.lsp.buf.clear_references()
    -- Allows <C-c> to exit the start of commands with a count
    -- Eliminates default command line nag
    return "<esc>"
end

return M

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
        vim.api.nvim_err_writeln(result or "Failed to get user input, unknown error")
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
        vim.api.nvim_err_writeln("E21: Cannot make changes, 'modifiable' is off")
        return false
    end
end

---@param line_num number -- One indexed
---@return integer
M.get_indent = function(line_num)
    local fix_indent = function(indent)
        if indent <= 0 then
            return 0
        else
            return indent
        end
    end

    -- If Treesitter indent is enabled, the indentexpr will be set to
    -- nvim_treesitter#indent(), so that will be captured here
    local indentexpr = vim.bo.indentexpr
    if indentexpr == "" then
        local prev_nonblank = vim.fn.prevnonblank(line_num - 1)
        local prev_nonblank_indent = vim.fn.indent(prev_nonblank)
        return fix_indent(prev_nonblank_indent)
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
    local expr_indent_tbl = vim.api.nvim_exec2("echo " .. indentexpr, { output = true })
    local expr_indent = tonumber(expr_indent_tbl.output) or 0
    return fix_indent(expr_indent)
end

return M

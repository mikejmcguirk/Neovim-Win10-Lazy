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

---@param bufnr? integer
---@return boolean
M.check_modifiable = function(bufnr)
    if vim.api.nvim_get_option_value("modifiable", { buf = bufnr or 0 }) then
        return true
    end

    vim.api.nvim_echo(
        { { "E21: Cannot make changes, 'modifiable' is off" } },
        true,
        { err = true }
    )

    return false
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

return M

local M = {}

---@param prompt string
---@return string
M.get_input = function(prompt)
    local pattern = nil ---@type string
    local status, result = pcall(function()
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

return M

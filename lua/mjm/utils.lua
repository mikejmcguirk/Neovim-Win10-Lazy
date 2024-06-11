local M = {}

---@param prompt string
---@return string
M.get_user_input = function(prompt)
    local pattern = nil
    local status, result = pcall(function()
        pattern = vim.fn.input(prompt)
    end)
    vim.api.nvim_exec2("echo ''", {})
    if pattern then
        return pattern
    end

    if result == "Keyboard interrupt" then
        do
        end
    elseif result then
        vim.api.nvim_err_writeln(result)
    else
        vim.api.nvim_err_writeln("Failed to get user input, unknown error")
    end
    return ""
end

---@param width number
---@return nil
M.adjust_tab_width = function(width)
    vim.bo.tabstop = width
    vim.bo.softtabstop = width
    vim.bo.shiftwidth = width
end

return M

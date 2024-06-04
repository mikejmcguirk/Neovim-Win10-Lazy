local M = {}

---@param prompt string
---@return string
M.get_user_input = function(prompt)
    local pattern = nil

    local status, result = pcall(function()
        pattern = vim.fn.input(prompt)
    end)

    if not status then
        if result then
            vim.api.nvim_err_writeln(result)
        else
            vim.api.nvim_err_writeln("Failed to get user input, unknown error")
        end

        return ""
    end

    if pattern == "" or pattern == nil then
        vim.api.nvim_exec2("echo ''", {})

        return ""
    end

    return pattern
end

---@param width number
---@return nil
M.adjust_tab_width = function(width)
    vim.bo.tabstop = width
    vim.bo.softtabstop = width
    vim.bo.shiftwidth = width
end

---@return nil
M.get_home = function()
    if vim.fn.has("win32") == 1 then
        return os.getenv("USERPROFILE")
    else
        return os.getenv("HOME")
    end
end

return M

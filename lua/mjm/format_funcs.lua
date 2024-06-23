local M = {}

---@param buf number
---@return boolean
M.try_conform = function(buf)
    local conformed = false

    local status, result = pcall(function()
        conformed = require("conform").format({
            bufnr = buf,
            lsp_fallback = false,
            async = false,
            timeout_ms = 1000,
        })
    end)

    if not status and type(result) == "string" then
        vim.api.nvim_err_writeln(result)
    elseif not status then
        vim.api.nvim_err_writeln("Unknown error occurred while formatting with Conform")
    end

    if status and conformed then
        return true
    end

    return false
end

---@param buf number
---@return boolean
M.try_lsp_format = function(buf)
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

    if #clients == 0 then
        return false
    end

    local status, result = pcall(vim.lsp.buf.format, { bufnr = buf, async = false })

    if not status then
        if type(result) == "string" then
            vim.api.nvim_err_writeln(result)
        else
            vim.api.nvim_err_writeln("Unknown error occurred while formatting with LSP")
        end

        return false
    end

    return true
end

return M

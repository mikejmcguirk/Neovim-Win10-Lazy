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
    local clients = vim.lsp.get_active_clients({ bufnr = buf })
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

    if not status and type(result) == "string" then
        vim.api.nvim_err_writeln(result)
    elseif not status then
        vim.api.nvim_err_writeln("Unknown error occurred while formatting with LSP")
    end

    if status then
        return true
    end

    return false
end

---@param buf number
M.fix_bookend_blanks = function(buf)
    ---@param line string
    ---@return boolean
    local check_line = function(line)
        local empty_line = line == ""
        local whitespace_line = line:match("^%s*$")
        local blank_line = empty_line or whitespace_line

        return blank_line
    end

    ---@return nil
    local function top_blank_lines()
        local line = vim.api.nvim_buf_get_lines(buf, 0, 1, true)[1]

        if check_line(line) then
            vim.api.nvim_buf_set_lines(buf, 0, 1, false, {})
            top_blank_lines()
        end
    end

    ---@return nil
    local function bottom_blank_lines()
        local line = vim.api.nvim_buf_get_lines(buf, -2, -1, true)[1]

        if check_line(line) then
            vim.api.nvim_buf_set_lines(buf, -2, -1, false, {})
            bottom_blank_lines()
        end
    end

    top_blank_lines()
    bottom_blank_lines()
end

return M

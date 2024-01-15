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
    if vim.api.nvim_buf_line_count(buf) == 1 then
        return
    end

    ---@param line string
    ---@return boolean
    local check_line = function(line)
        local empty_line = line == ""
        local whitespace_line = line:match("^%s*$")
        local blank_line = empty_line or whitespace_line
        local last_line = vim.api.nvim_buf_line_count(buf) == 1

        return blank_line and not last_line
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

---@param buf number
---@return table
M.get_marks = function(buf)
    local saved_marks = {}
    local local_marks = vim.fn.getmarklist(buf)

    for _, m in pairs(local_marks) do
        local mark_name = m.mark:sub(2, 2)
        local unsettable_marks = { "^", ".", "(", ")", "{", "}" }

        if not vim.tbl_contains(unsettable_marks, mark_name) then
            saved_marks[mark_name] = { m.pos[2], m.pos[3] - 1 } -- api-indexed
        end
    end

    local global_marks = vim.fn.getmarklist()

    for _, m in pairs(global_marks) do
        local is_global = m.mark:match("^'[A-Z]$")
        local this_buf = m.pos[1] == buf

        if is_global and this_buf then
            saved_marks[m.mark:sub(2, 2)] = { m.pos[2], m.pos[3] - 1 } -- api-indexed
        end
    end

    return saved_marks
end

---@param buf number
---@param marks table
M.restore_marks = function(buf, marks)
    local total_lines = vim.api.nvim_buf_line_count(buf)
    local old_marks = vim.deepcopy(marks)
    local cur_marks = vim.fn.getmarklist(buf)

    for _, m in pairs(cur_marks) do
        old_marks[m.mark:sub(2, 2)] = nil
    end

    for mark, pos in pairs(old_marks) do
        if pos then
            local row = pos[1]
            row = math.min(row, total_lines)

            local col = pos[2]
            local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, true)[1]
            local line_len = #line - 1
            col = math.min(col, line_len or "")

            vim.api.nvim_buf_set_mark(buf, mark, row, col, {})
        end
    end
end

return M

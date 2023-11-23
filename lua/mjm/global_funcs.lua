local M = {}

---@param width number
M.adjust_tab_width = function(width)
    vim.bo.tabstop = width
    vim.bo.softtabstop = width
    vim.bo.shiftwidth = width
end

local get_home = function()
    if vim.fn.has("win32") == 1 then
        return os.getenv("USERPROFILE")
    else
        return os.getenv("HOME")
    end
end

---@param patterns string[]
---@param path string
M.find_proj_root = function(patterns, path, backup_dir)
    local matches = vim.fs.find(patterns, { path = path, upward = true, stop = get_home() })

    for _, match in ipairs(matches) do
        local root_dir = vim.fs.dirname(match)

        if root_dir then
            return root_dir
        end
    end

    if backup_dir then
        return backup_dir
    end

    return nil
end

---@param filename string
---@param root_start string
---@param field_name string
M.find_file_with_field = function(filename, root_start, field_name)
    local matches = vim.fs.find(filename, { path = root_start, upward = true, stop = get_home() })

    for _, match in ipairs(matches) do
        local file = io.open(match, "r")

        if file then
            for line in file:lines() do
                if line:find(field_name) then
                    file:close()

                    return true
                end
            end

            file:close()
        end
    end

    return false
end

M.create_lsp_formatter = function(augroup)
    vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = 0,
        group = augroup,
        callback = function(ev)
            local ok, err = pcall(vim.lsp.buf.format, { bufnr = ev.buf, async = false })

            if not ok then
                vim.api.nvim_err_writeln("Failed to format via LSP: " .. vim.inspect(err))
            end
        end,
    })
end

M.get_buf_directory = function(buf_num)
    local buf_name = vim.fn.bufname(buf_num)

    return vim.fn.fnamemodify(buf_name, ":p:h")
end

-- Alternate publish_diagnostics handler for Typescript
--- @param err lsp.ResponseError
-- These params might only work in Neovim .10
-- @param result lsp.PublishDiagnosticsParams
-- @param ctx lsp.HandlerContext
local function diagnostics_handler(err, result, ctx)
    if err ~= nil then
        error("Failed to request diagnostics: " .. vim.inspect(err))
    end

    if result == nil then
        return
    end

    local buffer = vim.uri_to_bufnr(result.uri)
    local namespace = vim.lsp.diagnostic.get_namespace(ctx.client_id)

    local diagnostics = vim.tbl_map(function(diagnostic)
        local resultLines = vim.split(diagnostic.message, "\n")
        local output = vim.fn.reverse(resultLines)
        return {
            bufnr = buffer,
            lnum = diagnostic.range.start.line,
            end_lnum = diagnostic.range["end"].line,
            col = diagnostic.range.start.character,
            end_col = diagnostic.range["end"].character,
            severity = diagnostic.severity,
            message = table.concat(output, "\n\n"),
            source = diagnostic.source,
            code = diagnostic.code,
        }
    end, result.diagnostics)

    vim.diagnostic.set(namespace, buffer, diagnostics)
end

M.setup_tsserver = function(root_start)
    local root_dir = M.find_proj_root({ "tsconfig.json" }, root_start, nil)

    if not root_dir then
        local js_root_files = { "package.json", "jsconfig.json", ".git" }

        root_dir = M.find_proj_root(js_root_files, root_start, root_start)
    end

    return {
        name = "tsserver",
        cmd = { "typescript-language-server", "--stdio" },
        root_dir = root_dir,
        single_file_support = true,
        capabilities = Lsp_Capabilities,
        init_options = {
            hostInfo = "neovim",
        },
    }
end

return M

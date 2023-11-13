local M = {}

---@param width number
M.adjust_tab_width = function(width)
    vim.bo.tabstop = width
    vim.bo.softtabstop = width
    vim.bo.shiftwidth = width
end

---@param patterns string[]
---@param path string
M.find_proj_root = function(patterns, path, backup_dir)
    local get_home = function()
        if vim.fn.has("win32") == 1 then
            return os.getenv("USERPROFILE")
        else
            return os.getenv("HOME")
        end
    end

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

M.find_file_with_field = function(filename, root_start, field_name)
    local get_home = function()
        if vim.fn.has("win32") == 1 then
            return os.getenv("USERPROFILE")
        else
            return os.getenv("HOME")
        end
    end

    local matches = vim.fs.find(
        { filename },
        { path = root_start, upward = true, stop = get_home() }
    )

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

M.setup_tsserver = function(root_start)
    local gf = require("mjm.global_funcs")

    local find_js_root_dir = function(root_input)
        local tsconfig_dir = gf.find_proj_root({ "tsconfig.json" }, root_input, nil)

        if tsconfig_dir then
            return tsconfig_dir
        else
            local js_root_files = {
                "package.json",
                "jsconfig.json",
                ".git",
            }

            return gf.find_proj_root(js_root_files, root_input, root_input)
        end
    end

    return {
        name = "tsserver",
        cmd = { "typescript-language-server", "--stdio" },
        root_dir = find_js_root_dir(root_start),
        single_file_support = true,
        capabilities = Lsp_Capabilities,
        init_options = {
            hostInfo = "neovim",
        },
    }
end

return M

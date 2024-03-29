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

---@param patterns string[]
---@param path string
M.find_proj_root = function(patterns, path, backup_dir)
    local files = vim.deepcopy(patterns)
    local matches = vim.fs.find(files, { path = path, upward = true, stop = M.get_home() })

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

---@param buf_num number
---@return string
M.get_buf_directory = function(buf_num)
    local buf_name = vim.fn.bufname(buf_num)

    return vim.fn.fnamemodify(buf_name, ":p:h")
end

---@param root_start string
---@return table
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

local open_at_bottom = function()
    vim.api.nvim_cmd({ cmd = "copen", mods = { split = "botright" } }, {})
end

vim.keymap.set("n", "<leader>qt", function()
    for _, win in ipairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 then
            vim.api.nvim_cmd({ cmd = "cclose" }, {})

            return
        end
    end

    vim.api.nvim_cmd({ cmd = "copen", mods = { split = "botright" } }, {})
end)

vim.keymap.set("n", "<leader>qp", function()
    vim.api.nvim_cmd({ cmd = "copen", mods = { split = "botright" } }, {})
end)

vim.keymap.set("n", "<leader>qc", "<cmd>cclose<cr>")

vim.opt.grepprg = "rg --line-number"
vim.opt.grepformat = "%f:%l:%m"

local grep_wrapper = function(options)
    local pattern = vim.fn.input("Enter pattern: ")

    if pattern == "" or pattern == nil then
        vim.cmd("echo ''")

        return
    end

    local args = { pattern }

    local opts = vim.deepcopy(options) or {}
    local case_insensitive = opts.insensitive or false

    if case_insensitive then
        table.insert(args, "-i")
    end

    local grep_cmd = {
        args = args,
        bang = true,
        cmd = "grep",
        mods = {
            emsg_silent = true,
        },
    }

    vim.api.nvim_cmd(grep_cmd, {})
    vim.api.nvim_cmd({ cmd = "copen", mods = { split = "botright" } }, {})
end

vim.keymap.set("n", "<leader>qgn", function()
    grep_wrapper()
end)

-- This command depends on the grepprg being set to ripgrep
vim.keymap.set("n", "<leader>qgi", function()
    grep_wrapper({ insensitive = true })
end)

---@param severity_cap number
local diags_to_qf = function(severity_cap, options)
    local opts = vim.deepcopy(options) or {}
    local all_bufs = opts.all_bufs or false

    if not all_bufs then
        local cur_win = vim.api.nvim_get_current_win()
        local cur_win_info = vim.fn.getwininfo(cur_win)

        for _, win in ipairs(cur_win_info) do
            if win.quickfix == 1 then
                local echo_cmd = {
                    cmd = "echo",
                    args = { "'Currently", "in", "quickfix", "window'" },
                }

                vim.api.nvim_cmd(echo_cmd, {})

                return
            end
        end
    end

    local raw_diagnostics = nil

    if all_bufs then
        raw_diagnostics = vim.diagnostic.get(nil)
    else
        raw_diagnostics = vim.diagnostic.get(0)
    end

    local diags_for_qf = {}

    local severity_map = {
        [vim.diagnostic.severity.ERROR] = "E",
        [vim.diagnostic.severity.WARN] = "W",
        [vim.diagnostic.severity.INFO] = "I",
        [vim.diagnostic.severity.HINT] = "H",
    }

    for _, raw_diag in ipairs(raw_diagnostics) do
        if raw_diag.severity <= severity_cap then
            local converted_diag = {
                bufnr = raw_diag.bufnr,
                filename = vim.fn.bufname(raw_diag.bufnr),
                lnum = raw_diag.lnum + 1,
                end_lnum = raw_diag.end_lnum + 1,
                col = raw_diag.col,
                end_col = raw_diag.end_col,
                text = (raw_diag.source or "")
                    .. ": "
                    .. "["
                    .. (raw_diag.code or "")
                    .. "] "
                    .. (raw_diag.message or ""),
                type = severity_map[raw_diag.severity],
            }

            table.insert(diags_for_qf, converted_diag)
        end
    end

    vim.fn.setqflist(diags_for_qf, "r")
    vim.api.nvim_cmd({ cmd = "copen", mods = { split = "botright" } }, {})
end

vim.keymap.set("n", "<leader>qiq", function()
    diags_to_qf(4, { all_bufs = true })
end)

vim.keymap.set("n", "<leader>qiu", function()
    diags_to_qf(4)
end)

vim.keymap.set("n", "<leader>qii", function()
    diags_to_qf(2, { all_bufs = true })
end)

vim.keymap.set("n", "<leader>qif", function()
    diags_to_qf(2)
end)

vim.cmd("packadd cfilter")

vim.keymap.set("n", "<leader>qk", function()
    local pattern = vim.fn.input("Pattern to keep: ")

    if pattern ~= "" then
        vim.cmd("Cfilter " .. pattern)
    end
end)

vim.keymap.set("n", "<leader>qr", function()
    local pattern = vim.fn.input("Pattern to remove: ")

    if pattern ~= "" then
        vim.cmd("Cfilter! " .. pattern)
    end
end)

vim.keymap.set("n", "<leader>qe", function()
    vim.fn.setqflist({})
    vim.api.nvim_cmd({ cmd = "cclose" }, {})
end)

---@param direction string
---@param backup_direction string
local qf_scroll = function(direction, backup_direction)
    local status, result = pcall(function()
        vim.cmd("c" .. direction)
    end)

    if (not status) and result then
        if type(result) == "string" and string.find(result, "E553") then
            vim.cmd("c" .. backup_direction)
            vim.cmd("normal! zz")
        elseif type(result) == "string" and string.find(result, "E42") then
        else
            print(result)
        end
    else
        vim.cmd("normal! zz")
    end
end

vim.keymap.set("n", "[q", function()
    qf_scroll("prev", "last")
end)

vim.keymap.set("n", "]q", function()
    qf_scroll("next", "first")
end)

vim.keymap.set("n", "[Q", "<cmd>cfirst<cr>")
vim.keymap.set("n", "]Q", "<cmd>clast<cr>")

---@param statuses table{{code: string, description: string}}
---@param filter boolean
local get_git_info = function(statuses, filter)
    local git_status = vim.fn.systemlist("git status --porcelain")
    local files = {}

    for _, file in ipairs(git_status) do
        local found = false
        local file_status = file:sub(1, 2)

        ---@param text string
        local to_insert = function(text)
            return {
                filename = file:sub(4),
                text = text,
                lnum = 1,
                col = 1,
                type = 1,
            }
        end

        for _, status in ipairs(statuses) do
            if file_status == status.code then
                table.insert(files, to_insert(file_status .. " : " .. status.description))
                found = true
                break
            end
        end

        if not found and not filter then
            table.insert(files, to_insert(file_status .. " : Unknown"))
        end
    end

    vim.fn.setqflist(files)
    open_at_bottom()
end

local git_all = {
    { code = " M", description = "Modified" },
    { code = "A ", description = "Added" },
    { code = " D", description = "Deleted" },
    { code = "R ", description = "Renamed" },
    { code = "C ", description = "Copied" },
    { code = "U ", description = "Unmerged" },
    { code = "??", description = "Untracked" },
    { code = "!!", description = "Ignored" },
    { code = "AM", description = "Staged and Modified" },
    { code = "AD", description = "Staged for Deletion but Modified" },
    { code = "MM", description = "Modified, Staged and Modified Again" },
}

vim.keymap.set("n", "<leader>qut", function()
    get_git_info({
        { code = "??", description = "Untracked File" },
    }, true)
end)

vim.keymap.set("n", "<leader>quu", function()
    get_git_info({
        { code = " M", description = "Unstaged Change" },
    }, true)
end)

vim.keymap.set("n", "<leader>qud", function()
    get_git_info({
        { code = " D", description = "Unstaged Change" },
    }, true)
end)

vim.keymap.set("n", "<leader>qua", function()
    get_git_info(git_all, false)
end)

vim.keymap.set("n", "<leader>ql", function()
    local clients = vim.lsp.get_active_clients()

    if #clients == 0 then
        print("No active LSP clients")
        return
    end

    local for_qf_list = {}

    for _, client in ipairs(clients) do
        local bufs_for_client = "( "

        for _, buf in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
            bufs_for_client = bufs_for_client .. buf .. " "
        end

        bufs_for_client = bufs_for_client .. ")"
        local lsp_entry = "LSP: "
            .. client.name
            .. ", ID: "
            .. client.id
            .. ", Buffer(s): "
            .. bufs_for_client
            .. ", Root: "
            .. (client.config.root_dir or "")
            .. ", Status: "
            .. (client.config.status or "")
            .. ", Command: "
            .. (client.config.cmd[1] or "")

        table.insert(for_qf_list, { text = lsp_entry })
    end

    vim.fn.setqflist(for_qf_list, "r")
    open_at_bottom()
end)

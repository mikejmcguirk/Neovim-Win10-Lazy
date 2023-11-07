vim.keymap.set("n", "<leader>qt", function()
    local is_quickfix_open = false
    local win_info = vim.fn.getwininfo()

    for _, win in ipairs(win_info) do
        if win.quickfix == 1 then
            is_quickfix_open = true
            break
        end
    end

    if is_quickfix_open then
        vim.cmd("cclose")
    else
        vim.cmd("copen")
    end
end, Opts)

vim.keymap.set("n", "<leader>qo", "<cmd>copen<cr>", Opts)
vim.keymap.set("n", "<leader>qc", "<cmd>cclose<cr>", Opts)

vim.opt.grepformat = "%f:%l:%m"
vim.opt.grepprg = "rg --line-number"

---@param grep_cmd string
local grep_function = function(grep_cmd)
    local pattern = vim.fn.input("Enter pattern: ")

    if pattern ~= "" then
        local cur_view = vim.fn.winsaveview()

        vim.cmd("silent! " .. grep_cmd .. " " .. pattern .. " | copen")

        vim.cmd("wincmd p")
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-O>", true, true, true), "n", {})

        vim.defer_fn(function()
            vim.fn.winrestview(cur_view)
        end, 0)

        vim.defer_fn(function()
            vim.cmd("copen")
        end, 0)
    end
end

vim.keymap.set("n", "<leader>qgn", function()
    grep_function("grep")
end, Opts)

-- This command depends on the grepprg being set to ripgrep
vim.keymap.set("n", "<leader>qgi", function()
    grep_function("grep -i")
end, Opts)

---@param severity_cap number
local diags_to_qf = function(severity_cap)
    local raw_diagnostics = vim.diagnostic.get(nil)
    local diagnostics = {}

    for _, diagnostic in ipairs(raw_diagnostics) do
        if diagnostic.severity <= severity_cap then
            local severity_map = {
                [vim.diagnostic.severity.ERROR] = "E",
                [vim.diagnostic.severity.WARN] = "W",
                [vim.diagnostic.severity.INFO] = "I",
                [vim.diagnostic.severity.HINT] = "H",
            }

            local converted_diag = {
                bufnr = diagnostic.bufnr,
                filename = vim.fn.bufname(diagnostic.bufnr),
                lnum = diagnostic.lnum,
                end_lnum = diagnostic.end_lnum,
                col = diagnostic.col,
                end_col = diagnostic.end_col,
                text = diagnostic.source
                    .. ": "
                    .. "["
                    .. diagnostic.code
                    .. "] "
                    .. diagnostic.message,
                type = severity_map[diagnostic.severity],
            }

            table.insert(diagnostics, converted_diag)
        end
    end

    vim.fn.setqflist(diagnostics, "r")
    vim.cmd("copen")
end

vim.keymap.set("n", "<leader>qiq", function()
    diags_to_qf(4)
end, Opts)

vim.keymap.set("n", "<leader>qii", function()
    diags_to_qf(2) -- ERROR or WARN only
end, Opts)

vim.keymap.set("n", "<leader>ql", function()
    local clients = vim.lsp.get_active_clients()
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

        table.insert(for_qf_list, { text = lsp_entry })
    end

    vim.fn.setqflist(for_qf_list, "r")
    vim.cmd("copen")
end, Opts)

vim.cmd("packadd cfilter")

vim.keymap.set("n", "<leader>qk", function()
    local pattern = vim.fn.input("Pattern to keep: ")

    if pattern ~= "" then
        vim.cmd("Cfilter " .. pattern)
    end
end, Opts)

vim.keymap.set("n", "<leader>qr", function()
    local pattern = vim.fn.input("Pattern to remove: ")

    if pattern ~= "" then
        vim.cmd("Cfilter! " .. pattern)
    end
end, Opts)

vim.keymap.set("n", "<leader>qe", function()
    vim.fn.setqflist({})
    vim.cmd("cclose")
end, Opts)

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
end, Opts)

vim.keymap.set("n", "]q", function()
    qf_scroll("next", "first")
end, Opts)

vim.keymap.set("n", "[Q", "<cmd>cfirst<cr>", Opts)
vim.keymap.set("n", "]Q", "<cmd>clast<cr>", Opts)

vim.keymap.set("n", "<leader>qo", function()
    if vim.bo.filetype ~= "qf" then
        return
    end

    local cur_line = vim.fn.line(".")
    vim.cmd("cc " .. tostring(cur_line))
    vim.cmd("cclose")
end, Opts)

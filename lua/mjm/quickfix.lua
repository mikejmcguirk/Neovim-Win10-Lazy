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
        vim.cmd "cclose"
    else
        vim.cmd "copen"
    end
end, Opts)

vim.keymap.set("n", "<leader>qo", "<cmd>copen<cr>", Opts)
vim.keymap.set("n", "<leader>qc", "<cmd>cclose<cr>", Opts)

local grep_function = function(grep_cmd)
    local pattern = vim.fn.input('Enter pattern: ')

    if pattern ~= "" then
        vim.cmd("silent! " .. grep_cmd .. " " .. pattern .. " | copen")

        -- vim.cmd("wincmd p")
        -- vim.api.nvim_feedkeys(
        --     vim.api.nvim_replace_termcodes(
        --         '<C-O>', true, true, true
        --     ), 'n', {}
        -- )
    end
end

vim.keymap.set("n", "<leader>qgn", function()
    grep_function("grep")
end, Opts)

vim.opt.grepformat = "%f:%l:%m"
vim.opt.grepprg = "rg --line-number"

-- NOTE: This command depends on the grepprg being set to ripgrep
vim.keymap.set("n", "<leader>qgi", function()
    grep_function("grep -i")
end, Opts)

local convert_raw_diagnostic = function(raw_diagnostic)
    local diag_severity

    if raw_diagnostic.severity == vim.diagnostic.severity.ERROR then
        diag_severity = "E"
    elseif raw_diagnostic.severity == vim.diagnostic.severity.WARN then
        diag_severity = "W"
    elseif raw_diagnostic.severity == vim.diagnostic.severity.INFO then
        diag_severity = "I"
    elseif raw_diagnostic.severity == vim.diagnostic.severity.HINT then
        diag_severity = "H"
    else
        diag_severity = "U"
    end

    return {
        bufnr = raw_diagnostic.bufnr,
        filename = vim.fn.bufname(raw_diagnostic.bufnr),
        lnum = raw_diagnostic.lnum,
        end_lnum = raw_diagnostic.end_lnum,
        col = raw_diagnostic.col,
        end_col = raw_diagnostic.end_col,
        text = raw_diagnostic.source .. ": " .. "[" .. raw_diagnostic.code .. "] " ..
            raw_diagnostic.message,
        type = diag_severity,
    }
end

local diags_to_qf = function(min_warning)
    local raw_diagnostics = vim.diagnostic.get(nil)
    local diagnostics = {}

    if min_warning then
        for _, diagnostic in ipairs(raw_diagnostics) do
            if diagnostic.severity <= 2 then --ERROR or WARN
                table.insert(diagnostics, convert_raw_diagnostic(diagnostic))
            end
        end
    else
        for _, diagnostic in ipairs(raw_diagnostics) do
            table.insert(diagnostics, convert_raw_diagnostic(diagnostic))
        end
    end

    vim.fn.setqflist(diagnostics, "r")
    vim.cmd "copen"
end

vim.keymap.set("n", "<leader>qiq", function()
    diags_to_qf(false)
end, Opts)

vim.keymap.set("n", "<leader>qii", function()
    diags_to_qf(true)
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
        local lsp_entry = "LSP: " .. client.name .. ", ID: " .. client.id .. ", Buffer(s): " ..
            bufs_for_client

        table.insert(for_qf_list, { text = lsp_entry })
    end

    vim.fn.setqflist(for_qf_list, "r")
    vim.cmd("copen")
end, Opts)

vim.cmd "packadd cfilter"

vim.keymap.set("n", "<leader>qk", function()
    local pattern = vim.fn.input('Pattern to keep: ')
    if pattern ~= "" then
        vim.cmd("Cfilter " .. pattern)
    end
end, Opts)

vim.keymap.set("n", "<leader>qr", function()
    local pattern = vim.fn.input('Pattern to remove: ')
    if pattern ~= "" then
        vim.cmd("Cfilter! " .. pattern)
    end
end, Opts)

vim.keymap.set("n", "<leader>qe", function()
    vim.fn.setqflist({})
    vim.cmd("cclose")
end, Opts)

local qf_scroll = function(direction)
    local status, result = pcall(function()
        vim.cmd("c" .. direction)
    end)

    if not status then
        local backup_direction

        if direction == "prev" then
            backup_direction = "last"
        elseif direction == "next" then
            backup_direction = "first"
        else
            print("Invalid direction: " .. direction)
            return
        end

        if result and type(result) == "string" and string.find(result, "E553") then
            vim.cmd("c" .. backup_direction)
            vim.cmd("normal! zz")
        elseif result and type(result) == "string" and string.find(result, "E42") then
        elseif result then
            print(result)
        end
    else
        vim.cmd("normal! zz")
    end
end

vim.keymap.set("n", "[q", function()
    qf_scroll("prev")
end, Opts)

vim.keymap.set("n", "]q", function()
    qf_scroll("next")
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

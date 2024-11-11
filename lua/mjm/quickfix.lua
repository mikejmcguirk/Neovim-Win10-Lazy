local ut = require("mjm.utils")

---@return boolean
local check_if_qf_open = function()
    for _, win in ipairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 then
            return true
        end
    end
    return false
end

---@return boolean
local check_if_qf_empty = function()
    if #vim.fn.getqflist() == 0 then
        print("Quickfix list is empty")
        return true
    else
        return false
    end
end

vim.keymap.set("n", "<leader>qt", function()
    if check_if_qf_open() then
        vim.api.nvim_exec2("cclose", {})
    else
        vim.api.nvim_exec2("botright copen", {})
    end
end)

vim.keymap.set("n", "<leader>ql", function()
    vim.api.nvim_exec2("cclose", {})
    vim.fn.setqflist({})
end)

---@param opts table
---@return nil
local grep_wrapper = function(opts)
    local pattern = ut.get_input("Enter Pattern: ")
    if pattern == "" then
        return
    end
    local args = { pattern }

    opts = vim.deepcopy(opts or {}, true)
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
    vim.api.nvim_exec2("botright copen", {})
end

vim.opt.grepprg = "rg --line-number"
vim.opt.grepformat = "%f:%l:%m"

vim.keymap.set("n", "<leader>qgn", function()
    grep_wrapper({})
end)
-- This command depends on the grepprg being set to ripgrep
vim.keymap.set("n", "<leader>qgi", function()
    grep_wrapper({ insensitive = true })
end)

---@param opts? table
---@return nil
local diags_to_qf = function(opts)
    opts = vim.deepcopy(opts or {}, true)
    local cur_buf = opts.cur_buf or false
    local bufnr = nil
    if cur_buf then
        if not ut.check_modifiable() then
            return
        end

        bufnr = 0
    end

    local err_only = opts.err_only or false
    local raw_diags = nil
    if err_only then
        raw_diags = vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR })
    else
        raw_diags = vim.diagnostic.get(bufnr)
    end

    if #raw_diags == 0 then
        if err_only then
            print("No errors")
        else
            print("No diagnostics")
        end
        vim.fn.setqflist({})
        vim.api.nvim_exec2("cclose", {})
        return
    end

    local severity_map = {
        [vim.diagnostic.severity.ERROR] = "E",
        [vim.diagnostic.severity.WARN] = "W",
        [vim.diagnostic.severity.INFO] = "I",
        [vim.diagnostic.severity.HINT] = "H",
    }

    ---@param raw_diag table
    ---@return table
    local convert_diag = function(raw_diag)
        local diag_source = ""
        if raw_diag.source then
            diag_source = raw_diag.source .. ": "
        end
        local diag_code = ""
        if raw_diag.code then
            diag_code = "[" .. raw_diag.code .. "] "
        end
        local diag_message = raw_diag.message or ""

        local converted_diag = {
            bufnr = raw_diag.bufnr,
            filename = vim.fn.bufname(raw_diag.bufnr),
            lnum = raw_diag.lnum + 1,
            end_lnum = raw_diag.end_lnum + 1,
            col = raw_diag.col + 1,
            end_col = raw_diag.end_col,
            text = diag_source .. diag_code .. diag_message,
            type = severity_map[raw_diag.severity],
        }

        return converted_diag
    end

    local diags_for_qf = vim.tbl_map(convert_diag, raw_diags)
    vim.fn.setqflist(diags_for_qf, "r")
    vim.api.nvim_exec2("botright copen", {})
end

vim.keymap.set("n", "<leader>qi", function()
    diags_to_qf()
end)
vim.keymap.set("n", "<leader>qu", function()
    diags_to_qf({ cur_buf = true })
end)
vim.keymap.set("n", "<leader>qe", function()
    diags_to_qf({ err_only = true })
end)

vim.api.nvim_exec2("packadd cfilter", {})

-- NOTE: cfilter only works on the "text" portion of the qf entry
---@param type string
---@return nil
local cfilter_wrapper = function(type)
    if not check_if_qf_open() then
        vim.notify("Quickfix list not open")
    end
    if check_if_qf_empty() then
        vim.notify("Quickfix list is closed")
    end

    local prompt = nil
    local use_bang = nil
    if type == "k" then
        prompt = "Pattern to keep: "
        use_bang = false
    elseif type == "r" then
        prompt = "Pattern to remove: "
        use_bang = true
    else
        print("Invalid filter type")
        return
    end

    local pattern = ut.get_input(prompt)
    if pattern == "" then
        return
    end

    vim.api.nvim_cmd({ cmd = "Cfilter", bang = use_bang, args = { pattern } }, {})
end

vim.keymap.set("n", "<leader>qk", function()
    cfilter_wrapper("k")
end)
vim.keymap.set("n", "<leader>qr", function()
    cfilter_wrapper("r")
end)

-- TODO: Add the ability to take count into this
---@param scroll_cmd string
---@return nil
local qf_scroll_wrapper = function(scroll_cmd)
    if check_if_qf_empty() then
        return
    end

    vim.api.nvim_exec2("botright copen", {})

    local backup_cmd = nil
    if scroll_cmd == "cprev" then
        backup_cmd = "clast"
    elseif scroll_cmd == "cnext" then
        backup_cmd = "cfirst"
    else
        print("Invalid scroll cmd")
        return
    end

    local status, result = pcall(function()
        vim.api.nvim_exec2(scroll_cmd, {})
    end)

    if (not status) and type(result) == "string" and string.find(result, "E553") then
        vim.api.nvim_exec2(backup_cmd, {})
    elseif not status then
        vim.api.nvim_err_writeln(result or "Unknown error in qf_scroll_wraper")
        return
    end

    vim.api.nvim_exec2("norm! zz", {})
end

vim.keymap.set("n", "[q", function()
    qf_scroll_wrapper("cprev")
end)
vim.keymap.set("n", "]q", function()
    qf_scroll_wrapper("cnext")
end)
-- TODO: Rewrite these with a pcall
vim.keymap.set("n", "[Q", "<cmd>cfirst<cr>")
vim.keymap.set("n", "]Q", "<cmd>clast<cr>")

local gf = require("mjm.global_funcs")

---@return boolean
local check_if_qf_open = function()
    for _, win in ipairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 then
            return true
        end
    end

    return false
end

vim.keymap.set("n", "<leader>qt", function()
    local qf_open = check_if_qf_open()

    if qf_open then
        vim.api.nvim_exec2("cclose", {})

        return
    end

    vim.api.nvim_exec2("botright copen", {})
end)

vim.opt.grepprg = "rg --line-number"
vim.opt.grepformat = "%f:%l:%m"

local grep_wrapper = function(options)
    local pattern = gf.get_user_input("Enter Pattern: ")

    if pattern == "" then
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
    vim.api.nvim_exec2("botright copen", {})
end

vim.keymap.set("n", "<leader>qgn", function()
    grep_wrapper()
end)

-- This command depends on the grepprg being set to ripgrep
vim.keymap.set("n", "<leader>qgi", function()
    grep_wrapper({ insensitive = true })
end)

---@param origin string
---@return nil
local diags_to_qf = function(origin, severity_cap)
    local raw_diags = {}

    if origin == "b" then
        raw_diags = vim.diagnostic.get(nil)
    elseif origin == "c" then
        local non_diag_fts = {
            "NvimTree",
            "qf",
            "help",
            "git",
            "harpoon",
            "tsplayground",
        }

        if vim.tbl_contains(non_diag_fts, vim.bo.filetype) then
            print("In non-diagnostic producing buffer")

            return
        end

        raw_diags = vim.diagnostic.get(0)
    elseif origin == "w" then
        local all_wins = vim.api.nvim_list_wins()

        for _, win in ipairs(all_wins) do
            local win_buf = vim.api.nvim_win_get_buf(win)
            local win_diags = vim.diagnostic.get(win_buf)

            vim.list_extend(raw_diags, win_diags)
        end
    else
        print("Invalid origin")

        return
    end

    if severity_cap == nil then
        severity_cap = 4
    end

    local severity_map = {
        [vim.diagnostic.severity.ERROR] = "E",
        [vim.diagnostic.severity.WARN] = "W",
        [vim.diagnostic.severity.INFO] = "I",
        [vim.diagnostic.severity.HINT] = "H",
    }

    if severity_map[severity_cap] == nil then
        vim.api.nvim_err_writeln("Invalid severity cap")

        return
    end

    if severity_cap < 4 then
        raw_diags = vim.tbl_filter(function(diag)
            return diag.severity <= severity_cap
        end, raw_diags)
    end

    if #raw_diags == 0 then
        print("No diagnostics")

        return
    end

    ---@param raw_diag table
    ---@return table
    local convert_diag = function(raw_diag)
        local diag_source = raw_diag.source or ""

        if diag_source ~= "" then
            diag_source = diag_source .. ": "
        end

        local diag_code = raw_diag.code or ""

        if diag_code ~= "" then
            diag_code = "[" .. diag_code .. "] "
        end

        local diag_message = raw_diag.message or ""
        local diag_text = diag_source .. diag_code .. diag_message

        local converted_diag = {
            bufnr = raw_diag.bufnr,
            filename = vim.fn.bufname(raw_diag.bufnr),
            lnum = raw_diag.lnum + 1,
            end_lnum = raw_diag.end_lnum + 1,
            col = raw_diag.col,
            end_col = raw_diag.end_col,
            text = diag_text,
            type = severity_map[raw_diag.severity],
        }

        return converted_diag
    end

    local diags_for_qf = vim.tbl_map(convert_diag, raw_diags)
    vim.fn.setqflist(diags_for_qf, "r")
    vim.api.nvim_exec2("botright copen", {})
end

vim.keymap.set("n", "<leader>qiq", function()
    diags_to_qf("b")
end)

vim.keymap.set("n", "<leader>qiu", function()
    diags_to_qf("c")
end)

vim.keymap.set("n", "<leader>qio", function()
    diags_to_qf("w")
end)

vim.keymap.set("n", "<leader>qii", function()
    diags_to_qf("b", 2)
end)

vim.keymap.set("n", "<leader>qif", function()
    diags_to_qf("c", 2)
end)

vim.keymap.set("n", "<leader>qiw", function()
    diags_to_qf("w", 2)
end)

vim.api.nvim_exec2("packadd cfilter", {})

---@param type string
local cfilter_wrapper = function(type)
    if not check_if_qf_open() then
        print("Quickfix list not open")

        return
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
        print("Invalid type")

        return
    end

    local pattern = gf.get_user_input(prompt)

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

vim.keymap.set("n", "<leader>ql", function()
    vim.fn.setqflist({})
    vim.api.nvim_exec2("cclose", {})
end)

local qf_scroll_wrapper = function(scroll_cmd)
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

    if status then
        vim.api.nvim_exec2("normal! zz", {})

        return
    end

    if not result then
        vim.api.nvim_err_writeln("Unknown error")

        return
    end

    if type(result) == "string" and string.find(result, "E553") then
        vim.api.nvim_exec2(backup_cmd, {})
        vim.api.nvim_exec2("normal! zz", {})

        return
    elseif type(result) == "string" and string.find(result, "E42") then
        return
    end

    vim.api.nvim_err_writeln(result)
end

vim.keymap.set("n", "[q", function()
    qf_scroll_wrapper("cprev")
end)

vim.keymap.set("n", "]q", function()
    qf_scroll_wrapper("cnext")
end)

vim.keymap.set("n", "[Q", "<cmd>cfirst<cr>")
vim.keymap.set("n", "]Q", "<cmd>clast<cr>")

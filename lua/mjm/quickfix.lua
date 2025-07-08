local ut = require("mjm.utils")

---@return boolean
local is_qf_open = function()
    for _, win in ipairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 then
            return true
        end
    end

    return false
end

---@return boolean
local is_qf_empty = function()
    if #vim.fn.getqflist() == 0 then
        return true
    else
        return false
    end
end

vim.keymap.set("n", "<leader>qt", function()
    if is_qf_open() then
        vim.cmd("cclose")
    else
        vim.cmd("botright copen")
    end
end)

vim.keymap.set("n", "<leader>ql", function()
    vim.cmd("cclose")
    vim.fn.setqflist({})
end)

local severity_map = {
    [vim.diagnostic.severity.ERROR] = "E",
    [vim.diagnostic.severity.WARN] = "W",
    [vim.diagnostic.severity.INFO] = "I",
    [vim.diagnostic.severity.HINT] = "H",
} ---@type string

---@param raw_diag table
---@return table
local convert_diag = function(raw_diag)
    local diag_source = raw_diag.source .. ": " or "" ---@type string
    local diag_message = raw_diag.message or "" ---@type string
    local diag_code = "" ---@type string
    if raw_diag.code then
        diag_code = "[" .. raw_diag.code .. "] "
    end

    return {
        bufnr = raw_diag.bufnr,
        filename = vim.fn.bufname(raw_diag.bufnr),
        lnum = raw_diag.lnum + 1,
        end_lnum = raw_diag.end_lnum + 1,
        col = raw_diag.col + 1,
        end_col = raw_diag.end_col,
        text = diag_source .. diag_code .. diag_message,
        type = severity_map[raw_diag.severity],
    }
end

---@param opts? table
---@return nil
local diags_to_qf = function(opts)
    opts = vim.deepcopy(opts or {}, true)

    local cur_buf = opts.cur_buf or false ---@type boolean
    local bufnr = nil ---@type integer
    if cur_buf and (not ut.check_modifiable()) then
        return
    elseif cur_buf then
        bufnr = 0
    end

    local err_only = opts.err_only or false ---@type boolean
    ---@return table
    local get_diags = function()
        if err_only then
            return vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR })
        else
            return vim.diagnostic.get(bufnr)
        end
    end
    local raw_diags = get_diags() ---@type table

    if #raw_diags == 0 then
        if err_only then
            print("No errors")
        else
            print("No diagnostics")
        end

        vim.fn.setqflist({})
        vim.cmd("cclose")

        return
    end

    local diags_for_qf = vim.tbl_map(convert_diag, raw_diags)
    vim.fn.setqflist(diags_for_qf, "r")
    vim.cmd("botright copen")
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

---@param opts? table
---@return nil
local cfilter_wrapper = function(opts)
    if not is_qf_open() then
        vim.notify("Quickfix list not open")
        return
    end

    if is_qf_empty() then
        vim.notify("Quickfix list is empty")
        return
    end

    opts = vim.deepcopy(opts or {}, true)
    local pattern = nil ---@type string
    local bang = true ---@type boolean
    if opts.keep then
        pattern = ut.get_input("Pattern to keep: ")
        bang = false
    else
        pattern = ut.get_input("Pattern to remove: ")
    end

    if pattern ~= "" then
        vim.api.nvim_cmd({ cmd = "Cfilter", bang = bang, args = { pattern } }, {})
    end
end

vim.keymap.set("n", "<leader>qk", function()
    cfilter_wrapper({ keep = true })
end)

vim.keymap.set("n", "<leader>qr", function()
    cfilter_wrapper()
end)

-- TODO: Add the ability to take count into this
---@param opts? { prev: boolean }
---@return nil
local qf_scroll_wrapper = function(opts)
    if is_qf_empty() then
        return
    end

    vim.cmd("botright copen") -- Run cmd after this to move focus to qf item
    opts = vim.deepcopy(opts or {}, true)
    local status, result = pcall(function()
        if opts.prev then
            vim.cmd("cprev")
        else
            vim.cmd("cnext")
        end
    end) ---@type boolean, unknown|nil

    if status then
        vim.cmd("norm! zz")
        return
    end

    if type(result) == "string" and string.find(result, "E553") then
        if opts.prev then
            vim.cmd("clast")
        else
            vim.cmd("cfirst")
        end

        vim.cmd("norm! zz")
        return
    end

    vim.api.nvim_echo({ { result or "Unknown error in qf_scroll_wraper" } }, true, { err = true })
end

vim.keymap.set("n", "[q", function()
    qf_scroll_wrapper({ prev = true })
end)

vim.keymap.set("n", "]q", function()
    qf_scroll_wrapper()
end)

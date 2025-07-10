local ut = require("mjm.utils")

---@param opts? table
local is_error_open = function(opts)
    opts = opts or {}
    local loclist = 0
    if opts.loclist then
        loclist = 1
    end

    for _, win in ipairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 and win.loclist == loclist then
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

local has_loc_list = function()
    local win = vim.api.nvim_get_current_win()
    local loclist = vim.fn.getloclist(win)
    if loclist and #loclist > 0 then
        return true
    else
        return false
    end
end

-- Use error_closer here to get the inside location list notification
vim.keymap.set("n", "cuc", function()
    ut.list_closer()
end)

vim.keymap.set("n", "cup", function()
    if is_error_open({ loclist = true }) then
        vim.notify("Location list is open")
    else
        vim.cmd("botright copen")
    end
end)

vim.keymap.set("n", "cui", function()
    if ut.list_closer() then
        return
    end

    if is_error_open({ loclist = true }) then
        vim.notify("Location list is open")
        return
    end

    vim.cmd("botright copen")
end)

vim.keymap.set("n", "coc", function()
    ut.list_closer({ loclist = true })
end)

vim.keymap.set("n", "cop", function()
    if is_error_open() then
        vim.notify("Quickfix list is open")
    else
        vim.cmd("botright lopen")
    end
end)

vim.keymap.set("n", "coi", function()
    if ut.list_closer({ loclist = true }) then
        return
    end

    if is_error_open() then
        vim.notify("Quickfix list is open")
        return
    end

    if not has_loc_list() then
        vim.notify("No location list for this window")
        return
    end

    vim.cmd("botright lopen")
end)

vim.keymap.set("n", "duu", function()
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
    raw_diag = raw_diag or {}
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
---@return table
local get_diags = function(opts)
    opts = opts or {}
    local err_only = opts.err_only or false ---@type boolean
    if err_only then
        return vim.diagnostic.get(opts.bufnr or nil, { severity = vim.diagnostic.severity.ERROR })
    else
        return vim.diagnostic.get(opts.bufnr or nil)
    end
end

-- TODO: Buffer specific diagnostics should be sent to location lists instead
-- So you would have:
--- yui (project diags to qf)
--- yue (projects errors to qf)
--- yoi (buffer diags to ll)
--- yoe (buffer errors to ll)
-- This allows for more flexibility with what diags are being viewed, using patterns that
-- alleviate memory overload
-- TODO: Consider using vim.diagnostic.setqflist in the future if enough features are added
---@param opts? table
---@return nil
local diags_to_qf = function(opts)
    opts = opts or {}

    local cur_buf = opts.cur_buf or false ---@type boolean
    local bufnr = nil ---@type integer
    if cur_buf and (not ut.check_modifiable()) then
        return
    elseif cur_buf then
        bufnr = 0
    end

    local err_only = opts.err_only or false ---@type boolean
    local raw_diags = get_diags({ err_only = err_only, bufnr = bufnr }) ---@type table
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

    local diags_for_qf = vim.tbl_map(convert_diag, raw_diags) ---@type table
    vim.fn.setqflist(diags_for_qf, "r")
    vim.cmd("botright copen")
end

vim.keymap.set("n", "yui", function()
    diags_to_qf()
end)

vim.keymap.set("n", "yuu", function()
    diags_to_qf({ cur_buf = true })
end)

vim.keymap.set("n", "yue", function()
    diags_to_qf({ err_only = true })
end)

---@param opts? table
---@return nil
local cfilter_wrapper = function(opts)
    if not is_error_open() then
        vim.notify("Quickfix list not open")
        return
    end

    if is_qf_empty() then
        vim.notify("Quickfix list is empty")
        return
    end

    opts = opts or {}
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

vim.keymap.set("n", "duk", function()
    cfilter_wrapper({ keep = true })
end)

vim.keymap.set("n", "dur", function()
    cfilter_wrapper()
end)

-- TODO: Make this take a count
---@param opts? table
---@return nil
local qf_scroll_wrapper = function(opts)
    if is_qf_empty() then
        vim.notify("Quickfix list is empty")
        return
    end

    opts = opts or {}
    local cmd = "cnext"
    if opts.prev then
        cmd = "cprev"
    end

    vim.cmd("botright copen")
    local ok, err = pcall(function()
        vim.cmd(cmd)
    end)

    if type(err) == "string" and string.find(err, "E553") then
        local backup_cmd = "cfirst"
        if opts.prev then
            backup_cmd = "clast"
        end

        ok, err = pcall(function()
            vim.cmd(backup_cmd)
        end)
    end

    if ok then
        vim.cmd("norm! zz")
    else
        vim.api.nvim_echo({ { err or "Unknown error in qf_scroll_wraper" } }, true, { err = true })
    end
end

vim.keymap.set("n", "[q", function()
    qf_scroll_wrapper({ prev = true })
end)

vim.keymap.set("n", "]q", function()
    qf_scroll_wrapper()
end)

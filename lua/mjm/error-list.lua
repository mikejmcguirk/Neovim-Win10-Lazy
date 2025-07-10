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
local is_error_empty = function(opts)
    opts = opts or {}
    local loclist = opts.loclist or false
    if loclist and #vim.fn.getloclist(vim.api.nvim_get_current_win()) > 0 then
        return false
    elseif (not loclist) and #vim.fn.getqflist() > 0 then
        return false
    end

    return true
end

vim.keymap.set("n", "cuc", "<cmd>cclose<cr>")
vim.keymap.set("n", "cup", function()
    ut.loc_list_closer()
    vim.cmd("botright copen")
end)

vim.keymap.set("n", "cuu", function()
    if is_error_open({ loclist = false }) then
        vim.cmd("cclose")
        return
    end

    ut.loc_list_closer()
    vim.cmd("botright copen")
end)

vim.keymap.set("n", "coc", function()
    ut.loc_list_closer()
end)

vim.keymap.set("n", "cop", function()
    local ok, err = pcall(function()
        vim.cmd("botright lopen")
    end)

    if ok then
        vim.cmd("cclose")
        return
    end

    local err_msg = err or "Unknown error opening location list"
    vim.api.nvim_echo({ { err_msg } }, true, { err = true })
end)

vim.keymap.set("n", "coo", function()
    if ut.loc_list_closer() then
        return
    end

    local ok, err = pcall(function()
        vim.cmd("botright lopen")
    end)

    if ok then
        vim.cmd("cclose")
        return
    end

    local err_msg = err or "Unknown error opening location list"
    vim.api.nvim_echo({ { err_msg } }, true, { err = true })
end)

for _, map in pairs({ "cuo", "cou" }) do
    vim.keymap.set("n", map, function()
        ut.loc_list_closer()
        vim.cmd("cclose")
    end)
end

-- Not a great way at the moment to deal with chistory and lhistory, so just wipe everything

vim.keymap.set("n", "dua", function()
    vim.cmd("cclose")
    vim.fn.setqflist({}, "f")
end)

vim.keymap.set("n", "doa", function()
    ut.loc_list_closer()
    vim.fn.setloclist(vim.api.nvim_get_current_win(), {}, "f")
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

    if is_error_empty() then
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
local err_scroll_wrapper = function(opts)
    opts = opts or {}
    if is_error_empty({ loclist = opts.loclist or false }) then
        if opts.loclist then
            vim.notify("Location list is empty")
        else
            vim.notify("Quickfix list is empty")
        end

        return
    end

    local prefix = "c"
    if opts.loclist then
        prefix = "l"
    end

    local cmd = prefix .. "next"
    if opts.prev then
        cmd = prefix .. "prev"
    end

    vim.cmd("botright " .. prefix .. "open")
    local ok, err = pcall(function()
        vim.cmd(cmd)
    end)

    if type(err) == "string" and string.find(err, "E553") then
        local backup_cmd = prefix .. "first"
        if opts.prev then
            backup_cmd = prefix .. "last"
        end

        ok, err = pcall(function()
            vim.cmd(backup_cmd)
        end)
    end

    if ok then
        vim.cmd("norm! zz")
    else
        local err_msg = err or "Unknown error in err_scroll_wrapper"
        vim.api.nvim_echo({ { err_msg } }, true, { err = true })
    end
end

vim.keymap.set("n", "[q", function()
    err_scroll_wrapper({ prev = true })
end)

vim.keymap.set("n", "]q", function()
    err_scroll_wrapper()
end)

vim.keymap.set("n", "[l", function()
    err_scroll_wrapper({ loclist = true, prev = true })
end)

vim.keymap.set("n", "]l", function()
    err_scroll_wrapper({ loclist = true })
end)

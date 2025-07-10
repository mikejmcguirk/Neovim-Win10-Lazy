-- Override Nvim default behavior where new windows get a copy of the previous window's loc list
vim.api.nvim_create_autocmd("WinNew", {
    group = vim.api.nvim_create_augroup("new_llist_delete", { clear = true }),
    pattern = "*",
    callback = function()
        vim.fn.setloclist(0, {}, "f")
    end,
})

---@param opts? table
local is_error_open = function(opts)
    opts = opts or {}
    local loclist = opts.loclist and 1 or 0
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

local ut = require("mjm.utils")
local open_qf_list = function()
    ut.loc_list_closer()
    vim.cmd("botright copen")
end

local open_loc_list = function()
    -- Not the best to do this before verifying the loc list opened, but having the qf list open
    -- while the loc list opens messes up its formatting
    vim.cmd("cclose")
    -- Nvim already internally checks if an active qf window is available. No need to
    -- duplicate logic
    -- In theory, this should only be run after checking that a valid loc list is present,
    -- but the pcall is here for defensive coding purposes
    local ok, err = pcall(function()
        vim.cmd("lopen")
    end)

    if not ok then
        local err_msg = err or "Unknown error opening location list"
        vim.api.nvim_echo({ { err_msg } }, true, { err = true })
    end
end

vim.keymap.set("n", "cuc", "<cmd>cclose<cr>")
vim.keymap.set("n", "cup", function()
    open_qf_list()
end)

vim.keymap.set("n", "cuu", function()
    if is_error_open({ loclist = false }) then
        return vim.cmd("cclose")
    end

    open_qf_list()
end)

vim.keymap.set("n", "coc", "<cmd>lclose<cr>")
vim.keymap.set("n", "cop", function()
    local cur_win = vim.api.nvim_get_current_win() ---@type integer
    local cur_win_info = vim.fn.getwininfo(cur_win)[1]
    if cur_win_info.quickfix == 1 then
        return -- qf windows cannot have associated llists
    end

    local llist_id = vim.fn.getloclist(cur_win, { id = 0 }).id
    if llist_id == 0 then
        return vim.notify("No location list for this window")
    end

    open_loc_list()
end)

vim.keymap.set("n", "coo", function()
    local cur_win = vim.api.nvim_get_current_win() ---@type integer
    local cur_win_info = vim.fn.getwininfo(cur_win)[1]
    if cur_win_info.quickfix == 1 and cur_win_info.loclist == 1 then
        return vim.cmd("lclose")
    end

    -- See :h getqflist what section for id field. Zero gets ID for current list
    local llist_id = vim.fn.getloclist(cur_win, { id = 0 }).id
    -- See :h getqflist returned dictionary for what items
    if llist_id == 0 then
        return vim.notify("No location list for this window")
    end

    for _, win in ipairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 and win.loclist == 1 then
            local this_id = vim.fn.getloclist(win.winid, { id = 0 }).id
            if this_id == llist_id then
                return vim.cmd("lclose")
            end
        end
    end

    open_loc_list()
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

-- TODO: Consider using vim.diagnostic.setqflist in the future if enough features are added
---@param opts? table
---@return nil
local all_diags_to_qf = function(opts)
    opts = opts or {}
    local severity = nil
    if opts.highest then
        severity = ut.get_highest_severity({ buf = nil })
    else
        local error = vim.diagnostic.severity.ERROR ---@type integer
        local hint = vim.diagnostic.severity.HINT ---@type integer
        severity = { min = opts.err_only and error or hint }
    end

    ---@diagnostic disable: undefined-doc-name
    ---@type vim.diagnostic[]
    local raw_diags = vim.diagnostic.get(nil, { severity = severity })
    if #raw_diags == 0 then
        local name = opts.err_only and "errors" or "diagnostics" ---@type string
        -- At least for now, will omit clearing the qflist
        vim.cmd("cclose")
        return vim.notify("No " .. name)
    end

    local diags_for_qf = vim.tbl_map(convert_diag, raw_diags) ---@type table
    assert(#raw_diags == #diags_for_qf, "Coverted diags were filtered")
    vim.fn.setqflist(diags_for_qf, "r")
    open_qf_list()
end

---@param opts? table
local buf_diags_to_loc_list = function(opts)
    opts = opts or {}
    local cur_win = vim.api.nvim_get_current_win() ---@type integer
    local cur_buf = vim.api.nvim_win_get_buf(cur_win) ---@type integer
    if not ut.check_modifiable(cur_buf) then
        return
    end

    local severity = nil
    if opts.highest then
        severity = ut.get_highest_severity({ buf = cur_buf })
    else
        local error = vim.diagnostic.severity.ERROR ---@type integer
        local hint = vim.diagnostic.severity.HINT ---@type integer
        severity = { min = opts.err_only and error or hint }
    end

    ---@diagnostic disable: undefined-doc-name
    ---@type vim.diagnostic[]
    local raw_diags = vim.diagnostic.get(cur_buf, { severity = severity })
    if #raw_diags == 0 then
        local name = opts.err_only and "errors" or "diagnostics" ---@type string
        -- At least for now, will omit clearing the llist
        vim.cmd("lclose")
        return vim.notify("No " .. name)
    end

    local diags_for_ll = vim.tbl_map(convert_diag, raw_diags) ---@type table ---@type table
    assert(#raw_diags == #diags_for_ll, "Coverted diags were filtered")
    vim.fn.setloclist(cur_win, diags_for_ll, "r")
    open_loc_list()
end

-- TODO: Add one of these for highest priority diags

vim.keymap.set("n", "yui", function()
    all_diags_to_qf()
end)

vim.keymap.set("n", "yue", function()
    all_diags_to_qf({ err_only = true })
end)

vim.keymap.set("n", "yuh", function()
    all_diags_to_qf({ highest = true })
end)

vim.keymap.set("n", "yoi", function()
    buf_diags_to_loc_list()
end)

vim.keymap.set("n", "yoe", function()
    buf_diags_to_loc_list({ err_only = true })
end)

vim.keymap.set("n", "yoh", function()
    buf_diags_to_loc_list({ highest = true })
end)

---@param opts? table
---@return nil
local filter_wrapper = function(opts)
    opts = opts or {}
    local name = opts.loclist and "Location" or "Quickfix"
    local prefix = opts.loclist and "L" or "C"

    if not is_error_open({ loclist = opts.loclist }) then
        return vim.notify(name .. " list not open")
    end

    if is_error_empty({ loclist = opts.loclist }) then
        return vim.notify(name .. " list is empty")
    end

    local pattern = ut.get_input("Pattern to " .. (opts.remove and "remove: " or "keep: "))
    local cmd = prefix .. "filter"
    if pattern ~= "" then
        vim.api.nvim_cmd({ cmd = cmd, bang = opts.remove, args = { pattern } }, {})
    end
end

vim.keymap.set("n", "duk", function()
    filter_wrapper()
end)

vim.keymap.set("n", "dur", function()
    filter_wrapper({ remove = true })
end)

vim.keymap.set("n", "dok", function()
    filter_wrapper({ loclist = true })
end)

vim.keymap.set("n", "dor", function()
    filter_wrapper({ loclist = true, remove = true })
end)

-- TODO: Make this take a count
---@param opts? table
---@return nil
local err_scroll_wrapper = function(opts)
    opts = opts or {}
    local name = opts.loclist and "Location" or "Quickfix"
    if is_error_empty({ loclist = opts.loclist or false }) then
        return vim.notify(name .. " list is empty")
    end

    local prefix = opts.loclist and "l" or "c"
    local cmd = opts.prev and prefix .. "prev" or prefix .. "next"
    if opts.loclist then
        open_loc_list()
    else
        open_qf_list()
    end

    local ok, err = pcall(function()
        vim.cmd(cmd)
    end)

    if type(err) == "string" and string.find(err, "E553") then
        local backup_cmd = opts.prev and prefix .. "last" or prefix .. "first"
        ok, err = pcall(function()
            vim.cmd(backup_cmd)
        end)
    end

    if not ok then
        local err_msg = err or "Unknown error in err_scroll_wrapper"
        return vim.api.nvim_echo({ { err_msg } }, true, { err = true })
    end

    vim.cmd("norm! zz")
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

---Assumes gregprg is ripgrep
---@param opts table
---@return nil
local grep_wrapper = function(opts)
    local pattern = ut.get_input("Enter Pattern: ") ---@type string
    if pattern == "" then
        return
    end

    local args = { pattern } ---@type table
    opts = opts or {}
    local cmd = opts.loclist and "lgrep" or "grep"
    if opts.insensitive then
        table.insert(args, "-i")
    end

    local magic = opts.loclist and { file = true } or {}
    if opts.loclist then
        table.insert(args, "%")
    end

    local grep_cmd = {
        args = args,
        bang = true,
        cmd = cmd,
        mods = { emsg_silent = true },
        magic = magic,
    }

    vim.api.nvim_cmd(grep_cmd, {})
    if opts.loclist then
        open_loc_list()
    else
        open_qf_list()
    end
end

vim.keymap.set("n", "yugs", function()
    grep_wrapper({})
end)

vim.keymap.set("n", "yugi", function()
    grep_wrapper({ insensitive = true })
end)

vim.keymap.set("n", "yogs", function()
    grep_wrapper({ loclist = true })
end)

vim.keymap.set("n", "yogi", function()
    grep_wrapper({ loclist = true, insensitive = true })
end)

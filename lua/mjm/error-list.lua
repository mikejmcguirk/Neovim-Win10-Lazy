-- Override Nvim default behavior where new windows get a copy of the previous window's loc list
vim.api.nvim_create_autocmd("WinNew", {
    group = vim.api.nvim_create_augroup("new_llist_delete", { clear = true }),
    pattern = "*",
    callback = function()
        vim.fn.setloclist(0, {}, "f")
    end,
})

---@param opts table(winid:integer)
---@return number
local get_loc_id = function(opts)
    opts = opts or {}
    if not opts.winid then
        return 0
    end

    -- See :h getqflist what section for id field. Zero gets ID for current list
    -- See :h getqflist returned dictionary for what items
    local loc_id = vim.fn.getloclist(opts.winid, { id = 0 }).id ---@type any
    assert(type(loc_id) == "number")
    return loc_id
end

--- NOTE: This function does not check that the id parameter is present in a non-qf window
---@param opts table{qfid:number}
---@return boolean
local has_open_associated_loc = function(opts)
    opts = opts or {}
    if not opts.qfid then
        return false
    end

    for _, win in ipairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 and win.loclist == 1 then
            if vim.fn.getloclist(win.winid, { id = 0 }).id == opts.qfid then
                return true
            end
        end
    end

    return false
end

---@param opts? table{loclist:boolean}
---@return boolean
local is_error_open = function(opts)
    opts = opts or {}
    if not opts.loclist then
        for _, win in ipairs(vim.fn.getwininfo()) do
            if win.quickfix == 1 and win.loclist == 0 then
                return true
            end
        end

        return false
    end

    local cur_win = vim.api.nvim_get_current_win() ---@type integer
    local cur_win_info = vim.fn.getwininfo(cur_win)[1] ---@type vim.fn.getwininfo.ret.item
    if cur_win_info.quickfix == 1 and cur_win_info.loclist == 1 then
        return true
    end

    local loc_id = get_loc_id({ winid = cur_win }) ---@type number
    if loc_id == 0 then
        return false
    end

    if has_open_associated_loc({ id = loc_id }) then
        return true
    end

    return false
end

---@param opts? table{loclist:boolean}
---@return boolean
local is_error_empty = function(opts)
    opts = opts or {}
    if opts.loclist and #vim.fn.getloclist(vim.api.nvim_get_current_win()) > 0 then
        return false
    elseif (not opts.loclist) and #vim.fn.getqflist() > 0 then
        return false
    end

    return true
end

local ut = require("mjm.utils")
---@return nil
local open_qf_list = function()
    ut.loc_list_closer()
    vim.cmd("botright copen")
end

---@return nil
local open_loc_list = function()
    -- Not the best to do this before verifying the loc list opened, but having the qf list open
    -- while the loc list opens messes up its formatting
    vim.cmd("cclose")
    -- Because the function can't guarantee that we've checked for a valid loc list, pcall
    local ok, err = pcall(function()
        vim.cmd("lopen")
    end)

    if ok then
        return
    end

    local err_msg = err or "Unknown error opening location list"
    vim.api.nvim_echo({ { err_msg } }, true, { err = true })
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
    if vim.fn.getwininfo(cur_win)[1].quickfix == 1 then
        return -- qf windows cannot have associated loc lists
    end

    local llist_id = vim.fn.getloclist(cur_win, { id = 0 }).id ---@type any
    assert(type(llist_id) == "number")
    if llist_id == 0 then
        return vim.notify("No location list for this window")
    end

    open_loc_list()
end)

vim.keymap.set("n", "coo", function()
    local cur_win = vim.api.nvim_get_current_win() ---@type integer
    local cur_win_info = vim.fn.getwininfo(cur_win)[1] ---@type vim.fn.getwininfo.ret.item
    if cur_win_info.quickfix == 1 and cur_win_info.loclist == 1 then
        return vim.cmd("lclose")
    end

    local loc_id = get_loc_id({ winid = cur_win }) ---@type number
    if loc_id == 0 then
        return vim.notify("No location list for this window")
    end

    if has_open_associated_loc({ id = loc_id }) then
        return vim.cmd("lclose")
    end

    open_loc_list()
end)

for _, map in pairs({ "cuo", "cou" }) do
    vim.keymap.set("n", map, function()
        ut.loc_list_closer()
        vim.cmd("cclose")
    end)
end

-- FUTURE: Might be future value in actually using the qf and loc list stacks

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
} ---@type table<integer, string>

---@param raw_diag table
---@return table
local convert_diag = function(raw_diag)
    raw_diag = raw_diag or {}
    local diag_source = raw_diag.source .. ": " or "" ---@type string
    local diag_message = raw_diag.message or "" ---@type string
    local diag_code = "" ---@type string
    -- For whatever reason, this doesn't work with an or
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

-- FUTURE: Consider using vim.diagnostic.setqflist if enough features are added
---@param opts? table{highest:boolean, err_only:boolean}
---@return nil
local all_diags_to_qf = function(opts)
    opts = opts or {}
    -- Running vim.diagnostic.get() twice is not ideal, but better than hacking together
    -- a manual diag filter
    local severity = opts.highest and ut.get_highest_severity({ buf = nil })
        or {
            min = opts.err_only and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.HINT,
        } ---@type integer|table{min:integer}

    ---@diagnostic disable: undefined-doc-name
    local raw_diags = vim.diagnostic.get(nil, { severity = severity }) ---@type vim.diagnostic[]
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

---@param opts? table{highest:boolean, err_only:boolean}
---@return nil
local buf_diags_to_loc_list = function(opts)
    opts = opts or {}
    local cur_win = vim.api.nvim_get_current_win() ---@type integer
    local buf = vim.api.nvim_win_get_buf(cur_win) ---@type integer
    if not ut.check_modifiable(buf) then
        return
    end

    local severity = opts.highest and ut.get_highest_severity({ buf = nil })
        or {
            min = opts.err_only and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.HINT,
        } ---@type integer|table{min:integer}

    ---@diagnostic disable: undefined-doc-name
    local raw_diags = vim.diagnostic.get(buf, { severity = severity }) ---@type vim.diagnostic[]
    if #raw_diags == 0 then
        local name = opts.err_only and "errors" or "diagnostics" ---@type string
        -- At least for now, will omit clearing the loc list
        vim.cmd("lclose")
        return vim.notify("No " .. name)
    end

    local diags_for_ll = vim.tbl_map(convert_diag, raw_diags) ---@type table
    assert(#raw_diags == #diags_for_ll, "Coverted diags were filtered")
    vim.fn.setloclist(cur_win, diags_for_ll, "r")
    open_loc_list()
end

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

---@param opts? table{loclist:boolean, remove:boolean}
---@return nil
local filter_wrapper = function(opts)
    opts = opts or {}
    local name = opts.loclist and "Location" or "Quickfix" ---@type string
    if not is_error_open({ loclist = opts.loclist }) then
        return vim.notify(name .. " list not open")
    end

    if is_error_empty({ loclist = opts.loclist }) then
        return vim.notify(name .. " list is empty")
    end

    ---@type string
    local pattern = ut.get_input("Pattern to " .. (opts.remove and "remove: " or "keep: "))
    if pattern ~= "" then
        local prefix = opts.loclist and "L" or "C" ---@type string
        local cmd = prefix .. "filter" ---@type string
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

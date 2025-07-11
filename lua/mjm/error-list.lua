-- Override Nvim default behavior where new windows get a copy of the previous window's loc list
vim.api.nvim_create_autocmd("WinNew", {
    group = vim.api.nvim_create_augroup("del_new_loclist", { clear = true }),
    pattern = "*",
    callback = function()
        vim.fn.setloclist(0, {}, "f")
    end,
})

-- Both Quickfix lists and Loclists are identified with quickfix-ID values
-- The terminology is used here for consistency

---@return boolean
local cur_buf_is_qf = function()
    if vim.api.nvim_get_option_value("filetype", { buf = 0 }) == "qf" then
        return true
    else
        return false
    end
end

---@return number
local get_cur_win_qf_id = function()
    -- See :h getqflist what section for id field. Zero gets ID for current list
    -- See :h getqflist returned dictionary for what items
    local qf_id = vim.fn.getloclist(vim.api.nvim_get_current_win(), { id = 0 }).id ---@type any
    assert(type(qf_id) == "number")
    return qf_id
end

local cur_win_has_loclist = function()
    if get_cur_win_qf_id() == 0 then
        return false
    else
        return true
    end
end

---@return boolean
local is_cur_win_loclist_open = function()
    if not cur_win_has_loclist() then
        return false
    end

    local qf_id = get_cur_win_qf_id()
    for _, w in ipairs(vim.fn.getwininfo()) do
        if w.quickfix == 1 and w.loclist == 1 then
            if vim.fn.getloclist(w.winid, { id = 0 }).id == qf_id then
                return true
            end
        end
    end

    return false
end

local is_qflist_open = function()
    for _, w in ipairs(vim.fn.getwininfo()) do
        if w.quickfix == 1 and w.loclist == 0 then
            return true
        end
    end

    return false
end

---@param opts? table{loclist:boolean}
---@return boolean
local is_list_empty = function(opts)
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
local open_qflist = function()
    ut.close_all_loclists()
    vim.cmd("botright copen")
end

---@return nil
local open_loclist = function()
    -- In theory, qflist should not be closed before verifying lopen is okay
    -- In practice, opening the loclist with the qflist open messes up formating
    -- lopen produces an error if no loclist is present. This function cannot be responsible for
    -- verifying one exists because the steps are situational. Defensively pcall instead
    vim.cmd("cclose")
    local ok, err = pcall(function()
        vim.cmd("lopen")
    end)

    if ok then
        return
    end

    vim.api.nvim_echo({ { err or "Unknown error opening location list" } }, true, { err = true })
end

vim.keymap.set("n", "cuc", "<cmd>cclose<cr>")
vim.keymap.set("n", "cup", function()
    open_qflist()
end)

vim.keymap.set("n", "cuu", function()
    if is_qflist_open() then
        return vim.cmd("cclose")
    else
        open_qflist()
    end
end)

vim.keymap.set("n", "coc", "<cmd>lclose<cr>")
vim.keymap.set("n", "cop", function()
    if cur_buf_is_qf() then
        return vim.notify("Inside qf buffer")
    end

    if cur_win_has_loclist() then
        open_loclist()
    else
        vim.notify("No location list for this window")
    end
end)

vim.keymap.set("n", "coo", function()
    if not cur_win_has_loclist() then -- The qflist is always id zero, so test fails
        return vim.notify("Current window does not have a location list")
    end

    if is_cur_win_loclist_open() then
        vim.cmd("lclose")
        return
    end

    open_loclist()
end)

for _, map in pairs({ "cuo", "cou" }) do
    vim.keymap.set("n", map, function()
        ut.close_all_loclists()
        vim.cmd("cclose")
    end)
end

-- FUTURE: Might be future value in actually using the qf and loc list stacks

vim.keymap.set("n", "dua", function()
    vim.cmd("cclose")
    vim.fn.setqflist({}, "f")
end)

vim.keymap.set("n", "doa", function()
    vim.cmd("lclose")
    vim.fn.setloclist(vim.api.nvim_get_current_win(), {}, "f")
end)

local severity_map = {
    [vim.diagnostic.severity.ERROR] = "E",
    [vim.diagnostic.severity.WARN] = "W",
    [vim.diagnostic.severity.INFO] = "I",
    [vim.diagnostic.severity.HINT] = "H",
} ---@type table<integer, string>

---@param diag table
---@return table
local convert_diag = function(diag)
    diag = diag or {}
    local source = diag.source .. ": " or "" ---@type string
    local message = diag.message or "" ---@type string
    local code = "" ---@type string
    -- For whatever reason, this doesn't work with an or
    if diag.code then
        code = "[" .. diag.code .. "] "
    end

    return {
        bufnr = diag.bufnr,
        filename = vim.fn.bufname(diag.bufnr),
        lnum = diag.lnum + 1,
        end_lnum = diag.end_lnum + 1,
        col = diag.col + 1,
        end_col = diag.end_col,
        text = source .. code .. message,
        type = severity_map[diag.severity],
    }
end

-- FUTURE: Consider using vim.diagnostic.setqflist if enough features are added
---@param opts? table{highest:boolean, err_only:boolean}
---@return nil
local all_diags_to_qflist = function(opts)
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

    local diags_for_qflist = vim.tbl_map(convert_diag, raw_diags) ---@type table
    assert(#raw_diags == #diags_for_qflist, "Coverted diags were filtered")
    vim.fn.setqflist(diags_for_qflist, "r")
    open_qflist()
end

---@param opts? table{highest:boolean, err_only:boolean}
---@return nil
local buf_diags_to_loclist = function(opts)
    opts = opts or {}
    local win = vim.api.nvim_get_current_win() ---@type integer
    local buf = vim.api.nvim_win_get_buf(win) ---@type integer
    if not ut.check_modifiable(buf) then
        return
    end

    local severity = opts.highest and ut.get_highest_severity({ buf = buf })
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

    local diags_for_loclist = vim.tbl_map(convert_diag, raw_diags) ---@type table
    assert(#raw_diags == #diags_for_loclist, "Coverted diags were filtered")
    vim.fn.setloclist(win, diags_for_loclist, "r")
    open_loclist()
end

vim.keymap.set("n", "yui", function()
    all_diags_to_qflist()
end)

vim.keymap.set("n", "yue", function()
    all_diags_to_qflist({ err_only = true })
end)

vim.keymap.set("n", "yuh", function()
    all_diags_to_qflist({ highest = true })
end)

vim.keymap.set("n", "yoi", function()
    buf_diags_to_loclist()
end)

vim.keymap.set("n", "yoe", function()
    buf_diags_to_loclist({ err_only = true })
end)

vim.keymap.set("n", "yoh", function()
    buf_diags_to_loclist({ highest = true })
end)

---@param opts? table{loclist:boolean, remove:boolean}
---@return nil
local filter_wrapper = function(opts)
    opts = opts or {}
    if opts.loclist and not cur_win_has_loclist() then
        return vim.notify("Current window has no location list")
    end

    local list = opts.loclist and "Location" or "Quickfix" ---@type string
    if is_list_empty({ loclist = opts.loclist }) then
        return vim.notify(list .. " list is empty")
    end

    ---@type string
    local action = opts.remove and "remove: " or "keep: "
    local pattern = ut.get_input(list .. " pattern to " .. action)
    if pattern ~= "" then
        local prefix = opts.loclist and "L" or "C" ---@type string
        vim.api.nvim_cmd({ cmd = prefix .. "filter", bang = opts.remove, args = { pattern } }, {})
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

---@param opts table
---@return nil
local grep_wrapper = function(opts)
    if cur_buf_is_qf() then
        return vim.notify("Inside qf buffer")
    end

    local pattern = ut.get_input("Enter Grep Pattern: ") ---@type string
    if pattern == "" then
        return
    end

    local args = { pattern } ---@type table
    opts = opts or {}
    if opts.insensitive then
        table.insert(args, "-i")
    end

    if opts.loclist then
        table.insert(args, "%")
    end

    vim.api.nvim_cmd({
        args = args,
        bang = true,
        cmd = opts.loclist and "lgrep" or "grep",
        mods = { emsg_silent = true },
        magic = opts.loclist and { file = true } or {},
    }, {})

    if opts.loclist then
        open_loclist()
    else
        open_qflist()
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

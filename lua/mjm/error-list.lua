local ut = require("mjm.utils")

vim.cmd("packadd! cfilter")

-- Override default behavior where new windows get a copy of the previous window's loclist
vim.api.nvim_create_autocmd("WinNew", {
    group = vim.api.nvim_create_augroup("del_new_loclist", { clear = true }),
    pattern = "*",
    callback = function()
        vim.fn.setloclist(0, {}, "f")
    end,
})

---@return nil
local function open_qflist()
    ut.close_all_loclists()
    vim.cmd("botright copen")
end

vim.keymap.set("n", "cuc", "<cmd>cclose<cr>")
vim.keymap.set("n", "cup", function()
    open_qflist()
end)

vim.keymap.set("n", "cuu", function()
    for _, w in ipairs(vim.fn.getwininfo()) do
        if w.quickfix == 1 and w.loclist == 0 then
            return vim.cmd("cclose")
        end
    end

    open_qflist()
end)

vim.keymap.set("n", "coc", "<cmd>lclose<cr>")
vim.keymap.set("n", "cop", function()
    if vim.api.nvim_get_option_value("filetype", { buf = 0 }) == "qf" then
        return vim.notify("Inside qf buffer")
    end

    if not (vim.fn.getloclist(vim.api.nvim_get_current_win(), { id = 0 }).id == 0) then
        vim.cmd("cclose | lopen")
    else
        vim.notify("Window has no location list")
    end
end)

vim.keymap.set("n", "coo", function()
    if vim.api.nvim_get_option_value("filetype", { buf = 0 }) == "qf" then
        return vim.notify("Inside qf buffer")
    end

    local qf_id = vim.fn.getloclist(vim.api.nvim_get_current_win(), { id = 0 }).id ---@type any
    if qf_id == 0 then
        return vim.notify("Window has no location list")
    end

    for _, w in ipairs(vim.fn.getwininfo()) do
        if w.quickfix == 1 and w.loclist == 1 then
            if vim.fn.getloclist(w.winid, { id = 0 }).id == qf_id then
                return vim.cmd("lclose")
            end
        end
    end

    vim.cmd("cclose | lopen")
end)

for _, map in pairs({ "cuo", "cou" }) do
    vim.keymap.set("n", map, function()
        ut.close_all_loclists()
        vim.cmd("cclose")
    end)
end

vim.keymap.set("n", "duc", function()
    vim.cmd("cclose")
    vim.fn.setqflist({}, "r")
end)

vim.keymap.set("n", "dua", function()
    vim.cmd("cclose")
    vim.fn.setqflist({}, "f")
end)

vim.keymap.set("n", "doc", function()
    vim.cmd("lclose")
    vim.fn.setloclist(vim.api.nvim_get_current_win(), {}, "r")
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
local function convert_diag(diag)
    diag = diag or {}
    local source = diag.source .. ": " or "" ---@type string
    local message = diag.message or "" ---@type string
    local code = diag.code and "[" .. diag.code .. "]" or "" --- @type string
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

-- LOW: I doubt this is the best way to get the highest severity, as it requires two pulls
-- from vim.diagnostic.get(). It might also be cleaner to use iter functions
-- FUTURE: Consider using vim.diagnostic.setqflist if enough features are added
---@param opts? table{highest:boolean, err_only:boolean}
---@return nil
local function all_diags_to_qflist(opts)
    opts = opts or {}
    -- Running vim.diagnostic.get() twice is not ideal, but better than hacking together
    -- a manual diag filter
    local severity = opts.highest and ut.get_top_severity({ buf = nil })
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
local function buf_diags_to_loclist(opts)
    opts = opts or {}
    local win = vim.api.nvim_get_current_win() ---@type integer
    local buf = vim.api.nvim_win_get_buf(win) ---@type integer
    if not ut.check_modifiable(buf) then
        return
    end

    local severity = opts.highest and ut.get_top_severity({ buf = buf })
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
    vim.cmd("cclose | lopen")
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
local function filter_wrapper(opts)
    opts = opts or {}

    if opts.loclist and vim.fn.getloclist(vim.api.nvim_get_current_win(), { id = 0 }).id == 0 then
        return vim.notify("Current window has no location list")
    end

    local list = opts.loclist and "Location" or "Quickfix" ---@type string

    if opts.loclist and #vim.fn.getloclist(vim.api.nvim_get_current_win()) > 0 then
        return vim.notify(list .. " list is empty")
    elseif (not opts.loclist) and #vim.fn.getqflist() > 0 then
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

local last_grep = nil
local last_lgrep = nil

---@param opts table
---@return nil
local function grep_wrapper(opts)
    opts = opts or {}
    if opts.loclist and vim.api.nvim_get_option_value("filetype", { buf = 0 }) == "qf" then
        return vim.notify("Inside qf buffer")
    end

    local pattern = opts.pattern or ut.get_input("Enter Grep Pattern: ") ---@type string
    if pattern == "" and opts.pattern then
        return vim.notify("Empty grep pattern", vim.log.levels.WARN)
    elseif pattern == "" then
        return
    end

    local args = { pattern } ---@type table
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
        --- @diagnostic disable: missing-fields
        mods = { emsg_silent = true },
        magic = opts.loclist and { file = true } or {},
    }, {})

    if opts.loclist then
        last_lgrep = pattern
        vim.cmd("cclose | lopen")
    else
        last_grep = pattern
        open_qflist()
    end
end

vim.keymap.set("n", "yugs", function()
    grep_wrapper({})
end)

vim.keymap.set("n", "yogs", function()
    grep_wrapper({ loclist = true })
end)

vim.keymap.set("n", "yugi", function()
    grep_wrapper({ insensitive = true })
end)

vim.keymap.set("n", "yogi", function()
    grep_wrapper({ insensitive = true, loclist = true })
end)

vim.keymap.set("n", "yugr", function()
    grep_wrapper({ pattern = last_grep })
end)

vim.keymap.set("n", "yogr", function()
    grep_wrapper({ pattern = last_lgrep, loclist = true })
end)

vim.keymap.set("n", "yugv", function()
    print(last_grep)
end)

vim.keymap.set("n", "yogv", function()
    print(last_lgrep)
end)

local function qf_scroll_wrapper(main, alt)
    local cmd_opts = { cmd = main, count = vim.v.count1 }
    local ok, err = pcall(vim.api.nvim_cmd, cmd_opts, {})

    if (not ok) and (err:match("E42") or err:match("E776")) then
        vim.notify(err:sub(#"Vim:" + 1))
        return
    end

    if (not ok) and err:match("E553") then
        local alt_opts = { cmd = alt }
        ok, err = pcall(vim.api.nvim_cmd, alt_opts, {})
    end

    if not ok then
        err = err and err:sub(#"Vim:" + 1) or "Unknown qf_scroll error"
        vim.notify(err, vim.log.levels.WARN)
        return
    end

    vim.cmd("norm! zz")
end

local scroll_maps = {
    { "[q", "cprev", "clast" },
    { "]q", "cnext", "crewind" },
    { "[l", "lprev", "llast" },
    { "]l", "lnext", "lrewind" },
}

for _, m in pairs(scroll_maps) do
    vim.keymap.set("n", m[1], function()
        qf_scroll_wrapper(m[2], m[3])
    end)
end

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
    require("mjm.utils").close_all_loclists()
    --- @diagnostic disable: missing-fields
    vim.api.nvim_cmd({ cmd = "copen", mods = { split = "botright" } }, {})
end

Map("n", "cuc", function()
    vim.api.nvim_cmd({ cmd = "ccl" }, {})
end)

Map("n", "cup", function()
    open_qflist()
end)

Map("n", "cuu", function()
    for _, w in ipairs(vim.fn.getwininfo()) do
        if w.quickfix == 1 and w.loclist == 0 and w.tabnr == vim.fn.tabpagenr() then
            vim.api.nvim_cmd({ cmd = "ccl" }, {})
            return
        end
    end

    open_qflist()
end)

Map("n", "coc", function()
    vim.api.nvim_cmd({ cmd = "lcl" }, {})
end)

Map("n", "cop", function()
    if vim.api.nvim_get_option_value("filetype", { buf = 0 }) == "qf" then
        vim.notify("Inside qf buffer")
        return
    end

    if not (vim.fn.getloclist(vim.api.nvim_get_current_win(), { id = 0 }).id == 0) then
        vim.api.nvim_cmd({ cmd = "ccl" }, {})
        vim.api.nvim_cmd({ cmd = "lop" }, {})
    else
        vim.notify("Window has no location list")
    end
end)

Map("n", "coo", function()
    if vim.api.nvim_get_option_value("filetype", { buf = 0 }) == "qf" then
        return vim.notify("Inside qf buffer")
    end

    local qf_id = vim.fn.getloclist(vim.api.nvim_get_current_win(), { id = 0 }).id ---@type any
    if qf_id == 0 then
        vim.notify("Window has no location list")
        return
    end

    for _, w in ipairs(vim.fn.getwininfo()) do
        if w.quickfix == 1 and w.loclist == 1 then
            if vim.fn.getloclist(w.winid, { id = 0 }).id == qf_id then
                vim.api.nvim_cmd({ cmd = "lcl" }, {})
                return
            end
        end
    end

    vim.api.nvim_cmd({ cmd = "ccl" }, {})
    vim.api.nvim_cmd({ cmd = "lop" }, {})
end)

for _, map in pairs({ "cuo", "cou" }) do
    Map("n", map, function()
        require("mjm.utils").close_all_loclists()
        vim.api.nvim_cmd({ cmd = "ccl" }, {})
    end)
end

Map("n", "duc", function()
    vim.api.nvim_cmd({ cmd = "ccl" }, {})
    vim.fn.setqflist({}, "r")
end)

Map("n", "dua", function()
    vim.api.nvim_cmd({ cmd = "ccl" }, {})
    vim.fn.setqflist({}, "f")
end)

Map("n", "doc", function()
    vim.api.nvim_cmd({ cmd = "lcl" }, {})
    vim.fn.setloclist(vim.api.nvim_get_current_win(), {}, "r")
end)

Map("n", "doa", function()
    vim.api.nvim_cmd({ cmd = "lcl" }, {})
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

    local source = diag.source and diag.source .. ": " or "" ---@type string
    local code = diag.code and "[" .. diag.code .. "]" or "" --- @type string
    local message = diag.message or "" ---@type string

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
---@param opts? {highest:boolean, err_only:boolean}
---@return nil
local function all_diags_to_qflist(opts)
    opts = opts or {}

    local severity = (function()
        if opts.highest then
            return require("mjm.utils").get_top_severity({ buf = nil })
        elseif opts.err_only then
            return vim.diagnostic.severity.ERROR
        else
            return vim.diagnostic.severity.HINT
        end
    end)() ---@type integer|{min:integer}

    ---@diagnostic disable: undefined-doc-name
    local raw_diags = vim.diagnostic.get(nil, { severity = severity }) ---@type vim.diagnostic[]
    if #raw_diags == 0 then
        local name = opts.err_only and "errors" or "diagnostics" ---@type string
        vim.api.nvim_cmd({ cmd = "ccl" }, {})

        vim.notify("No " .. name)
        return
    end

    local diags_for_qflist = vim.tbl_map(convert_diag, raw_diags) ---@type table
    assert(#raw_diags == #diags_for_qflist, "Coverted diags were filtered")

    vim.fn.setqflist(diags_for_qflist, "r")
    open_qflist()
end

---@param opts? {highest:boolean, err_only:boolean}
---@return nil
local function buf_diags_to_loclist(opts)
    opts = opts or {}

    local win = vim.api.nvim_get_current_win() ---@type integer
    local buf = vim.api.nvim_win_get_buf(win) ---@type integer
    if not require("mjm.utils").check_modifiable(buf) then
        return
    end

    local severity = (function()
        if opts.highest then
            return require("mjm.utils").get_top_severity({ buf = buf })
        elseif opts.err_only then
            return vim.diagnostic.severity.ERROR
        else
            return vim.diagnostic.severity.HINT
        end
    end)() ---@type integer|{min:integer}

    ---@diagnostic disable: undefined-doc-name
    local raw_diags = vim.diagnostic.get(buf, { severity = severity }) ---@type vim.diagnostic[]
    if #raw_diags == 0 then
        local name = opts.err_only and "errors" or "diagnostics" ---@type string
        vim.api.nvim_cmd({ cmd = "lcl" }, {})

        vim.notify("No " .. name)
        return
    end

    local diags_for_loclist = vim.tbl_map(convert_diag, raw_diags) ---@type table
    assert(#raw_diags == #diags_for_loclist, "Coverted diags were filtered")

    vim.fn.setloclist(win, diags_for_loclist, "r")
    vim.api.nvim_cmd({ cmd = "ccl" }, {})
    vim.api.nvim_cmd({ cmd = "lop" }, {})
end

Map("n", "yui", function()
    all_diags_to_qflist()
end)

Map("n", "yue", function()
    all_diags_to_qflist({ err_only = true })
end)

Map("n", "yuh", function()
    all_diags_to_qflist({ highest = true })
end)

Map("n", "yoi", function()
    buf_diags_to_loclist()
end)

Map("n", "yoe", function()
    buf_diags_to_loclist({ err_only = true })
end)

Map("n", "yoh", function()
    buf_diags_to_loclist({ highest = true })
end)

---@param opts? {loclist:boolean, remove:boolean}
---@return nil
local function filter_wrapper(opts)
    opts = opts or {}

    if opts.loclist and vim.fn.getloclist(vim.api.nvim_get_current_win(), { id = 0 }).id == 0 then
        vim.notify("Current window has no location list")
        return
    end

    local list = opts.loclist and "Location" or "Quickfix" ---@type string

    if opts.loclist and #vim.fn.getloclist(vim.api.nvim_get_current_win()) <= 0 then
        vim.notify(list .. " list is empty")
        return
    elseif (not opts.loclist) and #vim.fn.getqflist() <= 0 then
        vim.notify(list .. " list is empty")
        return
    end

    local action = opts.remove and "remove: " or "keep: " --- @type string
    local prompt = list .. " pattern to " .. action --- @type string
    local ok, pattern = require("mjm.utils").get_input(prompt) --- @type boolean, string
    if not ok then
        local msg = pattern or "Unknown error getting input" --- @type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    elseif pattern == "" then
        return
    end

    local prefix = opts.loclist and "L" or "C" ---@type string
    vim.api.nvim_cmd({ cmd = prefix .. "filter", bang = opts.remove, args = { pattern } }, {})
end

Map("n", "duk", function()
    filter_wrapper()
end)

Map("n", "dur", function()
    filter_wrapper({ remove = true })
end)

Map("n", "dok", function()
    filter_wrapper({ loclist = true })
end)

Map("n", "dor", function()
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

    local ok, pattern = (function()
        if opts.pattern then
            return true, opts.pattern
        else
            return require("mjm.utils").get_input("Enter Grep pattern: ")
        end
    end)() --- @type boolean, string

    if not ok then
        local msg = pattern or "Unknown error getting input" --- @type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    elseif pattern == "" and opts.pattern then
        vim.api.nvim_echo({ { "Empty grep pattern", "WarningMsg" } }, true, {})
        return
    elseif pattern == "" then
        return
    end

    local args = { pattern } ---@type table
    if opts.insensitive then table.insert(args, "-i") end
    if opts.loclist then table.insert(args, "%") end

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
        vim.api.nvim_cmd({ cmd = "ccl" }, {})
        vim.api.nvim_cmd({ cmd = "lop" }, {})
    else
        last_grep = pattern
        open_qflist()
    end
end

Map("n", "yugs", function()
    grep_wrapper({})
end)

Map("n", "yogs", function()
    grep_wrapper({ loclist = true })
end)

Map("n", "yugi", function()
    grep_wrapper({ insensitive = true })
end)

Map("n", "yogi", function()
    grep_wrapper({ insensitive = true, loclist = true })
end)

Map("n", "yugr", function()
    grep_wrapper({ pattern = last_grep })
end)

Map("n", "yogr", function()
    grep_wrapper({ pattern = last_lgrep, loclist = true })
end)

Map("n", "yugv", function()
    print(last_grep)
end)

Map("n", "yogv", function()
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
    { "[q", "cp", "cla" },
    { "]q", "cn", "cr" },
    { "[l", "lp", "lla" },
    { "]l", "ln", "lr" },
}

for _, m in pairs(scroll_maps) do
    Map("n", m[1], function()
        qf_scroll_wrapper(m[2], m[3])
    end)
end

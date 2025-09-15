--- TODO: Break system into its own file and keep grep here
--- TODO: document that the buf greps use external grep
--- TODO: We have enough examples now of different greps to abstract the parts out
--- TODO: test with default grep. findstr kinda out of luck
--- TODO: multilines work as an or grep but would be better as a true multiline

local M = {}

-------------
--- Types ---
-------------

--- @class QfRancherSystemIn
--- @field cmd_parts? string[]
--- @field err_chunk? [string, string]
--- @field err_msg_hist? boolean
--- @field title? string

--- @class QfRancherSystemOpts
--- @field async? boolean
--- @field loclist? boolean
--- @field merge? boolean
--- @field overwrite? boolean
--- @field timeout? integer
--- @field type? string

----------------------
--- System Helpers ---
----------------------

local function get_qf_key(entry)
    local fname = entry.filename or ""
    local lnum = tostring(entry.lnum or 0)
    local col = tostring(entry.col or 0)
    return fname .. ":" .. lnum .. ":" .. col
end

local function merge_qf_lists(a, b)
    local merged = {}
    local seen = {}

    local x = #a > #b and a or b
    local y = #a > #b and b or a

    for _, entry in ipairs(x) do
        local key = get_qf_key(entry)
        seen[key] = true
        table.insert(merged, entry)
    end

    for _, entry in ipairs(y) do
        local key = get_qf_key(entry)
        if not seen[key] then
            seen[key] = true
            table.insert(merged, entry)
        end
    end

    return merged
end

--- @param win? integer
local function get_getlist(win)
    if not win then return vim.fn.getqflist end

    return function(what)
        if not what then return vim.fn.getloclist(win) end

        return vim.fn.getloclist(win, what)
    end
end

local function get_setlist(win)
    if not win then return vim.fn.setqflist end

    return function(dict, a, b)
        local action, what
        if type(a) == "table" then
            action = ""
            what = a
        elseif type(a) == "string" and a ~= "" or a == "" then
            action = a
            what = b or {}
        elseif a == nil then
            action = ""
            what = b or {}
        else
            error("Invalid action: must be a non-nil string")
        end

        vim.fn.setloclist(win, dict, action, what)
    end
end

--- @param get_cmd_parts fun():boolean, QfRancherSystemIn
--- @return boolean, QfRancherSystemIn|nil
local function resolve_cmd_parts(get_cmd_parts)
    if type(get_cmd_parts) ~= "function" then
        local chunk = { "No function provided to get cmd parts", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return false, nil
    end

    local ok, system_in = get_cmd_parts()
    if not ok then
        local chunk = system_in.err_chunk or { "Unknown error getting command parts", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, system_in.err_msg_hist or true, { err = true })
        return false, nil
    end

    if type(system_in.cmd_parts) ~= "table" then
        local chunk = { "No cmd parts table provided from input function", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return false, nil
    end

    if #system_in.cmd_parts < 1 then
        local chunk = { "cmd_parts empty in qf_system_wrapper", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return false, nil
    end

    return true, system_in
end

--- @param getlist function
--- @param opts table
--- @return integer|string
local function get_list_nr(getlist, opts)
    opts = opts or {}

    if vim.v.count < 1 then
        if opts.overwrite or opts.merge then
            return getlist({ nr = 0 }).nr
        else
            return "$"
        end
    else
        return math.min(vim.v.count, getlist({ nr = "$" }).nr)
    end
end

----------------------
--- System Wrapper ---
----------------------

--- @param get_cmd_parts fun():boolean, QfRancherSystemIn
--- @param opts QfRancherSystemOpts
--- @return nil
function M.qf_sys_wrap(get_cmd_parts, opts)
    local ok, system_in = resolve_cmd_parts(get_cmd_parts)
    if (not ok) or not system_in then return end

    opts = opts or {}
    local cur_win = opts.loclist and vim.api.nvim_get_current_win() or nil
    local cur_wintype = cur_win and vim.fn.win_gettype(cur_win) or nil
    if opts.loclist and cur_wintype == "quickfix" then
        local chunk = { "Cannot create a loclist in a quickfix window", "" }
        vim.api.nvim_echo({ chunk }, false, {})
        return
    end

    local getlist = get_getlist(cur_win)
    local list_nr = get_list_nr(getlist, opts) --- @type integer|string

    local function handle_result(obj)
        if obj.code ~= 0 then
            local cmd = obj.cmd or "Unknown cmd"
            local code = obj.code or "N/A"
            local err = obj.stderr or "No stderr output"
            local msg = cmd .. " failed. Code: " .. code .. ", Error: " .. err

            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        end

        local lines = vim.split(obj.stdout or "", "\n", { trimempty = true })

        local qf_dict = vim.fn.getqflist({ lines = lines })
        if opts.type then
            for _, item in pairs(qf_dict.items) do
                item.type = opts.type
            end
        end

        if opts.merge then
            local cur_list = getlist({ nr = list_nr, items = true })
            local new_items = merge_qf_lists(cur_list.items, qf_dict.items)
            qf_dict.items = new_items
        end

        table.sort(qf_dict.items, require("mjm.error-list-sort").sort_fname_asc)
        local title = type(system_in.title) == "string" and system_in.title or ""
        local setlist = get_setlist(cur_win)
        local action = (opts.merge or opts.overwrite) and "r" or " "
        setlist({}, action, { items = qf_dict.items, nr = list_nr, title = title })

        -- TODO: do a getopen thing here too
        -- TODO: if either of these return false, do a resize instead
        local el = require("mjm.error-list")
        if opts.loclist then
            el.open_loclist()
        else
            el.open_qflist()
        end

        if opts.overwrite or opts.merge then
            if opts.loclist then
                vim.cmd(list_nr .. "lhistory")
            else
                vim.cmd(list_nr .. "chistory")
            end
        end
    end

    if opts.async then
        vim.system(system_in.cmd_parts, { text = true }, function(obj)
            vim.schedule(function() handle_result(obj) end)
        end)
    else
        local obj = vim.system(system_in.cmd_parts, { text = true }):wait(opts.timeout or 2000)
        handle_result(obj)
    end
end

--------------------
--- Grep Helpers ---
--------------------

--- @return boolean, string|[string, string]
--- Assumes that it is being called in visual mode with a valid mode parameter
local function get_visual_grep_pattern(mode)
    local start_pos = vim.fn.getpos(".")
    local end_pos = vim.fn.getpos("v")
    local sel = vim.fn.getregion(start_pos, end_pos, { type = mode })

    local lines = type(sel) == "string" and vim.split(sel, "\n", { plain = true }) or sel

    local function format_line(line)
        local trimmed = line:gsub("^%s*(.-)%s*$", "%1")
        if trimmed == "" then return nil end

        return trimmed:gsub("([%.%^%$%*%[%\\%+%?%(%)%{%)|%}])", "\\%1")
    end

    local escaped_lines = {}
    for _, line in ipairs(lines) do
        local escaped = format_line(line)
        if escaped then table.insert(escaped_lines, escaped) end
    end

    if #escaped_lines == 0 then return false, { "Empty selection", "" } end

    vim.api.nvim_cmd({ cmd = "normal", args = { "\27" }, bang = true }, {})
    return true, table.concat(escaped_lines, "|")
end

--- @return boolean, string|QfRancherSystemIn
local function get_grep_pattern(prompt)
    local mode = vim.fn.mode()
    local is_visual = mode == "v" or mode == "V" or mode == "\22"

    if is_visual then
        local ok, pattern = get_visual_grep_pattern(mode)
        if not ok then return false, { err_chunk = pattern, err_msg_hist = false } end
        return true, pattern
    end

    local ok, pattern = pcall(vim.fn.input, { prompt = prompt, cancelreturn = "" })
    if (ok and pattern == "") or ((not ok) and pattern == "Keyboard interrupt") then
        return false, { err_chunk = { "", "" }, err_msg_hist = false }
    end

    if not ok then
        --- @type [string, string]
        local chunk = { pattern or "Unknown error getting input", "ErrorMsg" }
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    return true, pattern
end

---------------------
--- Grep Commands ---
---------------------

vim.keymap.set({ "n", "x" }, "<leader>qg", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>qG", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>lg", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>lG", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>", "<nop>")

--- @return boolean, QfRancherSystemIn
local function grep_cwd()
    local cwd = vim.fn.getcwd() --- @type string
    local prompt = "Grep (" .. cwd .. "): " --- @type string

    local ok, pattern = get_grep_pattern(prompt) --- @type boolean, string|QfRancherSystemIn
    if not ok then
        --- @type [string, string]
        local chunk = type(pattern) ~= "string" and pattern
            or { err_chunk = { "Unknown error getting pattern", "ErrorMsg" }, err_msg_hist = true }
        return false, chunk
    end

    local cmd_parts = (function()
        if vim.fn.executable("rg") == 1 then
            return { "rg", "--vimgrep", "-uu", "--ignore-case", pattern, cwd }
        elseif vim.fn.has("win32") == 1 then
            return { "findstr", "/s", "/n", "/i", pattern, cwd }
        else
            return { "grep", "-r", "-H", "-E", "-I", "-n", "-i", pattern, cwd }
        end
    end)() --- @type string[]

    local title = 'Grep "' .. pattern .. '" in ' .. cwd --- @type string
    return true, { cmd_parts = cmd_parts, title = title }
end

local grep_b = { async = true, timeout = 2000 }
local grep_o = { async = true, overwrite = true, timeout = 2000 }
local grep_m = { async = true, merge = true, timeout = 2000 }

local lgrep_b = { async = true, loclist = true, timeout = 2000 }
local lgrep_o = { async = true, loclist = true, overwrite = true, timeout = 2000 }
local lgrep_m = { async = true, loclist = true, merge = true, timeout = 2000 }

vim.keymap.set({ "n", "x" }, "<leader>qgd", function() M.qf_sys_wrap(grep_cwd, grep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>qGd", function() M.qf_sys_wrap(grep_cwd, grep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>d", function() M.qf_sys_wrap(grep_cwd, grep_m) end)

vim.keymap.set({ "n", "x" }, "<leader>lgd", function() M.qf_sys_wrap(grep_cwd, lgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>lGd", function() M.qf_sys_wrap(grep_cwd, lgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>d", function() M.qf_sys_wrap(grep_cwd, lgrep_m) end)

--- @return boolean, QfRancherSystemIn
local function grep_CWD()
    local cwd = vim.fn.getcwd() --- @type string
    local prompt = "Grep (" .. cwd .. "): " --- @type string

    local ok, pattern = get_grep_pattern(prompt) --- @type boolean, string|QfRancherSystemIn
    if not ok then
        --- @type [string, string]
        local chunk = type(pattern) ~= "string" and pattern
            or { err_chunk = { "Unknown error getting pattern", "ErrorMsg" }, err_msg_hist = true }
        return false, chunk
    end

    local cmd_parts = (function()
        if vim.fn.executable("rg") == 1 then
            return { "rg", "--vimgrep", "-uu", pattern, cwd }
        elseif vim.fn.has("win32") == 1 then
            return { "findstr", "/s", "/n", pattern, cwd }
        else
            return { "grep", "-r", "-H", "-E", "-I", "-n", pattern, cwd }
        end
    end)() --- @type string[]

    local title = 'Grep "' .. pattern .. '" in ' .. cwd --- @type string
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>qgD", function() M.qf_sys_wrap(grep_CWD, grep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>qGD", function() M.qf_sys_wrap(grep_CWD, grep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>D", function() M.qf_sys_wrap(grep_CWD, grep_m) end)

vim.keymap.set({ "n", "x" }, "<leader>lgD", function() M.qf_sys_wrap(grep_CWD, lgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>lGD", function() M.qf_sys_wrap(grep_CWD, lgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>D", function() M.qf_sys_wrap(grep_CWD, lgrep_m) end)

local hgrep_b = { async = true, type = "\1", timeout = 2000 }
local hgrep_o = { async = true, type = "\1", overwrite = true, timeout = 2000 }
local hgrep_m = { async = true, type = "\1", merge = true, timeout = 2000 }

local hlgrep_b = { async = true, type = "\1", loclist = true, timeout = 2000 }
local hlgrep_o = { async = true, type = "\1", loclist = true, overwrite = true, timeout = 2000 }
local hlgrep_m = { async = true, type = "\1", loclist = true, merge = true, timeout = 2000 }

local function grep_help()
    local prompt = "Help Grep: " --- @type string

    local ok, pattern = get_grep_pattern(prompt) --- @type boolean, string|QfRancherSystemIn
    if not ok then
        --- @type [string, string]
        local chunk = type(pattern) ~= "string" and pattern
            or { err_chunk = { "Unknown error getting pattern", "ErrorMsg" }, err_msg_hist = true }
        return false, chunk
    end

    local doc_files = vim.api.nvim_get_runtime_file("doc/*.txt", true) --- @type string[]
    if #doc_files == 0 then
        local chunk = { "No doc files found", "ErrorMsg" } --- @type [string,string]
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    local cmd_parts = (function()
        if vim.fn.executable("rg") == 1 then
            return vim.list_extend(
                { "rg", "--vimgrep", "-uu", "--ignore-case", pattern },
                doc_files
            )
        elseif vim.fn.has("win32") == 1 then
            return vim.list_extend({ "findstr", "/n", "/I", pattern }, doc_files)
        else
            return vim.list_extend({ "grep", "-H", "-E", "-I", "-n", "-i", pattern }, doc_files)
        end
    end)()

    local title = 'Grep "' .. pattern .. '" in docs'
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>qgh", function() M.qf_sys_wrap(grep_help, hgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>qGh", function() M.qf_sys_wrap(grep_help, hgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>h", function() M.qf_sys_wrap(grep_help, hgrep_m) end)

vim.keymap.set({ "n", "x" }, "<leader>lgh", function() M.qf_sys_wrap(grep_help, hlgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>lGh", function() M.qf_sys_wrap(grep_help, hlgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>h", function() M.qf_sys_wrap(grep_help, hlgrep_m) end)

local function grep_HELP()
    local prompt = "Help Grep: " --- @type string

    local ok, pattern = get_grep_pattern(prompt) --- @type boolean, string|QfRancherSystemIn
    if not ok then
        --- @type [string, string]
        local chunk = type(pattern) ~= "string" and pattern
            or { err_chunk = { "Unknown error getting pattern", "ErrorMsg" }, err_msg_hist = true }
        return false, chunk
    end

    local doc_files = vim.api.nvim_get_runtime_file("doc/*.txt", true) --- @type string[]
    if #doc_files == 0 then
        local chunk = { "No doc files found", "ErrorMsg" } --- @type [string,string]
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    local cmd_parts = (function()
        if vim.fn.executable("rg") == 1 then
            return vim.list_extend({ "rg", "--vimgrep", "-uu", pattern }, doc_files)
        elseif vim.fn.has("win32") == 1 then
            return vim.list_extend({ "findstr", "/n", pattern }, doc_files)
        else
            return vim.list_extend({ "grep", "-H", "-E", "-I", "-n", pattern }, doc_files)
        end
    end)()

    local title = 'Grep "' .. pattern .. '" in docs'
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>qgH", function() M.qf_sys_wrap(grep_HELP, hgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>qGH", function() M.qf_sys_wrap(grep_HELP, hgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>H", function() M.qf_sys_wrap(grep_HELP, hgrep_m) end)

vim.keymap.set({ "n", "x" }, "<leader>lgH", function() M.qf_sys_wrap(grep_HELP, hlgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>lGH", function() M.qf_sys_wrap(grep_HELP, hlgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>H", function() M.qf_sys_wrap(grep_HELP, hlgrep_m) end)

local function grep_bufs()
    local prompt = "Grep open bufs: " --- @type string

    local ok, pattern = get_grep_pattern(prompt) --- @type boolean, string|QfRancherSystemIn
    if not ok then
        --- @type [string, string]
        local chunk = type(pattern) ~= "string" and pattern
            or { err_chunk = { "Unknown error getting pattern", "ErrorMsg" }, err_msg_hist = true }
        return false, chunk
    end

    local bufs = vim.api.nvim_list_bufs() --- @type integer[]
    local buf_files = {} --- @type string[]
    for _, buf in ipairs(bufs) do
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
        local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf })
        if buflisted and buftype == "" then
            local fname = vim.api.nvim_buf_get_name(buf)
            if fname ~= "" and vim.fn.filereadable(fname) == 1 then
                table.insert(buf_files, fname)
            end
        end
    end

    if #buf_files == 0 then
        local chunk = { "No valid bufs found", "ErrorMsg" } --- @type [string,string]
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    local cmd_parts = (function()
        if vim.fn.executable("rg") == 1 then
            return vim.list_extend(
                { "rg", "--vimgrep", "-uu", "--ignore-case", pattern },
                buf_files
            )
        elseif vim.fn.has("win32") == 1 then
            return vim.list_extend({ "findstr", "/s", "/n", "/i", pattern }, buf_files)
        else
            return vim.list_extend(
                { "grep", "-r", "-H", "-E", "-I", "-n", "-i", pattern },
                buf_files
            )
        end
    end)()

    local title = 'Grep "' .. pattern .. '" in bufs'
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>qgu", function() M.qf_sys_wrap(grep_bufs, grep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>qGu", function() M.qf_sys_wrap(grep_bufs, grep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>u", function() M.qf_sys_wrap(grep_bufs, grep_m) end)

local function grep_BUFS()
    local prompt = "Grep Bufs (case sensitive): " --- @type string

    local ok, pattern = get_grep_pattern(prompt) --- @type boolean, string|QfRancherSystemIn
    if not ok then
        --- @type [string, string]
        local chunk = type(pattern) ~= "string" and pattern
            or { err_chunk = { "Unknown error getting pattern", "ErrorMsg" }, err_msg_hist = true }
        return false, chunk
    end

    local bufs = vim.api.nvim_list_bufs() --- @type integer[]
    local buf_files = {} --- @type string[]
    for _, buf in ipairs(bufs) do
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
        local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf })
        if buflisted and buftype == "" then
            local fname = vim.api.nvim_buf_get_name(buf)
            if fname ~= "" and vim.fn.filereadable(fname) == 1 then
                table.insert(buf_files, fname)
            end
        end
    end

    if #buf_files == 0 then
        local chunk = { "No valid bufs found", "ErrorMsg" } --- @type [string,string]
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    local cmd_parts = (function()
        if vim.fn.executable("rg") == 1 then
            return vim.list_extend({ "rg", "--vimgrep", "-uu", pattern }, buf_files)
        elseif vim.fn.has("win32") == 1 then
            return vim.list_extend({ "findstr", "/s", "/n", pattern }, buf_files)
        else
            return vim.list_extend({ "grep", "-r", "-H", "-E", "-I", "-n", pattern }, buf_files)
        end
    end)()

    local title = 'Grep "' .. pattern .. '" in bufs'
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>qgU", function() M.qf_sys_wrap(grep_BUFS, grep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>qGU", function() M.qf_sys_wrap(grep_BUFS, grep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>U", function() M.qf_sys_wrap(grep_BUFS, grep_m) end)

local function grep_cbuf()
    local prompt = "Grep Current Buf: " --- @type string

    local ok, pattern = get_grep_pattern(prompt) --- @type boolean, string|QfRancherSystemIn
    if not ok then
        --- @type [string, string]
        local chunk = type(pattern) ~= "string" and pattern
            or { err_chunk = { "Unknown error getting pattern", "ErrorMsg" }, err_msg_hist = true }
        return false, chunk
    end

    local buf = vim.api.nvim_get_current_buf()
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
    local good_buftype = buftype == "" or buftype == "help"
    local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf })
    local fname = vim.api.nvim_buf_get_name(buf)
    local readable = vim.fn.filereadable(fname) == 1
    local good_file = fname ~= "" and readable
    if not (buflisted and good_buftype and good_file) then
        --- @type [string,string]
        local chunk = { "Current buffer is not a valid file", "ErrorMsg" }
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    local buf_files = { fname }

    local cmd_parts = (function()
        if vim.fn.executable("rg") == 1 then
            return vim.list_extend(
                { "rg", "--vimgrep", "-uu", "--ignore-case", pattern },
                buf_files
            )
        elseif vim.fn.has("win32") == 1 then
            return vim.list_extend({ "findstr", "/n", "/i", pattern }, buf_files)
        else
            return vim.list_extend({ "grep", "-H", "-E", "-I", "-n", "-i", pattern }, buf_files)
        end
    end)()

    local title = 'Grep "' .. pattern .. '" in current buf'
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>lgu", function() M.qf_sys_wrap(grep_cbuf, lgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>lGu", function() M.qf_sys_wrap(grep_cbuf, lgrep_m) end)
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>u", function() M.qf_sys_wrap(grep_cbuf, lgrep_m) end)

local function grep_CBUF()
    local prompt = "Grep Current Buf (Case Sensitive): " --- @type string

    local ok, pattern = get_grep_pattern(prompt) --- @type boolean, string|QfRancherSystemIn
    if not ok then
        --- @type [string, string]
        local chunk = type(pattern) ~= "string" and pattern
            or { err_chunk = { "Unknown error getting pattern", "ErrorMsg" }, err_msg_hist = true }
        return false, chunk
    end

    local buf = vim.api.nvim_get_current_buf()
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
    local good_buftype = buftype == "" or buftype == "help"
    local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf })
    local fname = vim.api.nvim_buf_get_name(buf)
    local readable = vim.fn.filereadable(fname) == 1
    local good_file = fname ~= "" and readable
    if not (buflisted and good_buftype and good_file) then
        --- @type [string,string]
        local chunk = { "Current buffer is not a valid file", "ErrorMsg" }
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    local buf_files = { fname }

    local cmd_parts = (function()
        if vim.fn.executable("rg") == 1 then
            return vim.list_extend({ "rg", "--vimgrep", "-uu", pattern }, buf_files)
        elseif vim.fn.has("win32") == 1 then
            return vim.list_extend({ "findstr", "/n", pattern }, buf_files)
        else
            return vim.list_extend({ "grep", "-H", "-E", "-I", "-n", pattern }, buf_files)
        end
    end)()

    local title = 'Grep "' .. pattern .. '" in current buf'
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>lgU", function() M.qf_sys_wrap(grep_CBUF, lgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>lGU", function() M.qf_sys_wrap(grep_CBUF, lgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>U", function() M.qf_sys_wrap(grep_CBUF, lgrep_m) end)

return M

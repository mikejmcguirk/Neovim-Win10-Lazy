--- TODO: Break system into its own file and keep grep here
--- TODO: document that the buf greps use external grep
--- TODO: We have enough examples now of different greps to abstract the parts out
--- TODO: test with default grep. findstr kinda out of luck
--- TODO: multilines work as an or grep but would be better as a true multiline
--- TODO: make sure all ripgrep queries have -U flag and greps have -E

local M = {}

-- From vim-grepper
-- " Escaping test line:
-- " ..ad\\f40+$':-# @=,!;%^&&*()_{}/ /4304\'""?`9$343%$ ^adfadf[ad)[(
-- TODO: fails

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

--- MAYBE: If grep opts build up, turn then imto a class
--- @alias QfRancherGrepCmdFun fun(
--- table: string[], table: string[], table)
--- :boolean, string[]|[string, string]

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
    --- @type boolean, QfRancherSystemIn|nil
    local ok, system_in = resolve_cmd_parts(get_cmd_parts)
    if not ok then return end --- Errors printed in resolve_cmd_parts

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
            qf_dict.items = merge_qf_lists(cur_list.items, qf_dict.items)
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

        -- TODO: need a wrapper for these that resizes
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

--- @return boolean, string[]|[string, string]
--- Assumes that it is being called in visual mode with a valid mode parameter
local function get_visual_pattern(mode)
    local start_pos = vim.fn.getpos(".")
    local end_pos = vim.fn.getpos("v")
    local region = vim.fn.getregion(start_pos, end_pos, { type = mode })

    local lines = {}
    local is_single_line = #region == 1

    if is_single_line then
        local trimmed = region[1]:gsub("^%s*(.-)%s*$", "%1")
        if trimmed == "" then return false, { "get_visual_pattern: Empty selection", "" } end
        table.insert(lines, trimmed)
    else
        lines = region

        local has_valid_line = false
        for _, line in ipairs(lines) do
            if line ~= "" then
                has_valid_line = true
                break
            end
        end

        if not has_valid_line then return false, { "get_visual_pattern: Empty selection", "" } end
    end

    vim.api.nvim_cmd({ cmd = "normal", args = { "\27" }, bang = true }, {})
    return true, lines
end

--- @return boolean, string[]|QfRancherSystemIn
local function get_grep_pattern(prompt)
    local mode = vim.fn.mode()
    local is_visual = mode == "v" or mode == "V" or mode == "\22"

    if is_visual then
        local ok, pattern = get_visual_pattern(mode)
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

    return true, vim.split(pattern, "\\n")
end

local function grep_escape(text) return text:gsub("([%.%^%$%*%+%?%(%)%[%]%{%}%|%\\])", "\\%1") end

--- @param raw_pattern string[]
--- @param location string[]
--- @param opts? {ignore_case:boolean}
--- @return boolean, string[]|[string,string]
local function get_rg_cmd_parts(raw_pattern, location, opts)
    local cmd = { "rg", "--vimgrep", "-uu", "-U", "--ignore-case" }

    opts = opts or {}

    if opts.ignore_case then vim.list_extend(cmd, { "--ignore-case" }) end

    if not raw_pattern then
        return false, { "No pattern provided to build rg cmd parts", "ErrorMsg" }
    end

    local escape_lines = vim.tbl_map(grep_escape, raw_pattern)
    local pat_str = #escape_lines > 1 and { table.concat(escape_lines, "\\n") } or escape_lines
    vim.list_extend(cmd, pat_str)

    if not location then
        return false, { "No location provided to build rg cmd parts", "ErrorMsg" }
    end

    vim.list_extend(cmd, location)

    return true, cmd
end

--- @return boolean, QfRancherGrepCmdFun|[string,string]
local function get_grep_cmd()
    if vim.fn.executable("rg") ~= 1 then
        return false, { "get_grep_cmd: Only rg is currently supported", "" }
    end

    return true, get_rg_cmd_parts
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

local grep_b = { async = true, timeout = 2000 }
local grep_o = { async = true, overwrite = true, timeout = 2000 }
local grep_m = { async = true, merge = true, timeout = 2000 }

local lgrep_b = { async = true, loclist = true, timeout = 2000 }
local lgrep_o = { async = true, loclist = true, overwrite = true, timeout = 2000 }
local lgrep_m = { async = true, loclist = true, merge = true, timeout = 2000 }

--- @return boolean, QfRancherSystemIn
local function grep_cwd()
    local ok, grep_cmd = get_grep_cmd() --- @type boolean, QfRancherGrepCmdFun|[string,string]
    if (not ok) or type(grep_cmd) ~= "function" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep cmd", "ErrorMsg" }
        --- @type [string, string]
        local err_chunk = type(grep_cmd) ~= "function" and grep_cmd or backup_chunk
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local cwd = vim.fn.getcwd() --- @type string
    local prompt = "Grep (" .. cwd .. "): " --- @type string

    local ok_l, raw_pat = get_grep_pattern(prompt) --- @type boolean, string[]|QfRancherSystemIn
    if not ok_l or type(raw_pat) ~= "table" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep pattern", "ErrorMsg" }
        local err_chunk = raw_pat.err_chunk or backup_chunk --- @type [string,string]
        local err_msg_hist = raw_pat.err_msg_hist == false and false or true --- @type boolean
        return false, { err_chunk = err_chunk, err_msg_hist = err_msg_hist or true }
    end

    -- TODO: Test that feeding cwd this way works
    --- @type boolean, string[]|[string,string]
    local ok_c, cmd_parts = grep_cmd(raw_pat, { cwd }, { ignore_case = true })
    if not ok_c then
        local err_chunk = cmd_parts or { "grep_cbuf: Unknown error getting cmd parts", "ErrorMsg" }
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local title = 'Grep "' .. raw_pat[1] .. '" in ' .. cwd --- @type string
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>qgd", function() M.qf_sys_wrap(grep_cwd, grep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>qGd", function() M.qf_sys_wrap(grep_cwd, grep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>d", function() M.qf_sys_wrap(grep_cwd, grep_m) end)

vim.keymap.set({ "n", "x" }, "<leader>lgd", function() M.qf_sys_wrap(grep_cwd, lgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>lGd", function() M.qf_sys_wrap(grep_cwd, lgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>d", function() M.qf_sys_wrap(grep_cwd, lgrep_m) end)

--- @return boolean, QfRancherSystemIn
local function grep_CWD()
    local ok, grep_cmd = get_grep_cmd() --- @type boolean, QfRancherGrepCmdFun|[string,string]
    if (not ok) or type(grep_cmd) ~= "function" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep cmd", "ErrorMsg" }
        --- @type [string, string]
        local err_chunk = type(grep_cmd) ~= "function" and grep_cmd or backup_chunk
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local cwd = vim.fn.getcwd() --- @type string
    local prompt = "Grep (" .. cwd .. "): " --- @type string

    local ok_l, raw_pat = get_grep_pattern(prompt) --- @type boolean, string[]|QfRancherSystemIn
    if not ok_l or type(raw_pat) ~= "table" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep pattern", "ErrorMsg" }
        local err_chunk = raw_pat.err_chunk or backup_chunk --- @type [string,string]
        local err_msg_hist = raw_pat.err_msg_hist == false and false or true --- @type boolean
        return false, { err_chunk = err_chunk, err_msg_hist = err_msg_hist or true }
    end

    -- TODO: Test that feeding cwd this way works
    --- @type boolean, string[]|[string,string]
    local ok_c, cmd_parts = grep_cmd(raw_pat, { cwd })
    if not ok_c then
        local err_chunk = cmd_parts or { "grep_cbuf: Unknown error getting cmd parts", "ErrorMsg" }
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local title = 'Grep "' .. raw_pat[1] .. '" in ' .. cwd --- @type string
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

--- @return boolean, QfRancherSystemIn
local function grep_help()
    local ok, grep_cmd = get_grep_cmd() --- @type boolean, QfRancherGrepCmdFun|[string,string]
    if (not ok) or type(grep_cmd) ~= "function" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep cmd", "ErrorMsg" }
        --- @type [string, string]
        local err_chunk = type(grep_cmd) ~= "function" and grep_cmd or backup_chunk
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local doc_files = vim.api.nvim_get_runtime_file("doc/*.txt", true) --- @type string[]
    if #doc_files == 0 then
        local chunk = { "No doc files found", "ErrorMsg" } --- @type [string,string]
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    local prompt = "Help Grep: " --- @type string

    local ok_l, raw_pat = get_grep_pattern(prompt) --- @type boolean, string[]|QfRancherSystemIn
    if not ok_l or type(raw_pat) ~= "table" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep pattern", "ErrorMsg" }
        local err_chunk = raw_pat.err_chunk or backup_chunk --- @type [string,string]
        local err_msg_hist = raw_pat.err_msg_hist == false and false or true --- @type boolean
        return false, { err_chunk = err_chunk, err_msg_hist = err_msg_hist or true }
    end

    --- @type boolean, string[]|[string,string]
    local ok_c, cmd_parts = grep_cmd(raw_pat, doc_files, { ignore_case = true })
    if not ok_c then
        local err_chunk = cmd_parts or { "grep_cbuf: Unknown error getting cmd parts", "ErrorMsg" }
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local title = 'Grep "' .. raw_pat[1] .. '" in docs' --- @type string
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>qgh", function() M.qf_sys_wrap(grep_help, hgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>qGh", function() M.qf_sys_wrap(grep_help, hgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>h", function() M.qf_sys_wrap(grep_help, hgrep_m) end)

vim.keymap.set({ "n", "x" }, "<leader>lgh", function() M.qf_sys_wrap(grep_help, hlgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>lGh", function() M.qf_sys_wrap(grep_help, hlgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>h", function() M.qf_sys_wrap(grep_help, hlgrep_m) end)

--- @return boolean, QfRancherSystemIn
local function grep_HELP()
    local ok, grep_cmd = get_grep_cmd() --- @type boolean, QfRancherGrepCmdFun|[string,string]
    if (not ok) or type(grep_cmd) ~= "function" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep cmd", "ErrorMsg" }
        --- @type [string, string]
        local err_chunk = type(grep_cmd) ~= "function" and grep_cmd or backup_chunk
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local doc_files = vim.api.nvim_get_runtime_file("doc/*.txt", true) --- @type string[]
    if #doc_files == 0 then
        local chunk = { "No doc files found", "ErrorMsg" } --- @type [string,string]
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    local prompt = "Help Grep: " --- @type string

    local ok_l, raw_pat = get_grep_pattern(prompt) --- @type boolean, string[]|QfRancherSystemIn
    if not ok_l or type(raw_pat) ~= "table" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep pattern", "ErrorMsg" }
        local err_chunk = raw_pat.err_chunk or backup_chunk --- @type [string,string]
        local err_msg_hist = raw_pat.err_msg_hist == false and false or true --- @type boolean
        return false, { err_chunk = err_chunk, err_msg_hist = err_msg_hist or true }
    end

    --- @type boolean, string[]|[string,string]
    local ok_c, cmd_parts = grep_cmd(raw_pat, doc_files)
    if not ok_c then
        local err_chunk = cmd_parts or { "grep_cbuf: Unknown error getting cmd parts", "ErrorMsg" }
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local title = 'Grep "' .. raw_pat[1] .. '" in docs' --- @type string
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>qgH", function() M.qf_sys_wrap(grep_HELP, hgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>qGH", function() M.qf_sys_wrap(grep_HELP, hgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>H", function() M.qf_sys_wrap(grep_HELP, hgrep_m) end)

vim.keymap.set({ "n", "x" }, "<leader>lgH", function() M.qf_sys_wrap(grep_HELP, hlgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>lGH", function() M.qf_sys_wrap(grep_HELP, hlgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>H", function() M.qf_sys_wrap(grep_HELP, hlgrep_m) end)

--- @return boolean, QfRancherSystemIn
local function grep_bufs()
    local ok, grep_cmd = get_grep_cmd() --- @type boolean, QfRancherGrepCmdFun|[string,string]
    if (not ok) or type(grep_cmd) ~= "function" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep cmd", "ErrorMsg" }
        --- @type [string, string]
        local err_chunk = type(grep_cmd) ~= "function" and grep_cmd or backup_chunk
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local bufs = vim.api.nvim_list_bufs() --- @type integer[]
    local buf_files = {} --- @type string[]
    for _, buf in ipairs(bufs) do
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
        --- @type boolean
        local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf })
        local fname = vim.api.nvim_buf_get_name(buf) --- @type string
        local readable = vim.fn.filereadable(fname) == 1 --- @type boolean
        if buflisted and buftype == "" and readable then table.insert(buf_files, fname) end
    end

    if #buf_files == 0 then
        local chunk = { "No valid bufs found", "ErrorMsg" } --- @type [string,string]
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    local prompt = "Grep Bufs: " --- @type string

    local ok_l, raw_pat = get_grep_pattern(prompt) --- @type boolean, string[]|QfRancherSystemIn
    if not ok_l or type(raw_pat) ~= "table" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep pattern", "ErrorMsg" }
        local err_chunk = raw_pat.err_chunk or backup_chunk --- @type [string,string]
        local err_msg_hist = raw_pat.err_msg_hist == false and false or true --- @type boolean
        return false, { err_chunk = err_chunk, err_msg_hist = err_msg_hist or true }
    end

    --- @type boolean, string[]|[string,string]
    local ok_c, cmd_parts = grep_cmd(raw_pat, buf_files, { ignore_case = true })
    if not ok_c then
        local err_chunk = cmd_parts or { "grep_cbuf: Unknown error getting cmd parts", "ErrorMsg" }
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local title = 'Grep "' .. raw_pat[1] .. '" in current buf' --- @type string
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>qgu", function() M.qf_sys_wrap(grep_bufs, grep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>qGu", function() M.qf_sys_wrap(grep_bufs, grep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>u", function() M.qf_sys_wrap(grep_bufs, grep_m) end)

--- @return boolean, QfRancherSystemIn
local function grep_BUFS()
    local ok, grep_cmd = get_grep_cmd() --- @type boolean, QfRancherGrepCmdFun|[string,string]
    if (not ok) or type(grep_cmd) ~= "function" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep cmd", "ErrorMsg" }
        --- @type [string, string]
        local err_chunk = type(grep_cmd) ~= "function" and grep_cmd or backup_chunk
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local bufs = vim.api.nvim_list_bufs() --- @type integer[]
    local buf_files = {} --- @type string[]
    for _, buf in ipairs(bufs) do
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
        --- @type boolean
        local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf })
        local fname = vim.api.nvim_buf_get_name(buf) --- @type string
        local readable = vim.fn.filereadable(fname) == 1 --- @type boolean
        if buflisted and buftype == "" and readable then table.insert(buf_files, fname) end
    end

    if #buf_files == 0 then
        local chunk = { "No valid bufs found", "ErrorMsg" } --- @type [string,string]
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    local prompt = "Grep Bufs (case sensitive): " --- @type string

    local ok_l, raw_pat = get_grep_pattern(prompt) --- @type boolean, string[]|QfRancherSystemIn
    if not ok_l or type(raw_pat) ~= "table" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep pattern", "ErrorMsg" }
        local err_chunk = raw_pat.err_chunk or backup_chunk --- @type [string,string]
        local err_msg_hist = raw_pat.err_msg_hist == false and false or true --- @type boolean
        return false, { err_chunk = err_chunk, err_msg_hist = err_msg_hist or true }
    end

    --- @type boolean, string[]|[string,string]
    local ok_c, cmd_parts = grep_cmd(raw_pat, buf_files)
    if not ok_c then
        local err_chunk = cmd_parts or { "grep_cbuf: Unknown error getting cmd parts", "ErrorMsg" }
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local title = 'Grep "' .. raw_pat[1] .. '" in current buf' --- @type string
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>qgU", function() M.qf_sys_wrap(grep_BUFS, grep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>qGU", function() M.qf_sys_wrap(grep_BUFS, grep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>U", function() M.qf_sys_wrap(grep_BUFS, grep_m) end)

--- @return boolean, QfRancherSystemIn
local function grep_cbuf()
    local ok, grep_cmd = get_grep_cmd() --- @type boolean, QfRancherGrepCmdFun|[string,string]
    if (not ok) or type(grep_cmd) ~= "function" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep cmd", "ErrorMsg" }
        --- @type [string, string]
        local err_chunk = type(grep_cmd) ~= "function" and grep_cmd or backup_chunk
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local buf = vim.api.nvim_get_current_buf() --- @type integer
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
    local good_buftype = buftype == "" or buftype == "help" --- @type boolean
    local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf }) --- @type boolean
    local fname = vim.api.nvim_buf_get_name(buf) --- @type string
    local readable = vim.fn.filereadable(fname) == 1 --- @type boolean
    local good_file = fname ~= "" and readable --- @type boolean
    if not (buflisted and good_buftype and good_file) then
        --- @type [string,string]
        local chunk = { "Current buffer is not a valid file", "ErrorMsg" }
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    local buf_files = { fname } --- @type string[]

    local prompt = "Grep Current Buf: " --- @type string

    local ok_l, raw_pat = get_grep_pattern(prompt) --- @type boolean, string[]|QfRancherSystemIn
    if not ok_l or type(raw_pat) ~= "table" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep pattern", "ErrorMsg" }
        local err_chunk = raw_pat.err_chunk or backup_chunk --- @type [string,string]
        local err_msg_hist = raw_pat.err_msg_hist == false and false or true --- @type boolean
        return false, { err_chunk = err_chunk, err_msg_hist = err_msg_hist or true }
    end

    --- @type boolean, string[]|[string,string]
    local ok_c, cmd_parts = grep_cmd(raw_pat, buf_files, { ignore_case = true })
    if not ok_c then
        local err_chunk = cmd_parts or { "grep_cbuf: Unknown error getting cmd parts", "ErrorMsg" }
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local title = 'Grep "' .. raw_pat[1] .. '" in current buf' --- @type string
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>lgu", function() M.qf_sys_wrap(grep_cbuf, lgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>lGu", function() M.qf_sys_wrap(grep_cbuf, lgrep_m) end)
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>u", function() M.qf_sys_wrap(grep_cbuf, lgrep_m) end)

--- @return boolean, QfRancherSystemIn
local function grep_CBUF()
    local ok, grep_cmd = get_grep_cmd() --- @type boolean, QfRancherGrepCmdFun|[string,string]
    if (not ok) or type(grep_cmd) ~= "function" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep cmd", "ErrorMsg" }
        --- @type [string, string]
        local err_chunk = type(grep_cmd) ~= "function" and grep_cmd or backup_chunk
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local buf = vim.api.nvim_get_current_buf() --- @type integer
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
    local good_buftype = buftype == "" or buftype == "help" --- @type boolean
    local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf }) --- @type boolean
    local fname = vim.api.nvim_buf_get_name(buf) --- @type string
    local readable = vim.fn.filereadable(fname) == 1 --- @type boolean
    local good_file = fname ~= "" and readable --- @type boolean
    if not (buflisted and good_buftype and good_file) then
        --- @type [string,string]
        local chunk = { "Current buffer is not a valid file", "ErrorMsg" }
        return false, { err_chunk = chunk, err_msg_hist = true }
    end

    local buf_files = { fname } --- @type string[]

    local prompt = "Grep Current Buf (case sensitive): " --- @type string

    local ok_l, raw_pat = get_grep_pattern(prompt) --- @type boolean, string[]|QfRancherSystemIn
    if not ok_l or type(raw_pat) ~= "table" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep pattern", "ErrorMsg" }
        local err_chunk = raw_pat.err_chunk or backup_chunk --- @type [string,string]
        local err_msg_hist = raw_pat.err_msg_hist == false and false or true --- @type boolean
        return false, { err_chunk = err_chunk, err_msg_hist = err_msg_hist or true }
    end

    --- @type boolean, string[]|[string,string]
    local ok_c, cmd_parts = grep_cmd(raw_pat, buf_files)
    if not ok_c then
        local err_chunk = cmd_parts or { "grep_cbuf: Unknown error getting cmd parts", "ErrorMsg" }
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local title = 'Grep "' .. raw_pat[1] .. '" in current buf' --- @type string
    return true, { cmd_parts = cmd_parts, title = title }
end

vim.keymap.set({ "n", "x" }, "<leader>lgU", function() M.qf_sys_wrap(grep_CBUF, lgrep_b) end)
vim.keymap.set({ "n", "x" }, "<leader>lGU", function() M.qf_sys_wrap(grep_CBUF, lgrep_o) end)
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>U", function() M.qf_sys_wrap(grep_CBUF, lgrep_m) end)

return M

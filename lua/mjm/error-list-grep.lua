-- Escaping test line from From vim-grepper
-- ..ad\\f40+$':-# @=,!;%^&&*()_{}/ /4304\'""?`9$343%$ ^adfadf[ad)[(

-------------
--- Types ---
-------------

--- @alias QfRancherGrepCmdFun fun(
--- table: string[], table: string[], table)
--- :boolean, string[]|[string, string]
---
--- @alias QfRancherGrepLocFun fun():boolean, string[]|[string, string]
---
--- @class QfRancherGrepOpts
--- @field literal? boolean
--- @field pattern? string
--- @field smart_case? boolean

local M = {}

---------------------------
--- Grep Prg Management ---
---------------------------

vim.api.nvim_set_var("qf_rancher_grepprg", "rg")

-- local function grep_escape(text)
-- return text:gsub("([%.%^%$%*%+%?%(%)%[%]%{%}%|%\\])", "\\%1")
-- end

--- @param pattern string[]
--- @param location string[]
--- @param opts? QfRancherGrepOpts
--- @return boolean, string[]|[string,string]
--- NOTE: I do not run Windows
local function get_findstr_cmd_parts(pattern, location, opts)
    if not pattern then
        return false, { "No pattern provided to build findstr cmd parts", "ErrorMsg" }
    end

    if not location then
        return false, { "No location provided to build findstr cmd parts", "ErrorMsg" }
    end

    -- Recursive, line num, offset, skip non-printable
    local cmd = { "findstr", "/S", "/N", "/O", "/P" } --- @type string[]

    opts = opts or {}
    if opts.smart_case then
        local has_upper = false --- @type boolean
        for _, p in ipairs(pattern) do
            if p:match("%u") then
                has_upper = true
                break
            end
        end

        if not has_upper then
            table.insert(cmd, "/I")
        end
    end

    if not opts.literal then
        table.insert(cmd, "/R")
    end

    if opts.literal then
        for _, pat in ipairs(pattern) do
            table.insert(cmd, '/C:"' .. pat .. '"')
        end
    else
        local pat_str = #pattern > 1 and table.concat(pattern, "|") or pattern[1]
        table.insert(cmd, '"' .. pat_str .. '"') -- Quote for spaces/special chars
    end

    vim.list_extend(cmd, location)

    return true, cmd
end

--- @param pattern string[]
--- @param location string[]
--- @param opts? QfRancherGrepOpts
--- @return boolean, string[]|[string,string]
local function get_grep_cmd_parts(pattern, location, opts)
    if not pattern then
        return false, { "No pattern provided to build grep cmd parts", "ErrorMsg" }
    end

    if not location then
        return false, { "No location provided to build grep cmd parts", "ErrorMsg" }
    end

    --- recursive search, print filenames, ignore binary files, print line numbers
    local cmd = { "grep", "-rHIn" } --- @type string[]

    opts = opts or {}
    if opts.smart_case then
        local has_upper = false --- @type boolean
        for _, p in ipairs(pattern) do
            if p:match("%u") then
                has_upper = true
                break
            end
        end

        if not has_upper then
            table.insert(cmd, "-i")
        end --- ignore case
    end

    if opts.literal then
        table.insert(cmd, "-F") --- fixed strings
    else
        table.insert(cmd, "-E") --- extended regex
    end

    table.insert(cmd, "--") --- no more flags

    local pat_str = #pattern > 1 and table.concat(pattern, "|") or pattern[1] --- @type string
    table.insert(cmd, pat_str)

    vim.list_extend(cmd, location)

    return true, cmd
end

--- @param pattern string[]
--- @param location string[]
--- @param opts? QfRancherGrepOpts
--- @return boolean, string[]|[string,string]
local function get_rg_cmd_parts(pattern, location, opts)
    if not pattern then
        return false, { "No pattern provided to build rg cmd parts", "ErrorMsg" }
    end

    if not location then
        return false, { "No location provided to build rg cmd parts", "ErrorMsg" }
    end

    --- print each result on its own line, disrespect gitignore
    local cmd = { "rg", "--vimgrep", "-u" } --- @type string[]
    if vim.fn.has("win32") == 1 then
        table.insert(cmd, "--crlf")
    end

    opts = opts or {}
    -- rg's case sensitive flag (-s) is enabled by default
    if opts.smart_case then
        table.insert(cmd, "-S")
    end

    if opts.literal then
        table.insert(cmd, "-F")
    end

    if #pattern > 1 then
        table.insert(cmd, "-U")
    end --- multiline mode

    table.insert(cmd, "--") --- no more flags

    local newline = opts.literal and "\n" or "\\n" --- @type string
    local pat_str = #pattern > 1 and table.concat(pattern, newline) or pattern[1] --- @type string
    table.insert(cmd, pat_str)
    vim.list_extend(cmd, location)

    return true, cmd
end

--- @return boolean, QfRancherGrepCmdFun|[string,string]
local function get_grep_cmd()
    local qf_rancher_grepprg = vim.g.qf_rancher_grepprg

    if qf_rancher_grepprg == "rg" then
        if vim.fn.executable("rg") ~= 1 then
            return false, { "get_grep_cmd: rg is not executable", "ErrorMsg" }
        end

        return true, get_rg_cmd_parts
    elseif qf_rancher_grepprg == "grep" then
        if vim.fn.executable("grep") ~= 1 then
            return false, { "get_grep_cmd: grep is not executable", "ErrorMsg" }
        end

        return true, get_grep_cmd_parts
    elseif qf_rancher_grepprg == "findstr" then
        if vim.fn.executable("findstr") ~= 1 then
            return false, { "get_grep_cmd: findstr is not executable", "ErrorMsg" }
        end

        return true, get_findstr_cmd_parts
    end

    if vim.fn.executable("rg") == 1 then
        return true, get_rg_cmd_parts
    elseif vim.fn.executable("grep") == 1 then
        return true, get_grep_cmd_parts
    elseif vim.fn.has("win32") == 1 and vim.fn.executable("findstr") == 1 then
        return true, get_findstr_cmd_parts
    end

    return false, { "get_grep_cmd: No valid grep program found", "" }
end

----------------
-- Grep Funcs --
----------------

--- @return boolean, string[]
local function get_grep_pattern(prompt)
    local mode = vim.fn.mode() --- @type string
    local is_visual = mode == "v" or mode == "V" or mode == "\22" --- @type boolean

    if is_visual then
        return require("mjm.error-list-util").get_visual_pattern(mode)
    end

    --- @type boolean, string
    local ok, pattern = pcall(vim.fn.input, { prompt = prompt, cancelreturn = "" })
    if (ok and pattern == "") or ((not ok) and pattern == "Keyboard interrupt") then
        return false, { "", "" }
    end

    if not ok then
        return false, { (pattern or "Unknown error getting input"), "ErrorMsg" }
    end

    local split_pattern = vim.split(pattern, "\\n")
    return true, split_pattern
end

--- @param grep_location string[]
--- @param grep_opts? QfRancherGrepOpts
--- @return boolean, QfRancherSystemIn|nil
local function get_grep_parts(grep_location, prompt, grep_opts)
    local ok, grep_cmd = get_grep_cmd() --- @type boolean, QfRancherGrepCmdFun|[string,string]
    if (not ok) or type(grep_cmd) ~= "function" then
        --- @type [string, string]
        local backup_chunk = { "Unknown error getting grep cmd", "ErrorMsg" }
        --- @type [string, string]
        local err_chunk = type(grep_cmd) ~= "function" and grep_cmd or backup_chunk
        vim.api.nvim_echo({ err_chunk }, true, { err = true })
        return false, nil
    end

    grep_opts = grep_opts or {}
    -- vim.fn.confirm(vim.inspect(grep_opts))
    local ok_l, raw_pat = (function()
        if grep_opts.pattern and type(grep_opts.pattern) == "string" then
            return true, { grep_opts.pattern }
        else
            return get_grep_pattern(prompt)
        end
    end)() --- @type boolean, string[]

    if not ok_l then
        --- @type [string, string]
        local backup_chunk = { "Unknown error getting grep pattern", "ErrorMsg" }
        local err_chunk = raw_pat or backup_chunk --- @type [string,string]
        vim.api.nvim_echo({ err_chunk }, true, { err = true })
        return false, nil
    end

    --- @type boolean, string[]
    local ok_c, cmd_parts = grep_cmd(raw_pat, grep_location, grep_opts)
    if not ok_c then
        local err_chunk = cmd_parts or { "Unknown error getting cmd parts", "ErrorMsg" }
        vim.api.nvim_echo({ err_chunk }, true, { err = true })
        return false, nil
    end

    --- @type string
    local title = "Grep" --- @type string
    return true, { cmd_parts = cmd_parts, title = title }
end

--- @param grep_loc_fn  QfRancherGrepLocFun
--- @param prompt string
--- @param grep_opts QfRancherGrepOpts
--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function do_grep(grep_loc_fn, prompt, grep_opts, sys_opts)
    local ok, grep_location = grep_loc_fn() --- @type boolean, string[]|[string,string]
    if not ok then
        --- @type [string,string]
        local err_chunk = grep_location or { "Unknown error getting grep location", "ErrorMsg" }
        vim.api.nvim_echo({ err_chunk }, true, { err = true })
        return
    end

    --- @type boolean, QfRancherSystemIn|nil
    local ok_s, system_in = get_grep_parts(grep_location, prompt, grep_opts)
    if ok_s and system_in then
        require("mjm.error-list-system").qf_sys_wrap(system_in, sys_opts)
    end
end

---------------------
--- Grep Commands ---
---------------------

--- @type QfRancherGrepLocFun
local function get_cwd_tbl()
    return true, { vim.fn.getcwd() }
end

function M.grep_cwd(grep_opts, sys_opts)
    grep_opts = grep_opts or {}
    sys_opts = sys_opts or {}
    local prompt = (function()
        if not grep_opts.literal then
            return "CWD Grep (regex): "
        elseif grep_opts.literal and grep_opts.smart_case then
            return "CWD Grep: "
        else
            return "CWD Grep (case sensitive): "
        end
    end)()

    do_grep(get_cwd_tbl, prompt, grep_opts or {}, sys_opts or {})
end

--- @type QfRancherGrepLocFun
local function get_helpdirs()
    local doc_files = vim.api.nvim_get_runtime_file("doc/*.txt", true) --- @type string[]
    if #doc_files == 0 then
        local chunk = { "No doc files found", "ErrorMsg" } --- @type [string,string]
        return false, chunk
    end

    return true, doc_files
end

function M.grep_help(grep_opts, sys_opts)
    grep_opts = grep_opts or {}
    sys_opts = sys_opts or {}
    local prompt = (function()
        if not grep_opts.literal then
            return "Help Grep (regex): "
        elseif grep_opts.literal and grep_opts.smart_case then
            return "Help Grep: "
        else
            return "Help Grep (case sensitive): "
        end
    end)()

    do_grep(get_helpdirs, prompt, grep_opts or {}, sys_opts or {})
end

--- @type QfRancherGrepLocFun
local function get_buflist()
    local bufs = vim.api.nvim_list_bufs() --- @type integer[]
    local fnames = {} --- @type string[]
    for _, buf in pairs(bufs) do
        --- @type boolean
        local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf })
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
        local fname = vim.api.nvim_buf_get_name(buf) --- @type string
        local readable = vim.fn.filereadable(fname) == 1 --- @type boolean
        if buflisted and buftype == "" and readable then
            table.insert(fnames, fname)
        end
    end

    if #fnames == 0 then
        local chunk = { "No valid bufs found", "ErrorMsg" } --- @type [string,string]
        return false, chunk
    end

    return true, fnames
end

function M.grep_bufs(grep_opts, sys_opts)
    grep_opts = grep_opts or {}
    sys_opts = sys_opts or {}
    local prompt = (function()
        if not grep_opts.literal then
            return "Buf Grep (regex): "
        elseif grep_opts.literal and grep_opts.smart_case then
            return "Buf Grep: "
        else
            return "Buf Grep (case sensitive): "
        end
    end)()

    do_grep(get_buflist, prompt, grep_opts or {}, sys_opts or {})
end

--- @type QfRancherGrepLocFun
local function get_cur_buf()
    local buf = vim.api.nvim_get_current_buf() --- @type integer

    local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf }) --- @type boolean

    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
    local good_buftype = buftype == "" or buftype == "help" --- @type boolean

    local fname = vim.api.nvim_buf_get_name(buf) --- @type string
    local readable = vim.fn.filereadable(fname) == 1 --- @type boolean
    local good_file = fname ~= "" and readable --- @type boolean

    if not (buflisted and good_buftype and good_file) then
        --- @type [string,string]
        local chunk = { "Current buffer is not a valid file", "ErrorMsg" }
        return false, chunk
    end

    return true, { fname }
end

function M.grep_cbuf(grep_opts, sys_opts)
    grep_opts = grep_opts or {}
    sys_opts = sys_opts or {}
    local prompt = (function()
        if not grep_opts.literal then
            return "Current Buf Grep (regex): "
        elseif grep_opts.literal and grep_opts.smart_case then
            return "Current Buf Grep: "
        else
            return "Current Buf Grep (case sensitive): "
        end
    end)()

    do_grep(get_cur_buf, prompt, grep_opts or {}, sys_opts or {})
end

return M

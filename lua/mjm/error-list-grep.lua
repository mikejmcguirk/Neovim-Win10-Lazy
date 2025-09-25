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
--- @field smart_case? boolean
--- @field literal? boolean

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
    local qf_rancher_grepprg = vim.api.nvim_get_var("qf_rancher_grepprg")

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
--- Assumes that it is being called in visual mode with a valid mode parameter
local function get_visual_pattern(mode)
    local start_pos = vim.fn.getpos(".") --- @type Range4
    local end_pos = vim.fn.getpos("v") --- @type Range4
    local region = vim.fn.getregion(start_pos, end_pos, { type = mode }) --- @type string[]

    local lines = {} --- @type string[]
    if #region == 1 then
        local trimmed = region[1]:gsub("^%s*(.-)%s*$", "%1") --- @type string
        if trimmed == "" then
            return false, { "get_visual_pattern: Empty selection", "" }
        end

        table.insert(lines, trimmed)
    else
        lines = region
        local has_valid_line = false --- @type boolean
        for _, line in ipairs(lines) do
            if line ~= "" then
                has_valid_line = true
                break
            end
        end

        if not has_valid_line then
            return false, { "get_visual_pattern: Empty selection", "" }
        end
    end

    vim.api.nvim_cmd({ cmd = "normal", args = { "\27" }, bang = true }, {})
    return true, lines
end

--- @return boolean, string[]
local function get_grep_pattern(prompt)
    local mode = vim.fn.mode() --- @type string
    local is_visual = mode == "v" or mode == "V" or mode == "\22" --- @type boolean

    if is_visual then
        return get_visual_pattern(mode)
    end

    --- @type boolean, string
    local ok, pattern = pcall(vim.fn.input, { prompt = prompt, cancelreturn = "" })
    if (ok and pattern == "") or ((not ok) and pattern == "Keyboard interrupt") then
        return false, { "", "" }
    end

    if not ok then
        return false, { (pattern or "Unknown error getting input"), "ErrorMsg" }
    end

    return true, vim.split(pattern, "\\n")
end

--- @param grep_location string[]
--- @param grep_opts? QfRancherGrepOpts
--- @return boolean, QfRancherSystemIn|nil
local function get_grep_parts(grep_location, prompt, grep_opts)
    local ok, grep_cmd = get_grep_cmd() --- @type boolean, QfRancherGrepCmdFun|[string,string]
    if (not ok) or type(grep_cmd) ~= "function" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep cmd", "ErrorMsg" }
        --- @type [string, string]
        local err_chunk = type(grep_cmd) ~= "function" and grep_cmd or backup_chunk
        vim.api.nvim_echo({ err_chunk }, true, { err = true })
        return false, nil
    end

    local ok_l, raw_pat = get_grep_pattern(prompt) --- @type boolean, string[]
    if not ok_l then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep pattern", "ErrorMsg" }
        local err_chunk = raw_pat or backup_chunk --- @type [string,string]
        vim.api.nvim_echo({ err_chunk }, true, { err = true })
        return false, nil
    end

    grep_opts = grep_opts or {}

    --- @type boolean, string[]
    local ok_c, cmd_parts = grep_cmd(raw_pat, grep_location, grep_opts)
    if not ok_c then
        local err_chunk = cmd_parts or { "Unknown error getting cmd parts", "ErrorMsg" }
        vim.api.nvim_echo({ err_chunk }, true, { err = true })
        return false, nil
    end

    --- @type string
    local disp_pattern = #raw_pat > 1 and table.concat(raw_pat, " | ") or raw_pat[1]
    --- @type string
    local disp_location = #grep_location == 1 and vim.fn.fnamemodify(grep_location[1], ":t")
        or (#grep_location .. " files")
    local title = string.format('Grep "%s" in %s', disp_pattern, disp_location) --- @type string

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
    else
        vim.api.nvim_echo({ { "Unable to get grep parts", "ErrorMsg" } }, true, { err = true })
    end
end

---------------------
--- Grep Commands ---
---------------------

--- @type QfRancherSystemOpts
local grep_n = { async = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local grep_r = { async = true, overwrite = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local grep_a = { async = true, add = true, timeout = 2000 }

--- @type QfRancherSystemOpts
local lgrep_n = { async = true, loclist = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local lgrep_r = { async = true, loclist = true, overwrite = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local lgrep_a = { async = true, loclist = true, add = true, timeout = 2000 }

--- @type QfRancherGrepLocFun
local function get_cwd_tbl()
    return true, { vim.fn.getcwd() }
end

--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function grep_cwd(sys_opts)
    do_grep(get_cwd_tbl, "CWD Grep: ", { literal = true, smart_case = true }, sys_opts or {})
end

function M.grep_cwd_n()
    grep_cwd(grep_n)
end

function M.grep_cwd_r()
    grep_cwd(grep_r)
end

function M.grep_cwd_a()
    grep_cwd(grep_a)
end

function M.lgrep_cwd_n()
    grep_cwd(lgrep_n)
end

function M.lgrep_cwd_r()
    grep_cwd(lgrep_r)
end

function M.lgrep_cwd_a()
    grep_cwd(lgrep_a)
end

--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function grep_CWD(sys_opts)
    do_grep(get_cwd_tbl, "CWD Grep (case-sensitive): ", { literal = true }, sys_opts or {})
end

function M.grep_CWD_n()
    grep_CWD(grep_n)
end

function M.grep_CWD_r()
    grep_CWD(grep_r)
end

function M.grep_CWD_a()
    grep_CWD(grep_a)
end

function M.lgrep_CWD_n()
    grep_CWD(lgrep_n)
end

function M.lgrep_CWD_r()
    grep_CWD(lgrep_r)
end

function M.lgrep_CWD_a()
    grep_CWD(lgrep_a)
end

--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function grep_cwdX(sys_opts)
    do_grep(get_cwd_tbl, "CWD Grep (regex): ", {}, sys_opts or {})
end

function M.grep_cwdX_n()
    grep_cwdX(grep_n)
end

function M.grep_cwdX_r()
    grep_cwdX(grep_r)
end

function M.grep_cwdX_a()
    grep_cwdX(grep_a)
end

function M.lgrep_cwdX_n()
    grep_cwdX(lgrep_n)
end

function M.lgrep_cwdX_r()
    grep_cwdX(lgrep_r)
end

function M.lgrep_cwdX_a()
    grep_cwdX(lgrep_a)
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

--- @type QfRancherSystemOpts
local hgrep_n = { async = true, type = "\1", timeout = 2000 }
--- @type QfRancherSystemOpts
local hgrep_r = { async = true, type = "\1", overwrite = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local hgrep_a = { async = true, type = "\1", add = true, timeout = 2000 }

--- @type QfRancherSystemOpts
local hlgrep_n = { async = true, type = "\1", loclist = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local hlgrep_r = { async = true, type = "\1", loclist = true, overwrite = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local hlgrep_a = { async = true, type = "\1", loclist = true, add = true, timeout = 2000 }

--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function grep_help(sys_opts)
    do_grep(get_helpdirs, "Help Grep: ", { literal = true, smart_case = true }, sys_opts or {})
end

function M.grep_help_n()
    grep_help(hgrep_n)
end

function M.grep_help_r()
    grep_help(hgrep_r)
end

function M.grep_help_a()
    grep_help(hgrep_a)
end

function M.lgrep_help_n()
    grep_help(hlgrep_n)
end

function M.lgrep_help_r()
    grep_help(hlgrep_r)
end

function M.lgrep_help_a()
    grep_help(hlgrep_a)
end

--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function grep_HELP(sys_opts)
    do_grep(get_helpdirs, "Help Grep (case-sensitive): ", { literal = true }, sys_opts or {})
end

function M.grep_HELP_n()
    grep_HELP(hgrep_n)
end

function M.grep_HELP_r()
    grep_HELP(hgrep_r)
end

function M.grep_HELP_a()
    grep_HELP(hgrep_a)
end

function M.lgrep_HELP_n()
    grep_HELP(hlgrep_n)
end

function M.lgrep_HELP_r()
    grep_HELP(hlgrep_r)
end

function M.lgrep_HELP_a()
    grep_HELP(hlgrep_a)
end

--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function grep_helpX(sys_opts)
    do_grep(get_helpdirs, "HELP Grep (regex): ", {}, sys_opts or {})
end

function M.grep_helpX_n()
    grep_helpX(hgrep_n)
end

function M.grep_helpX_r()
    grep_helpX(hgrep_r)
end

function M.grep_helpX_a()
    grep_helpX(hgrep_a)
end

function M.lgrep_helpX_n()
    grep_helpX(hlgrep_n)
end

function M.lgrep_helpX_r()
    grep_helpX(hlgrep_r)
end

function M.lgrep_helpX_a()
    grep_helpX(hlgrep_a)
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

--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function grep_bufs(sys_opts)
    do_grep(get_buflist, "Buf Grep: ", { literal = true, smart_case = true }, sys_opts or {})
end

function M.grep_bufs_n()
    grep_bufs(grep_n)
end

function M.grep_bufs_r()
    grep_bufs(grep_r)
end

function M.grep_bufs_a()
    grep_bufs(grep_a)
end

--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function grep_BUFS(sys_opts)
    do_grep(get_buflist, "Buf Grep (case-sensitive): ", { literal = true }, sys_opts or {})
end

function M.grep_BUFS_n()
    grep_BUFS(grep_n)
end

function M.grep_BUFS_r()
    grep_BUFS(grep_r)
end

function M.grep_BUFS_a()
    grep_BUFS(grep_a)
end

--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function grep_bufsX(sys_opts)
    do_grep(get_buflist, "Buf Grep (regex): ", {}, sys_opts or {})
end

function M.grep_bufsX_n()
    grep_bufsX(grep_n)
end

function M.grep_bufsX_r()
    grep_bufsX(grep_r)
end

function M.grep_bufsX_a()
    grep_bufsX(grep_a)
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

--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function grep_cbuf(sys_opts)
    do_grep(get_cur_buf, "Buf Grep: ", { literal = true, smart_case = true }, sys_opts or {})
end

function M.grep_cbuf_n()
    grep_cbuf(lgrep_n)
end

function M.grep_cbuf_r()
    grep_cbuf(lgrep_r)
end

function M.grep_cbuf_a()
    grep_cbuf(lgrep_a)
end

--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function grep_CBUF(sys_opts)
    do_grep(get_cur_buf, "Buf Grep (case-sensitive): ", { literal = true }, sys_opts or {})
end

function M.grep_CBUF_n()
    grep_CBUF(lgrep_n)
end

function M.grep_CBUF_r()
    grep_CBUF(lgrep_r)
end

function M.grep_CBUF_a()
    grep_CBUF(lgrep_a)
end

--- @param sys_opts QfRancherSystemOpts
--- @return nil
local function grep_cbufX(sys_opts)
    do_grep(get_cur_buf, "Buf Grep (regex): ", {}, sys_opts or {})
end

function M.grep_cbufX_n()
    grep_cbufX(lgrep_n)
end

function M.grep_cbufX_r()
    grep_cbufX(lgrep_r)
end

function M.grep_cbufX_a()
    grep_cbufX(lgrep_a)
end

return M

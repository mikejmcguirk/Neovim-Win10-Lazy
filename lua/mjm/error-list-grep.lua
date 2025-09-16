--- TODO: The keymaps should sync up with the filter/sort/diag maps

--- MAYBE: Smart/ignore case can be rolled under the same option for grepprgs that don't
--- support it

--- FUTURE: Potentially use rg's built-in globbing. But don't want to create inconsistencies with
--- other grep cmds
--- FUTURE: If this can be done, use cmd literal for title

-- Escaping test line from From vim-grepper
-- Make sure to query the text part specifically. The comment dashw will make it interpret as an
-- option
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
    local cmd = { "findstr", "/S", "/N", "/O", "/P" }

    opts = opts or {}
    if opts.smart_case then
        local has_upper = false
        for _, p in ipairs(pattern) do
            if p:match("%u") then
                has_upper = true
                break
            end
        end
        if not has_upper then table.insert(cmd, "/I") end
    end

    if not opts.literal then table.insert(cmd, "/R") end

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
    local cmd = { "grep", "-rHIn" }

    opts = opts or {}
    if opts.smart_case then
        local has_upper = false
        for _, p in ipairs(pattern) do
            if p:match("%u") then
                has_upper = true
                break
            end
        end

        if not has_upper then table.insert(cmd, "-i") end --- ignore case
    end

    if opts.literal then
        table.insert(cmd, "-F") --- fixed strings
    else
        table.insert(cmd, "-E") --- extended regex
    end

    table.insert(cmd, "--") --- no more flags

    local pat_str = #pattern > 1 and table.concat(pattern, "|") or pattern[1]
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
    if vim.fn.has("win32") == 1 then table.insert(cmd, "--crlf") end

    opts = opts or {}
    -- rg's case sensitive flag (-s) is enabled by default
    if opts.smart_case then table.insert(cmd, "-S") end
    if opts.literal then table.insert(cmd, "-F") end

    if #pattern > 1 then table.insert(cmd, "-U") end --- multiline mode

    table.insert(cmd, "--") --- no more flags

    local newline = opts.literal and "\n" or "\\n" --- @type string
    local pat_str = #pattern > 1 and table.concat(pattern, newline) or pattern[1] --- @type string
    table.insert(cmd, pat_str)

    vim.list_extend(cmd, location)

    return true, cmd
end

--- @return boolean, QfRancherGrepCmdFun|[string,string]
--- TODO: Run a validity check for the grep program once. An additional filesystem call should not
--- be run on each grep
local function get_grep_cmd()
    local qf_rancher_grepprg = vim.api.nvim_get_var("qf_rancher_grepprg")

    if qf_rancher_grepprg == "rg" then
        -- if vim.fn.executable("rg") ~= 1 then
        --     return false, { "get_grep_cmd: rg is not executable", "ErrorMsg" }
        -- end

        return true, get_rg_cmd_parts
    elseif qf_rancher_grepprg == "grep" then
        -- if vim.fn.executable("grep") ~= 1 then
        --     return false, { "get_grep_cmd: grep is not executable", "ErrorMsg" }
        -- end

        return true, get_grep_cmd_parts
    elseif qf_rancher_grepprg == "findstr" then
        -- if vim.fn.executable("findstr") ~= 1 then
        --     return false, { "get_grep_cmd: findstr is not executable", "ErrorMsg" }
        -- end

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

--- @param loc_fun QfRancherGrepLocFun
--- @param grep_opts? QfRancherGrepOpts
--- @return boolean, QfRancherSystemIn
local function grep_master(loc_fun, prompt, grep_opts)
    local ok, grep_cmd = get_grep_cmd() --- @type boolean, QfRancherGrepCmdFun|[string,string]
    if (not ok) or type(grep_cmd) ~= "function" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep cmd", "ErrorMsg" }
        --- @type [string, string]
        local err_chunk = type(grep_cmd) ~= "function" and grep_cmd or backup_chunk
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local ok_b, buf_files = loc_fun() --- @type boolean, string[]|[string,string]
    if not ok_b then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep location", "ErrorMsg" }
        local err_chunk = buf_files or backup_chunk --- @type [string,string]
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local ok_l, raw_pat = get_grep_pattern(prompt) --- @type boolean, string[]|QfRancherSystemIn
    if not ok_l or type(raw_pat) ~= "table" then
        --- @type [string, string]
        local backup_chunk = { "grep_cbuf: Unknown error getting grep pattern", "ErrorMsg" }
        local err_chunk = raw_pat.err_chunk or backup_chunk --- @type [string,string]
        local err_msg_hist = raw_pat.err_msg_hist == false and false or true --- @type boolean
        return false, { err_chunk = err_chunk, err_msg_hist = err_msg_hist or true }
    end

    grep_opts = grep_opts or {}

    --- @type boolean, string[]|[string,string]
    local ok_c, cmd_parts = grep_cmd(raw_pat, buf_files, grep_opts)
    if not ok_c then
        local err_chunk = cmd_parts or { "grep_cbuf: Unknown error getting cmd parts", "ErrorMsg" }
        return false, { err_chunk = err_chunk, err_msg_hist = true }
    end

    local disp_pattern = #raw_pat > 1 and table.concat(raw_pat, " | ") or raw_pat[1]
    local disp_location = #buf_files == 1 and vim.fn.fnamemodify(buf_files[1], ":t")
        or (#buf_files .. " files")
    local title = string.format('Grep "%s" in %s', disp_pattern, disp_location)

    return true, { cmd_parts = cmd_parts, title = title }
end

---------------------
--- Grep Commands ---
---------------------

-- Don't fall back to defaults
vim.keymap.set({ "n", "x" }, "<leader>qg", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>qG", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>lg", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>lG", "<nop>")
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>", "<nop>")

--- @type QfRancherSystemOpts
local grep_b = { async = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local grep_o = { async = true, overwrite = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local grep_m = { async = true, merge = true, timeout = 2000 }

--- @type QfRancherSystemOpts
local lgrep_b = { async = true, loclist = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local lgrep_o = { async = true, loclist = true, overwrite = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local lgrep_m = { async = true, loclist = true, merge = true, timeout = 2000 }

--- @type QfRancherGrepLocFun
local function get_cwd_tbl() return true, { vim.fn.getcwd() } end

--- @return boolean, QfRancherSystemIn
local function grep_cwd()
    local prompt = "CWD Grep: " --- @type string
    return grep_master(get_cwd_tbl, prompt, { literal = true, smart_case = true })
end

local qgd = function() require("mjm.error-list-system").qf_sys_wrap(grep_cwd, grep_b) end
vim.keymap.set({ "n", "x" }, "<leader>qgd", qgd)
local qGd = function() require("mjm.error-list-system").qf_sys_wrap(grep_cwd, grep_o) end
vim.keymap.set({ "n", "x" }, "<leader>qGd", qGd)
local qCgd = function() require("mjm.error-list-system").qf_sys_wrap(grep_cwd, grep_m) end
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>d", qCgd)

local lgd = function() require("mjm.error-list-system").qf_sys_wrap(grep_cwd, lgrep_b) end
vim.keymap.set({ "n", "x" }, "<leader>lgd", lgd)
local lGd = function() require("mjm.error-list-system").qf_sys_wrap(grep_cwd, lgrep_o) end
vim.keymap.set({ "n", "x" }, "<leader>lGd", lGd)
local lCgd = function() require("mjm.error-list-system").qf_sys_wrap(grep_cwd, lgrep_m) end
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>d", lCgd)

--- @return boolean, QfRancherSystemIn
local function grep_CWD()
    local prompt = "CWD Grep (case-sensitive): " --- @type string
    return grep_master(get_cwd_tbl, prompt, { literal = true })
end

local qgD = function() require("mjm.error-list-system").qf_sys_wrap(grep_CWD, grep_b) end
vim.keymap.set({ "n", "x" }, "<leader>qgD", qgD)
local qGD = function() require("mjm.error-list-system").qf_sys_wrap(grep_CWD, grep_o) end
vim.keymap.set({ "n", "x" }, "<leader>qGD", qGD)
local qCgD = function() require("mjm.error-list-system").qf_sys_wrap(grep_CWD, grep_m) end
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>D", qCgD)

local lgD = function() require("mjm.error-list-system").qf_sys_wrap(grep_CWD, lgrep_b) end
vim.keymap.set({ "n", "x" }, "<leader>lgD", lgD)
local lGD = function() require("mjm.error-list-system").qf_sys_wrap(grep_CWD, lgrep_o) end
vim.keymap.set({ "n", "x" }, "<leader>lGD", lGD)
local lCgD = function() require("mjm.error-list-system").qf_sys_wrap(grep_CWD, lgrep_m) end
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>D", lCgD)

--- @return boolean, QfRancherSystemIn
local function grep_cwdX()
    local prompt = "CWD Grep (regex): " --- @type string
    return grep_master(get_cwd_tbl, prompt)
end

local qgCd = function() require("mjm.error-list-system").qf_sys_wrap(grep_cwdX, grep_b) end
vim.keymap.set({ "n", "x" }, "<leader>qg<C-d>", qgCd)
local qGCd = function() require("mjm.error-list-system").qf_sys_wrap(grep_cwdX, grep_o) end
vim.keymap.set({ "n", "x" }, "<leader>qG<C-d>", qGCd)
local qCgCd = function() require("mjm.error-list-system").qf_sys_wrap(grep_cwdX, grep_m) end
vim.keymap.set({ "n", "x" }, "<leader>q<C-g><C-d>", qCgCd)

local lgCd = function() require("mjm.error-list-system").qf_sys_wrap(grep_cwdX, lgrep_b) end
vim.keymap.set({ "n", "x" }, "<leader>lg<C-d>", lgCd)
local lGCd = function() require("mjm.error-list-system").qf_sys_wrap(grep_cwdX, lgrep_o) end
vim.keymap.set({ "n", "x" }, "<leader>lG<C-d>", lGCd)
local lCgCd = function() require("mjm.error-list-system").qf_sys_wrap(grep_cwdX, lgrep_m) end
vim.keymap.set({ "n", "x" }, "<leader>l<C-g><C-d>", lCgCd)

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
local hgrep_b = { async = true, type = "\1", timeout = 2000 }
--- @type QfRancherSystemOpts
local hgrep_o = { async = true, type = "\1", overwrite = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local hgrep_m = { async = true, type = "\1", merge = true, timeout = 2000 }

--- @type QfRancherSystemOpts
local hlgrep_b = { async = true, type = "\1", loclist = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local hlgrep_o = { async = true, type = "\1", loclist = true, overwrite = true, timeout = 2000 }
--- @type QfRancherSystemOpts
local hlgrep_m = { async = true, type = "\1", loclist = true, merge = true, timeout = 2000 }

--- @return boolean, QfRancherSystemIn
local function grep_help()
    local prompt = "Help Grep: " --- @type string
    return grep_master(get_helpdirs, prompt, { literal = true, smart_case = true })
end

local qgh = function() require("mjm.error-list-system").qf_sys_wrap(grep_help, hgrep_b) end
vim.keymap.set({ "n", "x" }, "<leader>qgh", qgh)
local qGh = function() require("mjm.error-list-system").qf_sys_wrap(grep_help, hgrep_o) end
vim.keymap.set({ "n", "x" }, "<leader>qGh", qGh)
local qCgh = function() require("mjm.error-list-system").qf_sys_wrap(grep_help, hgrep_m) end
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>h", qCgh)

local lgh = function() require("mjm.error-list-system").qf_sys_wrap(grep_help, hlgrep_b) end
vim.keymap.set({ "n", "x" }, "<leader>lgh", lgh)
local lGh = function() require("mjm.error-list-system").qf_sys_wrap(grep_help, hlgrep_o) end
vim.keymap.set({ "n", "x" }, "<leader>lGh", lGh)
local lCgh = function() require("mjm.error-list-system").qf_sys_wrap(grep_help, hlgrep_m) end
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>h", lCgh)

--- @return boolean, QfRancherSystemIn
local function grep_HELP()
    local prompt = "Help Grep (case-sensitive): " --- @type string
    return grep_master(get_helpdirs, prompt, { literal = true })
end

local qgH = function() require("mjm.error-list-system").qf_sys_wrap(grep_HELP, hgrep_b) end
vim.keymap.set({ "n", "x" }, "<leader>qgH", qgH)
local qGH = function() require("mjm.error-list-system").qf_sys_wrap(grep_HELP, hgrep_o) end
vim.keymap.set({ "n", "x" }, "<leader>qGH", qGH)
local qCgH = function() require("mjm.error-list-system").qf_sys_wrap(grep_HELP, hgrep_m) end
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>H", qCgH)

local lgH = function() require("mjm.error-list-system").qf_sys_wrap(grep_HELP, hlgrep_b) end
vim.keymap.set({ "n", "x" }, "<leader>lgH", lgH)
local lGH = function() require("mjm.error-list-system").qf_sys_wrap(grep_HELP, hlgrep_o) end
vim.keymap.set({ "n", "x" }, "<leader>lGH", lGH)
local lCgH = function() require("mjm.error-list-system").qf_sys_wrap(grep_HELP, hlgrep_m) end
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>H", lCgH)

--- @return boolean, QfRancherSystemIn
local function grep_helpX()
    local prompt = "Help Grep (regex): " --- @type string
    return grep_master(get_helpdirs, prompt)
end

local qgCh = function() require("mjm.error-list-system").qf_sys_wrap(grep_helpX, grep_b) end
vim.keymap.set({ "n", "x" }, "<leader>qg<C-h>", qgCh)
local qGCh = function() require("mjm.error-list-system").qf_sys_wrap(grep_helpX, grep_o) end
vim.keymap.set({ "n", "x" }, "<leader>qG<C-h>", qGCh)
local qCgCh = function() require("mjm.error-list-system").qf_sys_wrap(grep_helpX, grep_m) end
vim.keymap.set({ "n", "x" }, "<leader>q<C-g><C-h>", qCgCh)

local lgCh = function() require("mjm.error-list-system").qf_sys_wrap(grep_helpX, lgrep_b) end
vim.keymap.set({ "n", "x" }, "<leader>lg<C-h>", lgCh)
local lGCh = function() require("mjm.error-list-system").qf_sys_wrap(grep_helpX, lgrep_o) end
vim.keymap.set({ "n", "x" }, "<leader>lG<C-h>", lGCh)
local lCgCh = function() require("mjm.error-list-system").qf_sys_wrap(grep_helpX, lgrep_m) end
vim.keymap.set({ "n", "x" }, "<leader>l<C-g><C-h>", lCgCh)

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

        if buflisted and buftype == "" and readable then table.insert(fnames, fname) end
    end

    if #fnames == 0 then
        local chunk = { "No valid bufs found", "ErrorMsg" } --- @type [string,string]
        return false, chunk
    end

    return true, fnames
end

--- @return boolean, QfRancherSystemIn
local function grep_bufs()
    local prompt = "Buf Grep: "
    return grep_master(get_buflist, prompt, { literal = true, smart_case = true })
end

local qgu = function() require("mjm.error-list-system").qf_sys_wrap(grep_bufs, grep_b) end
vim.keymap.set({ "n", "x" }, "<leader>qgu", qgu)
local qGu = function() require("mjm.error-list-system").qf_sys_wrap(grep_bufs, grep_o) end
vim.keymap.set({ "n", "x" }, "<leader>qGu", qGu)
local qCgu = function() require("mjm.error-list-system").qf_sys_wrap(grep_bufs, grep_m) end
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>u", qCgu)

--- @return boolean, QfRancherSystemIn
local function grep_BUFS()
    local prompt = "Buf Grep (case-sensitive): "
    return grep_master(get_buflist, prompt, { literal = true })
end

local qgU = function() require("mjm.error-list-system").qf_sys_wrap(grep_BUFS, grep_b) end
vim.keymap.set({ "n", "x" }, "<leader>qgU", qgU)
local qGU = function() require("mjm.error-list-system").qf_sys_wrap(grep_BUFS, grep_o) end
vim.keymap.set({ "n", "x" }, "<leader>qGU", qGU)
local qCgU = function() require("mjm.error-list-system").qf_sys_wrap(grep_BUFS, grep_m) end
vim.keymap.set({ "n", "x" }, "<leader>q<C-g>U", qCgU)

--- @return boolean, QfRancherSystemIn
local function grep_bufsX()
    local prompt = "Buf Grep (regex): " --- @type string
    return grep_master(get_buflist, prompt)
end

local qgCu = function() require("mjm.error-list-system").qf_sys_wrap(grep_bufsX, grep_b) end
vim.keymap.set({ "n", "x" }, "<leader>qg<C-u>", qgCu)
local qGCu = function() require("mjm.error-list-system").qf_sys_wrap(grep_bufsX, grep_o) end
vim.keymap.set({ "n", "x" }, "<leader>qG<C-u>", qGCu)
local qCgCu = function() require("mjm.error-list-system").qf_sys_wrap(grep_bufsX, grep_m) end
vim.keymap.set({ "n", "x" }, "<leader>q<C-g><C-u>", qCgCu)

--- @type QfRancherGrepLocFun
local function get_cur_buf_fname()
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
        return false, chunk
    end

    return true, { fname }
end

--- @return boolean, QfRancherSystemIn
local function grep_cbuf()
    local prompt = "Current Buf Grep: " --- @type string
    return grep_master(get_cur_buf_fname, prompt, { literal = true, smart_case = true })
end

local lgu = function() require("mjm.error-list-system").qf_sys_wrap(grep_cbuf, lgrep_b) end
vim.keymap.set({ "n", "x" }, "<leader>lgu", lgu)
local lGu = function() require("mjm.error-list-system").qf_sys_wrap(grep_cbuf, lgrep_o) end
vim.keymap.set({ "n", "x" }, "<leader>lGu", lGu)
local lCgu = function() require("mjm.error-list-system").qf_sys_wrap(grep_cbuf, lgrep_m) end
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>u", lCgu)

--- @return boolean, QfRancherSystemIn
local function grep_CBUF()
    local prompt = "Current Buf Grep (case-sensitive): " --- @type string
    return grep_master(get_cur_buf_fname, prompt, { literal = true })
end

local lgU = function() require("mjm.error-list-system").qf_sys_wrap(grep_CBUF, lgrep_b) end
vim.keymap.set({ "n", "x" }, "<leader>lgU", lgU)
local lGU = function() require("mjm.error-list-system").qf_sys_wrap(grep_CBUF, lgrep_o) end
vim.keymap.set({ "n", "x" }, "<leader>lGU", lGU)
local lCgU = function() require("mjm.error-list-system").qf_sys_wrap(grep_CBUF, lgrep_m) end
vim.keymap.set({ "n", "x" }, "<leader>l<C-g>U", lCgU)

--- @return boolean, QfRancherSystemIn
local function grep_cbufX()
    local prompt = "Current Buf Grep (regex): " --- @type string
    return grep_master(get_cur_buf_fname, prompt)
end

local lgCu = function() require("mjm.error-list-system").qf_sys_wrap(grep_cbufX, lgrep_b) end
vim.keymap.set({ "n", "x" }, "<leader>lg<C-u>", lgCu)
local lGCu = function() require("mjm.error-list-system").qf_sys_wrap(grep_cbufX, lgrep_o) end
vim.keymap.set({ "n", "x" }, "<leader>lG<C-u>", lGCu)
local lCgCu = function() require("mjm.error-list-system").qf_sys_wrap(grep_cbufX, lgrep_m) end
vim.keymap.set({ "n", "x" }, "<leader>l<C-g><C-u>", lCgCu)

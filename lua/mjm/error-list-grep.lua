-- Escaping test line from From vim-grepper
-- ..ad\\f40+$':-# @=,!;%^&&*()_{}/ /4304\'""?`9$343%$ ^adfadf[ad)[(

local ee = Qfr_Defer_Require("mjm.error-list-system") ---@type QfrSystem
local eu = Qfr_Defer_Require("mjm.error-list-util") ---@type QfrUtil
local ey = Qfr_Defer_Require("mjm.error-list-types") ---@type QfrTypes

local api = vim.api
local fn = vim.fn

---@mod Grep Grep items into the list

---@class QfrGrep
local Grep = {}

-- ========================
-- == GREPPRG/GREP PARTS ==
-- ========================

-- MID: The grepprgs should live in their own module, with type annotations serving as an
-- interface for how they are interacted with. This would standardize development and allow for
-- registering custom grepprgs. This does create a source of truth conflict with the g_var though
-- This could allow for building out behaviors like setting hidden file behavior. Looking at
-- vim-grepper would be a good idea here

-- LOW: Support ack
-- LOW: When handling multiple locations, the grepprgs should build their arguments using
-- globbing rather than appending potentially dozens of locations
-- LOW: If vim.fn.executable succeeds, it shouldn't be re-run unless it then fails in the future
-- Unsure how to pass that behavior to vim.system though

local base_parts = {
    rg = { "rg", "--vimgrep", "-uu" },
    grep = { "grep", "--recursive", "--with-filename", "--line-number", "-I" },
} ---@type table<string, string[]>

---@type QfrGrepPartsFunc
local function get_full_parts_rg(pattern, input_type, locations)
    local cmd = vim.deepcopy(base_parts.rg, true) ---@type string[]

    if fn.has("win32") == 1 then table.insert(cmd, "--crlf") end

    if input_type == "smartcase" then
        table.insert(cmd, "--smart-case") -- or "-S"
    elseif input_type == "insensitive" then
        table.insert(cmd, "--ignore-case") -- or "-i"
    end

    if input_type ~= "regex" then
        table.insert(cmd, "--fixed-strings") -- or "-F"
    end

    if string.find(pattern, "\n", 1, true) ~= nil then
        table.insert(cmd, "--multiline") -- or "-U"
    end

    table.insert(cmd, "--")
    table.insert(cmd, pattern)
    vim.list_extend(cmd, locations)

    return cmd
end

---@type QfrGrepPartsFunc
local function get_full_parts_grep(pattern, input_type, locations)
    local cmd = vim.deepcopy(base_parts.grep) ---@type string[]

    if input_type == "regex" then
        table.insert(cmd, "--extended-regexp") -- or "-E"
    else
        table.insert(cmd, "--fixed-strings") -- or "-F"
    end

    ---@type boolean
    local smartcase = input_type == "smartcase" and string.lower(pattern) == pattern
    if smartcase or input_type == "insensitive" then
        table.insert(cmd, "--ignore-case") -- or "-i"
    end

    table.insert(cmd, "--")
    -- No multiline mode in vanilla grep, so fall back to or comparison
    local sub_pattern = string.gsub(pattern, "\n", "|")
    table.insert(cmd, sub_pattern)
    vim.list_extend(cmd, locations)

    return cmd
end

local get_full_parts = {
    grep = get_full_parts_grep,
    rg = get_full_parts_rg,
} ---@type table<string, function>

-- ========================
-- == MAIN GREP FUNCTION ==
-- ========================

-- LOW: Add a grep_opts table with grepprg as an option. You could also use this for controlling
-- the behaviors of the grepprgs, such as whether or not to check hidden or gitignored files
-- This is gated behind a grepprg interface I'm more confident in

---@param grep_info QfRancherGrepInfo
---@param input_opts QfrInputOpts
---@param system_opts QfrSystemOpts
---@param output_opts QfrOutputOpts
---@return nil
local function do_grep(grep_info, input_opts, system_opts, output_opts)
    ey._validate_grep_info(grep_info)
    ey._validate_system_opts(system_opts)
    ey._validate_input_opts(input_opts)
    ey._validate_output_opts(output_opts)

    local src_win = output_opts.src_win ---@type integer|nil
    if src_win and not eu._valid_win_for_loclist(src_win) then return end

    local locations = grep_info.location_func() ---@type string[]
    if #locations < 1 then return end

    local grepprg = eu._get_g_var("qf_rancher_grepprg") ---@type string
    if fn.executable(grepprg) ~= 1 then
        local chunk = { grepprg .. " is not executable", "ErrorMsg" }
        api.nvim_echo({ chunk }, true, { err = true })
        return
    end

    local input_type = eu._resolve_input_type(input_opts.input_type) ---@type QfrInputType
    local display_input_type = eu._get_display_input_type(input_type) ---@type string
    local which_grep = "[" .. grepprg .. "] " .. grep_info.name .. " Grep " ---@type string
    local prompt = which_grep .. "(" .. display_input_type .. "): " ---@type string

    local pattern = eu._resolve_pattern(prompt, input_opts.pattern, input_type) ---@type string|nil
    if not pattern then return end

    local grep_parts = get_full_parts[grepprg](pattern, input_type, locations) ---@type string[]
    if (not grep_parts) or #grep_parts == 0 then return end

    local full_system_opts = vim.deepcopy(system_opts, true) ---@type QfrSystemOpts
    full_system_opts.cmd_parts = grep_parts

    local sys_output_opts = vim.deepcopy(output_opts, true) ---@type QfrOutputOpts
    local what = sys_output_opts.what ---@type QfrWhat
    what.title = table.concat(base_parts[grepprg], " ")
    what.user_data = what.user_data or {}
    what.user_data.list_item_type = grep_info.list_item_type or what.user_data.list_item_type

    sys_output_opts.what = what
    ee.system_do(full_system_opts, sys_output_opts)
end

-- ====================
-- == GREP LOCATIONS ==
-- ====================

-- MID: Grep a specific file. Could show this an an API example
-- MID: Grep in specific treesitter nodes. So qgtm would grep in function definitions. The llist
-- grep is easy because you do it in the current win buf. But for multiple bufs, how do you
-- handle different languages? This almost feels like it needs ts-textobjects

---@return string[]
local function get_cwd()
    return { fn.getcwd() }
end

-- MAYBE: Could look at how FzfLua handles lazy.nvim unloaded paths

---@return string[]|nil
local function get_help_dirs()
    local doc_files = api.nvim_get_runtime_file("doc/*.txt", true) ---@type string[]

    if #doc_files > 0 then return doc_files end
    api.nvim_echo({ { "No doc files found", "ErrorMsg" } }, true, { err = true })
    return nil
end

---@return string[]|nil
local function get_buflist()
    local bufs = api.nvim_list_bufs() ---@type integer[]
    local fnames = {} ---@type string[]

    local function check_buf(buf)
        if not api.nvim_get_option_value("buflisted", { buf = buf }) then return end
        if api.nvim_get_option_value("buftype", { buf = buf }) ~= "" then return end

        local fname = api.nvim_buf_get_name(buf) ---@type string
        local fs_access = vim.uv.fs_access(fname, 4) ---@type boolean|nil
        if fname ~= "" and fs_access then table.insert(fnames, fname) end
    end

    for _, buf in pairs(bufs) do
        check_buf(buf)
    end

    if #fnames > 0 then return fnames end
    api.nvim_echo({ { "No valid bufs found", "" } }, false, {})
    return nil
end

---@return string[]|nil
local function get_cur_buf()
    local buf = api.nvim_get_current_buf() ---@type integer

    if not api.nvim_get_option_value("buflisted", { buf = buf }) then
        api.nvim_echo({ { "Cur buf is not listed", "" } }, false, {})
        return nil
    end

    local buftype = api.nvim_get_option_value("buftype", { buf = buf }) ---@type string
    if not (buftype == "" or buftype == "help") then
        api.nvim_echo({ { "Buftype " .. buftype .. " is not valid", "" } }, false, {})
        return nil
    end

    local fname = api.nvim_buf_get_name(buf) ---@type string
    local fs_access = vim.uv.fs_access(fname, 4) ---@type boolean|nil

    if fname ~= "" and fs_access then return { fname } end
    api.nvim_echo({ { "Current buffer is not a valid file", "" } }, false, {})
    return nil
end

-- =========
-- == API ==
-- =========

local greps = {
    cwd = { name = "CWD", list_item_type = nil, location_func = get_cwd },
    -- DOCUMENT: This will overwrite arbitrary data passed from the caller
    help = { name = "Help", list_item_type = "\1", location_func = get_help_dirs },
    bufs = { name = "Buf", list_item_type = nil, location_func = get_buflist },
    cbuf = { name = "Cur Buf", list_item_type = nil, location_func = get_cur_buf },
} ---@type QfRancherGrepInfo[]

---@return string[]
function Grep.get_grep_names()
    return vim.tbl_keys(greps)
end

-- DOCUMENT: How this works

---@param grep_info QfRancherGrepInfo
---@return nil
function Grep.register_grep(grep_info)
    ey._validate_grep_info(grep_info)
    greps[grep_info.name] = grep_info
end

-- DOCUMENT: How this works
---@param name string
---@return nil
function Grep.clear_grep(name)
    vim.validate("name", name, "string")
    if #vim.tbl_keys(greps) <= 1 then
        api.nvim_echo({ { "Cannot remove the last grep method" } }, false, {})
        return
    end

    if greps[name] then
        greps[name] = nil
        api.nvim_echo({ { name .. " removed from grep list", "" } }, true, {})
    else
        api.nvim_echo({ { name .. " is not a registered grep", "" } }, true, {})
    end
end

-- DOCUMENT: This. necessary to run your grep

---@param name string
---@param input_opts QfrInputOpts
---@param system_opts QfrSystemOpts
---@param output_opts QfrOutputOpts
---@return nil
function Grep.grep(name, input_opts, system_opts, output_opts)
    vim.validate("name", name, "string")

    local grep_info = greps[name] ---@type QfRancherGrepInfo|nil
    if grep_info then
        do_grep(grep_info, input_opts, system_opts, output_opts)
    else
        local chunk = { "Grep " .. name .. " is not registered", "ErrorMsg" }
        api.nvim_echo({ chunk }, true, { err = true })
    end
end

-- ===============
-- == CMD FUNCS ==
-- ===============

---@param src_win? integer
---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
local function grep_cmd(src_win, cargs)
    cargs = cargs or {}
    local fargs = cargs.fargs ---@type string[]

    local grep_names = Grep.get_grep_names() ---@type string[]
    assert(#grep_names > 1, "No grep commands available")
    local grep_name = eu._check_cmd_arg(fargs, grep_names, "cwd") ---@type string

    ---@type QfrInputType
    local input_type = eu._check_cmd_arg(fargs, ey._cmd_input_types, ey._default_input_type)
    local pattern = eu._find_cmd_pattern(fargs) ---@type string|nil
    local input_opts = { input_type = input_type, pattern = pattern } ---@type QfrInputOpts

    ---@type "sync"|"async"
    local sync_str = eu._check_cmd_arg(fargs, ey._sync_opts, ey._default_sync_opt)
    local sync = sync_str == "sync" and true or false ---@type boolean
    -- LOW: Should be able to set the timeout from the cmd
    ---@type QfrSystemOpts
    local system_opts = { sync = sync, timeout = ey._default_timeout }

    ---@type QfrRealAction
    local action = eu._check_cmd_arg(fargs, ey._real_actions, ey._default_real_action)
    ---@type QfrOutputOpts
    local output_opts = { src_win = src_win, action = action, what = { nr = cargs.count } }

    Grep.grep(grep_name, input_opts, system_opts, output_opts)
end

-- DOCUMENT: The documentation for the cmds and the functions should be mixed together along
-- with the default mappings

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Grep.q_grep_cmd(cargs)
    grep_cmd(nil, cargs)
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
function Grep.l_grep_cmd(cargs)
    grep_cmd(api.nvim_get_current_win(), cargs)
end

return Grep
---@export Grep

-- TODO: Docs
-- TODO: Add tests

-- DOCUMENT: Only rg and grep are currently supported
-- - I am not in Windows so I cannot test findstr
-- - I am open to PRs on this
-- DOCUMENT: It is intended behavior that cbuf grep can work on help files, but all bufs will
-- not pull from help files

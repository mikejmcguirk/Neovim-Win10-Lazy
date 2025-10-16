-- Escaping test line from From vim-grepper
-- ..ad\\f40+$':-# @=,!;%^&&*()_{}/ /4304\'""?`9$343%$ ^adfadf[ad)[(

--- @class QfRancherGrep
local M = {}

--------------------------
--- Grepprg/Grep Parts ---
--------------------------

local base_parts = {
    rg = { "rg", "--vimgrep", "-uu" },
    grep = { "grep", "--recursive", "--with-filename", "--line-number", "-I" },
} --- @type table<string, string[]>

--- @type QfRancherGrepPartsFunc
local function get_full_parts_rg(pattern, input_type, locations)
    local cmd = vim.deepcopy(base_parts.rg, true) --- @type string[]

    if vim.fn.has("win32") == 1 then
        table.insert(cmd, "--crlf")
    end

    if input_type == "smartcase" then
        table.insert(cmd, "--smart-case") --- or "-S"
    elseif input_type == "insensitive" then
        table.insert(cmd, "--ignore-case") --- or "-i"
    end

    if input_type ~= "regex" then
        table.insert(cmd, "--fixed-strings") --- or "-F"
    end

    if string.find(pattern, "\n", 1, true) ~= nil then
        table.insert(cmd, "--multiline") --- or "-U"
    end

    table.insert(cmd, "--")
    table.insert(cmd, pattern)
    vim.list_extend(cmd, locations)

    return cmd
end

--- @type QfRancherGrepPartsFunc
local function get_full_parts_grep(pattern, input_type, locations)
    local cmd = vim.deepcopy(base_parts.grep) --- @type string[]

    if input_type == "regex" then
        table.insert(cmd, "--extended-regexp") --- or "-E"
    else
        table.insert(cmd, "--fixed-strings") --- or "-F"
    end

    --- @type boolean
    local smartcase = input_type == "smartcase" and string.lower(pattern) == pattern
    if smartcase or input_type == "insensitive" then
        table.insert(cmd, "--ignore-case") --- or "-i"
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
} --- @type table<string, function>

--- @param pattern string
--- @param input_type string
--- @param locations string[]
--- @return string[]
local function get_grep_parts(pattern, input_type, locations)
    vim.validate("pattern", pattern, "string")
    vim.validate("input_type", input_type, "string")
    require("mjm.error-list-types")._validate_list(locations, { type = "string" })

    --- @type string
    local grep_cmd = require("mjm.error-list-util")._get_g_var("qf_rancher_grepprg")
    if vim.fn.executable(grep_cmd) ~= 1 then
        local chunk = { grep_cmd .. " is not executable", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return {}
    end

    return get_full_parts[grep_cmd](pattern, input_type, locations)
end

--------------------------
--- Main Grep Function ---
--------------------------

--- @param grep_info QfRancherGrepInfo
--- @param input_type QfRancherInputType
--- @return string
local function get_prompt(grep_info, input_type)
    local ey = require("mjm.error-list-types")
    ey._validate_grep_info(grep_info)
    ey._validate_input_type(input_type)

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local display_type = eu._get_display_input_type(input_type) --- @type string
    local grepprg = eu._get_g_var("qf_rancher_grepprg") --- @type string

    -- LOW: This could be better
    return "[" .. grepprg .. "] " .. grep_info.name .. " Grep (" .. display_type .. "): "
end

--- @param grep_info QfRancherGrepInfo
--- @param system_opts QfRancherSystemOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
local function validate_do_grep_inputs(grep_info, system_opts, input_opts, what)
    grep_info = grep_info or {}
    system_opts = system_opts or {}
    input_opts = input_opts or {}
    what = what or {}

    local ey = require("mjm.error-list-types")
    ey._validate_grep_info(grep_info)
    ey._validate_system_opts(system_opts)
    ey._validate_input_opts(input_opts)
    ey._validate_what(what)
end

--- @param grep_info QfRancherGrepInfo
--- @param system_opts QfRancherSystemOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
function M._do_grep(grep_info, system_opts, input_opts, what)
    validate_do_grep_inputs(grep_info, system_opts, input_opts, what)

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if what.user_data.src_win and not eu._win_can_have_loclist(what.user_data.src_win) then
        local msg = "Win " .. what.user_data.src_win .. " cannot have a location list"
        vim.api.nvim_echo({ { msg, "" } }, false, {})
        return
    end

    local locations = grep_info.location_func() --- @type string[]
    if #locations < 1 then
        return
    end

    local input_type = eu._resolve_input_type(input_opts.input_type) --- @type QfRancherInputType
    local prompt = get_prompt(grep_info, input_type) --- @type string
    --- @type string|nil
    local pattern = eu._resolve_pattern(prompt, input_opts.pattern, input_type)
    if not pattern then
        return
    end

    local full_system_opts = vim.deepcopy(system_opts, true) --- @type QfRancherSystemOpts
    full_system_opts.cmd_parts = get_grep_parts(pattern, input_type, locations)
    if #full_system_opts.cmd_parts < 1 then
        return
    end

    local what_set = vim.deepcopy(what, true) --- @type QfRancherWhat
    local grepprg = eu._get_g_var("qf_rancher_grepprg") --- @type string
    local title_parts = base_parts[grepprg] --- @type string[]
    what_set.title = table.concat(title_parts, " ")
    what_set.user_data.list_item_type = grep_info.list_item_type
        or what_set.user_data.list_item_type

    require("mjm.error-list-system").system_do(full_system_opts, what_set)
end

------------------
--- API Pieces ---
------------------

--- @return string[]
local function get_cwd()
    return { vim.fn.getcwd() }
end

--- @return string[]|nil
local function get_help_dirs()
    local doc_files = vim.api.nvim_get_runtime_file("doc/*.txt", true) --- @type string[]
    if #doc_files == 0 then
        vim.api.nvim_echo({ { "No doc files found", "ErrorMsg" } }, true, { err = true })
    end

    return doc_files
end

--- @return string[]|nil
local function get_buflist()
    local bufnrs = vim.api.nvim_list_bufs() --- @type integer[]
    local fnames = {} --- @type string[]

    for _, buf in pairs(bufnrs) do
        --- @type boolean
        local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf })
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
        local fname = vim.api.nvim_buf_get_name(buf) --- @type string
        local readable = vim.uv.fs_access(fname, 4) --- @type boolean|nil

        if buflisted and buftype == "" and readable then
            table.insert(fnames, fname)
        end
    end

    if #fnames == 0 then
        vim.api.nvim_echo({ { "No valid bufs found", "" } }, false, {})
    end

    return fnames
end

--- @return string[]|nil
local function get_cur_buf()
    local buf = vim.api.nvim_get_current_buf() --- @type integer

    if not vim.api.nvim_get_option_value("buflisted", { buf = buf }) then
        vim.api.nvim_echo({ { "Cur buf is not listed", "" } }, false, {})
        return {}
    end

    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
    if not (buftype == "" or buftype == "help") then
        vim.api.nvim_echo({ { "Buftype " .. buftype .. " is not valid", "" } }, false, {})
        return {}
    end

    local fname = vim.api.nvim_buf_get_name(buf) --- @type string
    local fs_access = vim.uv.fs_access(fname, 4) --- @type boolean|nil
    if fname ~= "" and fs_access == true then
        return { fname }
    else
        vim.api.nvim_echo({ { "Current buffer is not a valid file", "" } }, false, {})
        return {}
    end
end

local greps = {
    cwd = { name = "CWD", list_item_type = nil, location_func = get_cwd },
    --- DOCUMENT: This will overwrite arbitrary data passed from the caller
    help = { name = "Help", list_item_type = "\1", location_func = get_help_dirs },
    bufs = { name = "Buf", list_item_type = nil, location_func = get_buflist },
    cbuf = { name = "Cur Buf", list_item_type = nil, location_func = get_cur_buf },
} --- @type QfRancherGrepInfo[]

--- @return string[]
function M.get_grep_names()
    return vim.tbl_keys(greps)
end

--- DOCUMENT: This. necessary to run your grep

--- @param name string
--- @param system_opts QfRancherSystemOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
function M.grep(name, system_opts, input_opts, what)
    local grep_info = greps[name] --- @type QfRancherGrepInfo|nil
    if grep_info then
        M._do_grep(grep_info, system_opts, input_opts, what)
    else
        local chunk = { "Grep " .. name .. " is not registered", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
    end
end

--- DOCUMENT: How this works
--- @param grep_info QfRancherGrepInfo
--- @return nil
function M.register_grep(grep_info)
    require("mjm.error-list-types")._validate_grep_info(grep_info)
    greps.grep_info.name = grep_info
end

--- DOCUMENT: How this works
--- @param name string
--- @return nil
function M.clear_grep(name)
    vim.validate("name", name, "string")
    if #vim.tbl_keys(greps) <= 1 then
        vim.api.nvim_echo({ { "Cannot remove the last grep method" } }, false, {})
        return
    end

    if greps[name] then
        greps[name] = nil
        vim.api.nvim_echo({ { name .. " removed from grep list", "" } }, true, {})
    else
        vim.api.nvim_echo({ { name .. " is not a registered grep", "" } }, true, {})
    end
end

--- @param src_win? integer
--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
local function grep_cmd(src_win, cargs)
    cargs = cargs or {}
    local fargs = cargs.fargs --- @type string[]

    local grep_names = M.get_grep_names() --- @type string[]
    assert(#grep_names > 1, "No grep commands available")
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    local grep_name = eu._check_cmd_arg(fargs, grep_names, "cwd") --- @type string

    local ey = require("mjm.error-list-types") --- @type QfRancherTypes
    --- @type "sync"|"async"
    local sync_str = eu._check_cmd_arg(fargs, ey._sync_opts, ey._default_sync_opt)
    local sync = sync_str == "sync" and true or false --- @type boolean
    --- MID: Should be able to set the timeout from the cmd
    --- @type QfRancherSystemOpts
    local system_opts = { sync = sync, timeout = ey._default_timeout }

    --- @type QfRancherInputType
    local input_type = eu._check_cmd_arg(fargs, ey._cmd_input_types, ey._default_input_type)
    local pattern = eu._find_cmd_pattern(fargs) --- @type string|nil
    local input_opts = { input_type = input_type, pattern = pattern } --- @type QfRancherInputOpts

    --- @type QfRancherAction
    local action = eu._check_cmd_arg(fargs, ey._actions, ey._default_action)
    --- @type QfRancherWhat
    local what = { nr = cargs.count, user_data = { action = action, src_win = src_win } }

    M.grep(grep_name, system_opts, input_opts, what)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._q_grep_cmd(cargs)
    grep_cmd(nil, cargs)
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
function M._l_grep_cmd(cargs)
    grep_cmd(vim.api.nvim_get_current_win(), cargs)
end

return M

--------------
--- # TODO ---
--------------

--- This still does not properly resize the list window
--- Add tests
--- Docs

-------------
--- # MID ---
-------------

--- Grep specific file. Can either be a built-in or shown as a recipe
--- Partly a grep, partly a filter, but grep based on treesitter node name. e.g. I should be
---     able to grep all parameters
--- Mid: Each grepprg should be a module, and there should be a defined set of functions
---     that each grepprg should have. Essentially, defining an interface and then having
---     modules that fulfill it. I don't know if you use a literal interface module, but that's
---     the conceptual idea

-------------
--- # LOW ---
-------------

--- Support ack
--- Use globbing for locations instead of passing potentially triple digit amounts of arguments
--- Look at vim-grepper to see how it supports certain grepprgs
--- Cache the executable status of the grepprg. Issues:
--- - relative to how little time this check takes to run, a lot of state to keep track of
--- - how do you trigger re-checks?
--- - If you have a good status, under what circumstances might it fail? How do you check it for
---     a bad status?
--- Support changes to the grepprg itself, like turning off recursive grepping, or specifying the
---     grepprg in a command or map

-----------------------
--- # DOCUMENTATION ---
-----------------------

--- Only rg and grep are currently supported
--- - I am not in Windows so I cannot test findstr
--- - I am open to PRs on this
--- It is intended behavior that cbuf grep can work on help files, but all bufs will not pull from
---     help files

-- Escaping test line from From vim-grepper
-- ..ad\\f40+$':-# @=,!;%^&&*()_{}/ /4304\'""?`9$343%$ ^adfadf[ad)[(

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
        -- TODO: Revisit if this is necessary
        -- if input_type ~= "regex" then
        --     pattern = string.gsub(pattern, "\n", "\\n")
        -- end
    end

    table.insert(cmd, "--")
    table.insert(cmd, pattern)
    vim.list_extend(cmd, locations)

    return cmd
end

--- @type QfRancherGrepPartsFunc
local function get_full_parts_grep(pattern, input_type, locations)
    local cmd = base_parts.grep --- @type string[]

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
    -- No multiline mode in vanilla grep, so fall back to an or comparison
    pattern = string.gsub(pattern, "\n", "|")
    table.insert(cmd, pattern)
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
    if vim.g.qf_rancher_debug_assertions then
        vim.validate("pattern", pattern, "string")
        vim.validate("input_type", input_type, "string")
        require("mjm.error-list-util")._is_valid_str_list(locations)
    end

    local grep_cmd = vim.g.qf_rancher_grepprg
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
local function get_prompt(grep_info, input_type)
    if vim.g.qf_rancher_debug_assertions then
        local ey = require("mjm.error-list-types")
        ey._validate_grep_info(grep_info)
        ey._validate_input_type(input_type)
    end

    local display_type = require("mjm.error-list-util")._get_display_input_type(input_type)
    local grepprg = vim.g.qf_rancher_grepprg or ""

    -- LOW: This could be better
    return "[" .. grepprg .. "] " .. grep_info.name .. " Grep (" .. display_type .. "): "
end

--- @param grep_info QfRancherGrepInfo
--- @param system_opts QfRancherSystemOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
local function validate_do_grep_inputs(grep_info, system_opts, input_opts, what)
    local ey = require("mjm.error-list-types")
    ey._validate_grep_info(grep_info)
    ey._validate_system_opts(system_opts)
    ey._validate_input_opts(input_opts)
    ey._validate_what_strict(what)
end

--- @param grep_info QfRancherGrepInfo
--- @param system_opts QfRancherSystemOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
function M._do_grep(grep_info, system_opts, input_opts, what)
    grep_info = grep_info or {}
    system_opts = system_opts or {}
    input_opts = input_opts or {}
    what = what or {}
    validate_do_grep_inputs(grep_info, system_opts, input_opts, what)

    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if what.user_data.list_win and not eu._win_can_have_loclist(what.user_data.list_win) then
        return
    end

    local locations = grep_info.location_func() --- @type string[]
    if #locations < 1 then
        return
    end

    local input_type = eu._resolve_input_type(input_opts.input_type) --- @type QfRancherInputType
    local prompt = get_prompt(grep_info, input_type)
    --- @type string|nil
    local pattern = eu._resolve_pattern(prompt, input_opts.pattern, input_type)
    if not pattern then
        return
    end

    local grep_parts = get_grep_parts(pattern, input_type, locations) --- @type string[]
    if #grep_parts < 1 then
        return
    end

    local full_system_opts = vim.deepcopy(system_opts, true)
    full_system_opts.cmd_parts = grep_parts
    -- vim.fn.confirm(vim.inspect(grep_parts))

    local what_set = vim.deepcopy(what, true)
    local title_parts = base_parts[vim.g.qf_rancher_grepprg]
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
        vim.api.nvim_echo({ { "No valid bufs found", "ErrorMsg" } }, true, { err = true })
    end

    return fnames
end

--- @return string[]|nil
local function get_cur_buf()
    local buf = vim.api.nvim_get_current_buf() --- @type integer

    local buflisted = vim.api.nvim_get_option_value("buflisted", { buf = buf }) --- @type boolean
    if not buflisted then
        vim.api.nvim_echo({ { "Cur buf is not listed", "ErrorMsg" } }, true, { err = true })
        return {}
    end

    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
    local good_buftype = buftype == "" or buftype == "help" --- @type boolean
    if not good_buftype then
        local chunk = { "Buftype " .. buftype .. " is not valid", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return {}
    end

    local fname = vim.api.nvim_buf_get_name(buf) --- @type string
    local fs_access = vim.uv.fs_access(fname, 4) --- @type boolean|nil
    local good_file = fname ~= "" and fs_access == true --- @type boolean
    if good_file then
        return { fname }
    else
        --- @type [string,string]
        local chunk = { "Current buffer is not a valid file", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
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

--- @param name string
--- @param system_opts QfRancherSystemOpts
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
function M.grep(name, system_opts, input_opts, what)
    local grep_info = greps[name]
    if grep_info then
        M._do_grep(grep_info, system_opts, input_opts, what)
    end
end

--- TODO: Make the rest of the API

return M

--------------
--- # TODO ---
--------------

--- Global checklist:
--- - Check that all functions have reasonable default sorts
--- - Check that window height updates are triggered where appropriate
--- - Check that functions have proper visibility
--- - Check that all mappings have plugs and cmds
--- - Check that all maps/cmds/plugs have desc fieldss
--- - Check that all functions have annotations and documentation
--- - Check that loclist functions are appropriate (ex: all bufs vs. cbuf)

-------------
--- # MID ---
-------------

--- Grep specific file. Can either be a built-in or shown as a recipe
--- Add the ability to create and register grep sources

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

-----------------------
--- # DOCUMENTATION ---
-----------------------

--- Only rg and grep are currently supported
--- - I am not in Windows so I cannot test findstr
--- - I am open to PRs on this
--- It is intended behavior that cbuf grep can work on help files, but all bufs will not pull from
---     help files

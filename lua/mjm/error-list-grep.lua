-- Escaping test line from From vim-grepper
-- ..ad\\f40+$':-# @=,!;%^&&*()_{}/ /4304\'""?`9$343%$ ^adfadf[ad)[(

local M = {}

-------------
--- Types ---
-------------

--- @alias QfRancherGrepLocFunc fun():string[]
---
--- @alias QfRancherGrepLocs string[]
--- @alias QfRancherGrepPartsFunc fun(string, string, QfRancherGrepLocs):string[]

--- @class QfRancherGrepInfo
--- @field name string
--- @field list_item_type string|nil
--- @field location_func function

--------------------------
--- Grepprg/Grep Parts ---
--------------------------

--- @param locations string[]
local function validate_locations(locations)
    vim.validate("locations", locations, "table")
    if #locations < 1 then
        return false
    end

    for _, location in ipairs(locations) do
        if type(location) ~= "string" then
            return false
        end
    end

    return true
end

--- @return string[]
local function get_base_parts_rg()
    return { "rg", "--vimgrep", "-uu" }
end

local function get_base_parts_grep()
    -- Or, -rHn --binary-files=without-match
    return { "grep", "--recursive", "--with-filename", "--line-number", "-I" }
end

--- @type QfRancherGrepPartsFunc
--- The pattern param, unlike the field in input opts, is post-prompting/visual mode checking
local function get_full_parts_rg(pattern, input_type, locations)
    vim.validate("pattern", pattern, "string")
    vim.validate("input_type", input_type, "string")
    vim.validate("locations", locations, function()
        return validate_locations(locations)
    end)

    local cmd = get_base_parts_rg()
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
--- The pattern param, unlike the field in input opts, is post-prompting/visual mode checking
local function get_full_parts_grep(pattern, input_type, locations)
    vim.validate("pattern", pattern, "string")
    vim.validate("input_type", input_type, "string")
    vim.validate("locations", locations, function()
        return validate_locations(locations)
    end)

    local cmd = get_base_parts_grep() --- @type string[]

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

local get_base_parts = {
    grep = get_base_parts_grep,
    rg = get_base_parts_rg,
}

local get_full_parts = {
    grep = get_full_parts_grep,
    rg = get_full_parts_rg,
}

--- @class QfRancherGetGrepPartsOpts
--- @field base_only? boolean
--- @field pattern? string
--- @field input_type? QfRancherInputType
--- @field locations? string[]

--- @param opts? QfRancherGetGrepPartsOpts
--- @return string[]
local function get_grep_parts(opts)
    opts = opts or {}
    vim.validate("opts", opts, "table")
    vim.validate("opts.base_only", opts.base_only, { "boolean", "nil" })
    vim.validate("opts.pattern", opts.pattern, { "nil", "string" })
    vim.validate("opts.input_type", opts.input_type, { "nil", "string" })
    vim.validate("opts.locations", opts.locations, { "nil", "table" })

    -- Set to rg by default
    local grep_cmd = vim.g.qf_rancher_grepprg
    if opts.base_only then
        return get_base_parts[grep_cmd]()
    end

    if vim.fn.executable(grep_cmd) ~= 1 then
        local chunk = { grep_cmd .. " is not executable", "ErrorMsg" }
        vim.api.nvim_echo({ chunk }, true, { err = true })
        return {}
    end

    return get_full_parts[grep_cmd](opts.pattern, opts.input_type, opts.locations)
end

--------------------------
--- Main Grep Function ---
--------------------------

--- @param grep_info QfRancherGrepInfo
--- @param input_type QfRancherInputType
local function get_prompt(grep_info, input_type)
    local eu = require("mjm.error-list-util")

    vim.validate("grep_info", grep_info, "table")
    vim.validate("grep_info.name", grep_info.name, "string")
    vim.validate("input_type", input_type, function()
        return eu.validate_input_type(input_type)
    end)

    local display_type = eu._get_display_input_type(input_type)
    local grepprg = vim.g.qf_rancher_grepprg or ""

    -- TODO: actually look at this and adjust
    return "[" .. grepprg .. "] " .. grep_info.name .. " Grep (" .. display_type .. "): "
end

--- @param grep_info QfRancherGrepInfo
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
local function clean_do_grep_input(grep_info, system_opts, input_opts, what)
    vim.validate("grep_info", grep_info, "table")
    vim.validate("grep_info.location_func", grep_info.location_func, "callable")

    vim.validate("system_opts", system_opts, function()
        return require("mjm.error-list-system").validate_system_opts(system_opts)
    end)

    require("mjm.error-list-types")._validate_input_opts(input_opts)
    require("mjm.error-list-types")._validate_what_strict(what)
end

--- @param grep_info QfRancherGrepInfo
--- @param input_opts QfRancherInputOpts
--- @param what QfRancherWhat
--- @return nil
function M._do_grep(grep_info, system_opts, input_opts, what)
    clean_do_grep_input(grep_info, system_opts, input_opts, what)
    local eu = require("mjm.error-list-util") --- @type QfRancherUtils
    if not eu._win_can_have_loclist(what.user_data.list_win) then
        return
    end

    local locations = grep_info.location_func() --- @type string[]
    if #locations < 1 then
        return
    end

    local input_type = eu._resolve_input_type(input_opts.input_type) --- @type QfRancherInputType
    local prompt = get_prompt(grep_info, input_type)
    local pattern = eu._resolve_pattern(prompt, input_opts) --- @type string|nil
    if not pattern then
        return
    end

    local grep_parts_opts = { pattern = pattern, input_type = input_type, locations = locations }
    local grep_parts = get_grep_parts(grep_parts_opts) --- @type string[]
    if #grep_parts < 1 then
        return
    end

    system_opts.cmd_parts = grep_parts
    local title_parts = get_grep_parts({ base_only = true })
    what.title = table.concat(title_parts, " ")
    -- TODO: A bit of an oddity because it can also be set in what. So in a sense we're
    -- creating a mandatory overwrite. ANtipattern
    what.user_data.list_item_type = grep_info.list_item_type

    require("mjm.error-list-system").system_do(system_opts, what)
end

------------------
--- API Pieces ---
------------------

--- @type QfRancherGrepLocFunc
local function get_cwd()
    return { vim.fn.getcwd() }
end

--- @type QfRancherGrepLocFunc
local function get_help_dirs()
    local doc_files = vim.api.nvim_get_runtime_file("doc/*.txt", true) --- @type string[]
    if #doc_files == 0 then
        vim.api.nvim_echo({ { "No doc files found", "ErrorMsg" } }, true, { err = true })
    end

    return doc_files
end

--- @type QfRancherGrepLocFunc
local function get_buflist()
    local bufnrs = vim.api.nvim_list_bufs() --- @type integer[]
    local fnames = {} --- @type string[]

    for _, buf in pairs(bufnrs) do
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
        vim.api.nvim_echo({ { "No valid bufs found", "ErrorMsg" } }, true, { err = true })
    end

    return fnames
end

--- @type QfRancherGrepLocFunc
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
    if not grep_info then
        return
    end

    M._do_grep(grep_info, system_opts, input_opts, what)
end

--- TODO: Make the rest of the API

return M

----------------

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
---
--- - It should be possible to setup and register your own grep sources. This would be helpful
--- for people who want to use more niche programs, and it would make it easier for users to test
--- and then send in PRs for programs like findstr and ack that I would like to support but
--- don't really mean a means to. Note here that it's actually important then that the source
--- to use is controlled from the g-var, because it keeps the logic dis-entangled from which
--- source you're grepping from

-------------
--- # MID ---
-------------

--- Support ack. I think it's on Linux. Given that vim-ack is a kind of anscestor of the mappings
---     in the ftplugin, it feels disrespectful not to include it
--- Grep specific file. Can either be a built-in or shown as a recipe

-------------
--- # LOW ---
-------------

--- Filesystem grep
--- Use globbing for locations instead of passing potentially triple digit amounts of arguments
--- Could look at vim-grepper to see how it supports certain grepprgs
--- Cache the executable status of the grepprg. Issues:
--- - relative to how little time this check takes to run, a lot of state to keep track of
--- - how do you trigger re-checks?
--- - If you have a good status, under what circumstances might it fail? How do you check it to
---     a bad status

-----------------------
--- # DOCUMENTATION ---
-----------------------

--- Only rg and grep are currently supported
--- - I am not in Windows so I cannot test findstr
--- - Ack should be on the roadmap
--- - I am open to PRs on this
--- It is intended behavior that cbuf grep can work on help files, but all bufs will not pull from
---     help files

local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

local api = vim.api
local fn = vim.fn

local function close_floats()
    for _, win in pairs(fn.getwininfo()) do
        local id = win.winid
        local config = api.nvim_win_get_config(id)
        if config.relative and config.relative ~= "" then api.nvim_win_close(id, false) end
    end
end

api.nvim_create_user_command("CloseFloats", close_floats, {})

api.nvim_create_user_command("Parse", function(cargs)
    print(vim.inspect(api.nvim_parse_cmd(cargs.args, {})))
end, { nargs = "+" })

local function tab_kill()
    local confirm = fn.confirm(
        "This will delete all buffers in the current tab. Unsaved changes will be lost. Proceed?",
        "&Yes\n&No",
        2
    )

    if confirm ~= 1 then return end

    local buffers = fn.tabpagebuflist(fn.tabpagenr())
    for _, buf in pairs(buffers) do
        if api.nvim_buf_is_valid(buf) then api.nvim_buf_delete(buf, { force = true }) end
    end
end

api.nvim_create_user_command("TabKill", tab_kill, {})

api.nvim_create_user_command("Termcode", function(cargs)
    local replaced = api.nvim_replace_termcodes(cargs.args, true, true, true)
    print(vim.inspect(replaced))
end, { nargs = "+" })

--------------
-- Buf Cmds --
--------------

--- @param path string
--- @return boolean
local function is_git_tracked(path)
    if not vim.g.gitsigns_head then return false end

    local cmd = { "git", "ls-files", "--error-unmatch", "--", path }
    local output = vim.system(cmd):wait()

    return output.code == 0
end

--- @return integer|nil, string|nil
local function get_cur_buf()
    local buf = api.nvim_get_current_buf()
    if not api.nvim_buf_is_valid(buf) then
        api.nvim_echo({ { "Invalid buf", "WarningMsg" } }, true, { err = true })
        return nil, nil
    end

    local bufname = api.nvim_buf_get_name(buf)
    if bufname == "" then
        api.nvim_echo({ { "No bufname", "" } }, true, { err = true })
        return nil, nil
    end

    return buf, bufname
end

local function del_cur_buf_from_disk(cargs)
    local buf, bufname = get_cur_buf()
    if (not buf) or not bufname then return end

    if not cargs.bang then
        if api.nvim_get_option_value("modified", { buf = buf }) then
            api.nvim_echo({ { "Buf is modified", "" } }, false, {})
            return
        end
    end

    local full_bufname = fn.fnamemodify(bufname, ":p")
    local is_tracked = is_git_tracked(full_bufname)

    if is_tracked then
        -- # Fugitive
        local gdelete = { cmd = "GDelete", bang = true }
        local ok, err = pcall(api.nvim_cmd, gdelete, {})
        if not ok then
            local msg = err or "Unknown error performing GDelete"
            api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        end
    else
        if fn.delete(full_bufname) ~= 0 then
            local msg = "Failed to delete file from disk"
            api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        end

        api.nvim_buf_delete(buf, { force = true })
    end

    ut.harpoon_rm_buf({ bufname = full_bufname })
end

local function do_mkdir(path)
    local mkdir = vim.system({ "mkdir", "-p", path }):wait()
    if mkdir.code == 0 then return true end

    local err = mkdir.stderr or ("Cannot open " .. path)
    api.nvim_echo({ { err, "ErrorMsg" } }, true, { err = true })
    return false
end

-- MID: Use vim.fs.normalize?

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
local function mv_cur_buf(cargs)
    local arg = cargs.fargs[1] or ""
    if arg == "" then
        api.nvim_echo({ { "No argument", "" } }, false, {})
        return
    end

    local buf, bufname = get_cur_buf()
    if (not buf) or not bufname then return end

    if (not cargs.bang) and api.nvim_get_option_value("modified", { buf = buf }) then
        api.nvim_echo({ { "Buf is modified", "" } }, false, {})
        return
    end

    local target = (function()
        if arg:match("[/\\]$") or fn.isdirectory(arg) == 1 then
            local dir = arg:gsub("[/\\]+$", "")
            return dir .. "/" .. fn.fnamemodify(bufname, ":t")
        elseif fn.fnamemodify(arg, ":h") == "." then
            return fn.fnamemodify(bufname, ":h") .. "/" .. arg
        else
            return arg
        end
    end)()

    local full_target = fn.fnamemodify(target, ":p")
    local escape_target = fn.fnameescape(full_target)
    local full_bufname = fn.fnamemodify(bufname, ":p")
    local escape_bufname = fn.fnameescape(full_bufname)
    if escape_target == escape_bufname then return end

    do_mkdir(fn.fnamemodify(escape_target, ":h"))
    local is_tracked = is_git_tracked(escape_bufname)
    if is_tracked then
        -- # Fugitive
        local gmove = { cmd = "GMove", args = { escape_target } }
        local ok, err = pcall(api.nvim_cmd, gmove, {})
        if not ok then
            local err_msg = err or "Unknown error performing GMove"
            api.nvim_echo({ { err_msg, "ErrorMsg" } }, true, { err = true })
            return
        end
    else
        if fn.rename(escape_bufname, escape_target) ~= 0 then
            local err_chunk = { "Failed to rename file on disk", "ErrorMsg" }
            api.nvim_echo({ err_chunk }, true, { err = true })
            return
        end

        local args = { escape_target }
        local mods = { keepalt = true }
        api.nvim_cmd({ cmd = "saveas", args = args, bang = true, mods = mods }, {})
    end

    for _, b in pairs(api.nvim_list_bufs()) do
        if api.nvim_buf_get_name(b) == bufname then api.nvim_buf_delete(b, { force = true }) end
    end

    ut.harpoon_mv_buf(escape_bufname, escape_target)
end

local cmd_augroup_name = "mjm-buf-cmds"
Autocmd({ "BufNew", "BufReadPre" }, {
    group = Augroup(cmd_augroup_name, {}),
    once = true,
    callback = function()
        api.nvim_create_user_command("BKill", function(cargs)
            del_cur_buf_from_disk(cargs)
        end, { bang = true })

        api.nvim_create_user_command("BMove", function(cargs)
            mv_cur_buf(cargs)
        end, { bang = true, nargs = 1, complete = "file_in_path" })

        -- Quick refresh if Treesitter bugs out
        api.nvim_create_user_command("We", "silent up | e", {})

        api.nvim_del_augroup_by_name(cmd_augroup_name)
    end,
})

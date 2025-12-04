local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

local api = vim.api
local fn = vim.fn

api.nvim_create_user_command("Parse", function(cargs)
    print(vim.inspect(api.nvim_parse_cmd(cargs.args, {})))
end, { nargs = "+" })

local function tab_kill()
    local confirm = fn.confirm(
        "This will delete all buffers in the current tab. Unsaved changes will be lost. Proceed?",
        "&Yes\n&No",
        2
    )

    if confirm ~= 1 then
        return
    end

    local buffers = fn.tabpagebuflist(fn.tabpagenr())
    for _, buf in pairs(buffers) do
        if api.nvim_buf_is_valid(buf) then
            api.nvim_buf_delete(buf, { force = true })
        end
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

---@param path string
---@return boolean
local function is_git_tracked(path)
    if not vim.g.gitsigns_head then
        return false
    end

    local cmd = { "git", "ls-files", "--error-unmatch", "--", path }
    local output = vim.system(cmd):wait()

    return output.code == 0
end

---@return integer|nil, string|nil
local function del_cur_buf_from_disk(cargs)
    local buf = api.nvim_get_current_buf() ---@type integer
    local bufname = api.nvim_buf_get_name(buf) ---@type string
    if api.nvim_get_option_value("buftype", { buf = buf }) ~= "" then
        return
    end
    if bufname == "" then
        if cargs.bang then
            api.nvim_cmd({ cmd = "bwipeout", bang = true }, {})
        end
        return
    end

    if (not cargs.bang) and api.nvim_get_option_value("modified", { buf = buf }) then
        api.nvim_echo({ { "Buf is modified", "" } }, false, {})
        return
    end

    if is_git_tracked(bufname) then
        local ok, err = pcall(api.nvim_cmd, { cmd = "GDelete", bang = true }, {})
        if not ok then
            local msg = err or "Unknown error performing GDelete"
            api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        end
    else
        local ok, err = vim.uv.fs_unlink(bufname) ---@type boolean|nil, string|nil
        if not ok then
            local msg = err or "Failed to delete file from disk" ---@type string
            api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        end

        ut.pbuf_rm(buf, true, true, true, false)
    end

    ut.harpoon_rm_buf({ bufname = bufname })
end

---@param cargs vim.api.keyset.create_user_command.command_args
---@return nil
local function mv_cur_buf(cargs)
    local arg = cargs.fargs[1] or ""
    if arg == "" then
        api.nvim_echo({ { "No argument", "" } }, false, {})
        return
    end

    local buf = api.nvim_get_current_buf() ---@type integer
    local bufname = api.nvim_buf_get_name(buf) ---@type string
    if bufname == "" then
        return
    end
    if api.nvim_get_option_value("buftype", { buf = buf }) ~= "" then
        return
    end
    if (not buf) or not bufname then
        return
    end

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
    local escape_bufname = fn.fnameescape(bufname)
    if escape_target == escape_bufname then
        return
    end

    ut.checked_mkdir_p(fn.fnamemodify(escape_target, ":h"), tonumber("755", 8))
    if is_git_tracked(escape_bufname) then
        local ok, err = pcall(api.nvim_cmd, { cmd = "GMove", args = { escape_target } }, {})
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
        if api.nvim_buf_get_name(b) == bufname then
            api.nvim_buf_delete(b, { force = true })
        end
    end

    ut.harpoon_mv_buf(escape_bufname, escape_target)
end

api.nvim_create_user_command("BKill", function(cargs)
    del_cur_buf_from_disk(cargs)
end, { bang = true })

api.nvim_create_user_command("BMove", function(cargs)
    mv_cur_buf(cargs)
end, { bang = true, nargs = 1, complete = "file_in_path" })

-- Quick refresh if Treesitter bugs out
api.nvim_create_user_command("We", "silent up | e", {})

---@param args string
local function scratch_cmd(args)
    local output = vim.fn.execute(args) ---@type string

    api.nvim_cmd({ cmd = "tabnew" }, {})
    local buf = vim.api.nvim_get_current_buf() ---@type integer
    if not mjm.util.is_buf_empty_noname(buf) then
        api.nvim_cmd({ cmd = "enew" }, {})
    end

    -- MID: This also feels like something that can be broken out
    api.nvim_set_option_value("bh", "wipe", { buf = buf })
    api.nvim_set_option_value("bl", false, { buf = buf })
    api.nvim_set_option_value("bt", "nofile", { buf = buf })
    api.nvim_set_option_value("swf", false, { buf = buf })
    api.nvim_set_option_value("udf", false, { buf = buf })

    local lines_tbl = vim.split(output, "\n") ---@type string[]
    api.nvim_buf_set_lines(buf, 0, -1, false, lines_tbl)
    api.nvim_set_option_value("ma", false, { buf = buf })
end

vim.api.nvim_create_user_command("ScratchCmd", function(opts)
    scratch_cmd(opts.args)
end, { nargs = "+" })

-- LOW: Redo the Abolish subvert cmd with the preview handler
-- Does this plugin already exist?

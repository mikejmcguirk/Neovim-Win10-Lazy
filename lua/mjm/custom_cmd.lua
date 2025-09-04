-- LOW: Create pandoc exports for current buf

--- @param path string
--- @return boolean
--- LOW: vim.system enter errors if it can't run the command. Since vim.pack uses git, shouldn't
--- have a scenario where this config is loaded without Git. But bad in principle
--- Mitigated by checking for a head, but now we have a dependency
local function is_git_tracked(path)
    if not vim.g.gitsigns_head then
        return false
    end

    local cmd = { "git", "ls-files", "--error-unmatch", "--", path }
    local output = vim.system(cmd):wait()

    return output.code == 0
end

--- @return integer|nil, string|nil
local function get_cur_buf()
    local buf = vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_echo({ { "Invalid buf", "WarningMsg" } }, true, { err = true })
        return nil, nil
    end

    local bufname = vim.api.nvim_buf_get_name(buf)
    if bufname == "" then
        vim.api.nvim_echo({ { "No bufname", "" } }, true, { err = true })
        return nil, nil
    end

    return buf, bufname
end

local function del_cur_buf_from_disk(cargs)
    local buf, bufname = get_cur_buf()
    if (not buf) or not bufname then
        return
    end

    if not cargs.bang then
        if vim.api.nvim_get_option_value("modified", { buf = buf }) then
            vim.api.nvim_echo({ { "Buf is modified", "" } }, false, {})
            return
        end
    end

    local full_bufname = vim.fn.fnamemodify(bufname, ":p")
    local is_tracked = is_git_tracked(full_bufname)

    if is_tracked then
        -- LOW: You don't need Fugitive for this
        -- # Fugitive
        local gdelete = { cmd = "GDelete", bang = true }
        local ok, err = pcall(vim.api.nvim_cmd, gdelete, {})
        if not ok then
            local msg = err or "Unknown error performing GDelete"
            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        end
    else
        if vim.fn.delete(full_bufname) ~= 0 then
            local msg = "Failed to delete file from disk"
            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        end

        vim.api.nvim_buf_delete(buf, { force = true })
    end

    require("mjm.utils").harpoon_rm_buf({ bufname = full_bufname })
end

vim.api.nvim_create_user_command("BKill", del_cur_buf_from_disk, {})

local function do_mkdir(path)
    local mkdir = vim.system({ "mkdir", "-p", path }):wait()
    if mkdir.code == 0 then
        return true
    end

    local err = mkdir.stderr or ("Cannot open " .. path)
    vim.api.nvim_echo({ { err, "ErrorMsg" } }, true, { err = true })
    return false
end

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
local function mv_cur_buf(cargs)
    local arg = cargs.fargs[1] or ""
    if arg == "" then
        vim.api.nvim_echo({ { "No argument", "" } }, false, {})
        return
    end

    local buf, bufname = get_cur_buf()
    if (not buf) or not bufname then
        return
    end

    if not cargs.bang then
        if vim.api.nvim_get_option_value("modified", { buf = buf }) then
            vim.api.nvim_echo({ { "Buf is modified", "" } }, false, {})
            return
        end
    end

    local target = (function()
        if arg:match("[/\\]$") or vim.fn.isdirectory(arg) == 1 then
            local dir = arg:gsub("[/\\]+$", "")
            return dir .. "/" .. vim.fn.fnamemodify(bufname, ":t")
        elseif vim.fn.fnamemodify(arg, ":h") == "." then
            return vim.fn.fnamemodify(bufname, ":h") .. "/" .. arg
        else
            return arg
        end
    end)()

    local full_target = vim.fn.fnamemodify(target, ":p")
    local escape_target = vim.fn.fnameescape(full_target)
    local full_bufname = vim.fn.fnamemodify(bufname, ":p")
    local escape_bufname = vim.fn.fnameescape(full_bufname)
    if escape_target == escape_bufname then
        return
    end

    do_mkdir(vim.fn.fnamemodify(escape_target, ":h"))
    local is_tracked = is_git_tracked(escape_bufname)
    if is_tracked then
        -- LOW: Don't need Fugitive for this
        -- # Fugitive
        local gmove = { cmd = "GMove", args = { escape_target } }
        local ok, err = pcall(vim.api.nvim_cmd, gmove, {})
        if not ok then
            local err_msg = err or "Unknown error performing GMove"
            vim.api.nvim_echo({ { err_msg, "ErrorMsg" } }, true, { err = true })
            return
        end
    else
        if vim.fn.rename(escape_bufname, escape_target) ~= 0 then
            local err_chunk = { "Failed to rename file on disk", "ErrorMsg" }
            vim.api.nvim_echo({ err_chunk }, true, { err = true })
            return
        end

        local args = { escape_target }
        local mods = { keepalt = true }
        vim.api.nvim_cmd({ cmd = "saveas", args = args, bang = true, mods = mods }, {})
    end

    for _, b in pairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(b) == bufname then
            vim.api.nvim_buf_delete(b, { force = true })
        end
    end

    require("mjm.utils").harpoon_mv_buf(escape_bufname, escape_target)
end

vim.api.nvim_create_user_command("BMove", mv_cur_buf, { nargs = 1, complete = "file_in_path" })

local function close_floats()
    for _, win in pairs(vim.fn.getwininfo()) do
        local id = win.winid
        local config = vim.api.nvim_win_get_config(id)
        if config.relative and config.relative ~= "" then
            vim.api.nvim_win_close(id, false)
        end
    end
end

vim.api.nvim_create_user_command("CloseFloats", close_floats, {})

vim.api.nvim_create_user_command("Parse", function(cargs)
    print(vim.inspect(vim.api.nvim_parse_cmd(cargs.args, {})))
end, { nargs = "+" })

local function tab_kill()
    local confirm = vim.fn.confirm(
        "This will delete all buffers in the current tab. Unsaved changes will be lost. Proceed?",
        "&Yes\n&No",
        2
    )

    if confirm ~= 1 then
        return
    end

    local buffers = vim.fn.tabpagebuflist(vim.fn.tabpagenr())
    for _, buf in ipairs(buffers) do
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
end

vim.api.nvim_create_user_command("TabKill", tab_kill, {})

vim.api.nvim_create_user_command("We", "silent up | e", {}) -- Quick refresh if Treesitter bugs out

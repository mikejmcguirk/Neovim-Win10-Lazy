local api = vim.api
local fn = vim.fn
local vimv = vim.v

local M = {}

---@param buf integer
---@return boolean, string|nil, string|nil
function M.check_modifiable(buf)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint)
    if api.nvim_get_option_value("modifiable", { buf = buf }) then
        return true, nil, nil
    else
        return false, "E21: Cannot make changes, 'modifiable' is off", ""
    end
end

---@param buf integer
---@param row integer
---@return integer
function M.get_indent(buf, row)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("buf", buf, is_uint)
    vim.validate("row", row, is_uint)

    local indentexpr = api.nvim_get_option_value("indentexpr", { buf = buf })
    if #indentexpr > 0 then
        local old_row = vimv.lnum
        vimv.lnum = row
        ---@type boolean, string|number?
        local ok, indent = pcall(vim.api.nvim_buf_call, buf, function()
            return vim.fn.eval(indentexpr)
        end)

        vimv.lnum = old_row
        if ok then
            indent = tonumber(indent)
            if type(indent) == "number" and indent >= 0 then
                return indent
            end
        end
    elseif api.nvim_get_option_value("cindent", { buf = buf }) then
        ---@type integer
        local cindent = api.nvim_buf_call(buf, function()
            return fn.cindent(row)
        end)

        if cindent >= 0 then
            return cindent
        end
    elseif
        api.nvim_get_option_value("autoindent", { buf = buf })
        and api.nvim_get_option_value("lisp", { buf = buf })
    then
        ---@type integer
        local lisp = api.nvim_buf_call(buf, function()
            return fn.lispindent(row)
        end)

        if lisp >= 0 then
            return lisp
        end
    end

    return api.nvim_buf_call(buf, function()
        return math.max(fn.indent(fn.prevnonblank(row)), 0)
    end)
end
-- TODO: Guarantee support for all runtime indent functions
-- TODO: Support smartindent

---@return integer[]
function M.get_listed_bufs()
    local bufs = api.nvim_list_bufs()
    require("nvim-tools.list").filter(bufs, function(buf)
        return api.nvim_get_option_value("buflisted", { buf = buf })
    end)

    return bufs
end

---@param buf integer
---@return boolean
function M.is_empty_buf(buf)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint)
    return api.nvim_buf_call(buf, function()
        return fn.wordcount().bytes == 0
    end)
end

---@param buf integer
---@return boolean
function M.is_noname_buf(buf)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint)
    return #api.nvim_buf_get_name(buf) == 0
end

---@param buf integer
---@return boolean
function M.is_empty_noname_buf(buf)
    return M.is_empty_buf(buf) and M.is_noname_buf(buf)
end

---@param fold_cmd "zv"|"zO"|nil
---@param do_zzze? boolean
local function do_open_buf_adjustments(fold_cmd, do_zzze)
    if fold_cmd then
        api.nvim_cmd({ cmd = "normal", args = { fold_cmd }, bang = true }, {})
    end

    if do_zzze then
        api.nvim_cmd({ cmd = "normal", args = { "zzze" }, bang = true }, {})
    end
end

---Assumes proper window context
---Assumes buftype="quickfix" has already been set
---See qf_set_cwindow_options in quickfix.c
---@param buf integer
local function qf_set_cwindow_options(buf)
    local cur_buf = { buf = buf }
    api.nvim_set_option_value("bufhidden", "hide", cur_buf)
    api.nvim_set_option_value("swapfile", false, cur_buf)

    local local_scope = { scope = "local" }
    api.nvim_set_option_value("diff", false, local_scope)
    api.nvim_set_option_value("cursorbind", false, local_scope)
    api.nvim_set_option_value("foldmethod", "manual", local_scope)
    api.nvim_set_option_value("scrollbind", false, local_scope)
end

---Assumes proper window context
---Assumes buftype="help" has already been set
---See :h help-buffer-options
---@param buf integer
local function prepare_help_buffer(buf)
    local cur_buf = { buf = buf }
    api.nvim_set_option_value("binary", false, cur_buf)
    api.nvim_set_option_value("buflisted", false, cur_buf)
    api.nvim_set_option_value("modifiable", false, cur_buf)
    api.nvim_set_option_value("tabstop", 8, cur_buf)
    -- Try to avoid re-running buf_init_chartab
    local old_isk = api.nvim_get_option_value("iskeyword", cur_buf)
    local help_isk = '!-~,^*,^|,^",192-255'
    if old_isk ~= help_isk then
        api.nvim_set_option_value("iskeyword", help_isk, cur_buf)
    end

    local local_scope = { scope = "local" }
    api.nvim_set_option_value("arabic", false, local_scope)
    api.nvim_set_option_value("cursorbind", false, local_scope)
    api.nvim_set_option_value("diff", false, local_scope)
    api.nvim_set_option_value("foldenable", false, local_scope)
    api.nvim_set_option_value("foldmethod", "manual", local_scope)
    api.nvim_set_option_value("list", false, local_scope)
    api.nvim_set_option_value("number", false, local_scope)
    api.nvim_set_option_value("relativenumber", false, local_scope)
    api.nvim_set_option_value("rightleft", false, local_scope)
    api.nvim_set_option_value("scrollbind", false, local_scope)
    api.nvim_set_option_value("spell", false, local_scope)
end

---@param win integer
---@param buftype ""|"acwrite"|"help"|"nofile"|"nowrite"|"prompt"|"quickfix"|"terminal"
---@return string, string
local function get_eiw(win, buftype)
    local old_eiw = api.nvim_get_option_value("eventignorewin", { win = win })
    local new_eiw_tbl = { "WinEnter" } -- Caller will handle this

    -- Both of these FileTypes are meant to set two categories of options:
    -- - Buffer local options that run after loading (Should overwrite autocmds)
    -- - Buffer-scoped window options, which cannot be run until after the buf is set
    -- However, these options should still be overridable by FileType autocmds
    if buftype == "help" or buftype == "quickfix" then
        new_eiw_tbl[#new_eiw_tbl + 1] = "FileType"
    end

    if buftype == "quickfix" then
        -- See qf_open_new_cwindow in quickfix.c
        new_eiw_tbl[#new_eiw_tbl + 1] = "BufWinEnter"
    end

    local misc = require("nvim-tools.misc")
    return old_eiw, misc.append_if_missing(old_eiw, new_eiw_tbl, ",")
end

---Assumes proper window context
---@param win integer
---@param buf integer
---@param buflisted boolean|nil
---@param buftype ""|"acwrite"|"help"|"nofile"|"nowrite"|"prompt"|"quickfix"|"terminal"
---@param will_focus boolean
---@param clearjumps boolean
local function do_set_buf(win, buf, buflisted, buftype, will_focus, clearjumps)
    local buf_opt = { buf = buf }
    local win_opt = { win = win }

    local old_eiw, new_eiw = get_eiw(win, buftype)
    api.nvim_set_option_value("eventignorewin", new_eiw, win_opt)
    -- Set now since buf init can be tied into buftype, such as |local-additions| in help
    api.nvim_set_option_value("buftype", buftype, buf_opt)

    local cur_win = api.nvim_get_current_win()
    local dest_win = will_focus and win or cur_win
    if dest_win == cur_win then
        api.nvim_cmd({ cmd = "normal", args = { "m'" }, bang = true }, {})
    end

    local global_opt = { scope = "global" }
    local old_lz = api.nvim_get_option_value("lazyredraw", global_opt)
    api.nvim_set_option_value("lazyredraw", true, global_opt)
    local ok, err = pcall(api.nvim_set_current_buf, buf)
    api.nvim_set_option_value("eventignorewin", old_eiw, win_opt)
    if not ok then
        api.nvim_set_option_value("lazyredraw", old_lz, global_opt)
        error(err or ("Unable to set buf " .. buf .. " into win " .. win))
    end

    if buftype == "help" then
        prepare_help_buffer(buf)
        api.nvim_set_option_value("filetype", "help", buf_opt)
    elseif buftype == "quickfix" then
        qf_set_cwindow_options(buf)
        api.nvim_set_option_value("filetype", "qf", buf_opt)
    end

    api.nvim_set_option_value("lazyredraw", old_lz, global_opt)
    if clearjumps then
        api.nvim_cmd({ cmd = "clearjumps" }, {})
    end

    local bl = require("nvim-tools.misc").if_not_nil(buflisted, buftype ~= "help")
    api.nvim_set_option_value("buflisted", bl, buf_opt)
end
-- NOTE: nvim_set_current_buf uses open_buffer in buffer.c as its backend

---@param buf integer
---@param force "abandon"|"hide"|""|"save"
local function handle_abandonment(buf, force)
    if force == "abandon" then
        return
    end

    local global_opt = { scope = "global" }
    if api.nvim_get_option_value("hidden", global_opt) == true then
        return
    end

    local buf_opt = { buf = buf }
    if api.nvim_get_option_value("bufhidden", buf_opt) == "hide" or #fn.win_findbuf(buf) > 1 then
        return
    end

    local bt = api.nvim_get_option_value("buftype", buf_opt)
    local no_save = bt == "nowrite" or bt == "nofile" or bt == "terminal" or bt == "prompt"
    if no_save or not api.nvim_get_option_value("modified", buf_opt) then
        return
    end

    if force == "hide" then
        api.nvim_set_option_value("bufhidden", "hide", buf_opt)
        return
    end

    if force == "" and not api.nvim_get_option_value("autowriteall", global_opt) then
        error("No write since last change")
    end

    local ok, err, _ = M.save(buf)
    if ok then
        return
    elseif force == "save" then
        api.nvim_set_option_value("bufhidden", "hide", buf_opt)
    else
        error(err or ("Unable to save " .. fn.bufname(buf)))
    end
end

---@param win integer window-ID
---@param buf integer
---@param opts nvim-tools.buf.OpenBufOpts
local function validate_open_buf_params(win, buf, opts)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("win", win, is_uint)
    vim.validate("opts", opts, "table")
    vim.validate("buf", buf, function()
        return is_uint(buf) or type(buf) == "string"
    end)

    if not api.nvim_win_is_valid(win) then
        error("Window " .. win .. " is not valid")
    end

    if not api.nvim_buf_is_valid(buf) then
        error("Buf " .. buf .. " is not valid")
    end
end

---@class nvim-tools.buf.OpenBufOpts
---Manually set the listed status of the buffer. If nil, help buffers will be unlisted, with all
---other types listed (default |:edit| behavior). Does not apply if the buffer is already open.
---@field buflisted? boolean|nil
---Determines buflisted behavior if that opt is nil. help and quickfix buffers will set appropriate
---buf and window options. Does not apply if the buffer is already open.
---@field buftype? ""|"acwrite"|"help"|"nofile"|"nowrite"|"prompt"|"quickfix"|"terminal"
---Default false. If true, clears jumps after opening a new buffer. Does not apply if the buffer
---is already open.
---@field clearjumps? boolean
---Position to jump to in the destination win. Cursor indexed. Ignored if buftype is terminal.
---@field cur_pos? { [1]:integer, [2]:integer }
---Default false. Does not apply if the buffer is already open and cur_pos is nil. Ignored if
---buftype is terminal.
---@field do_zzze? boolean
---Focus the buffer after opening?
---@field focus? boolean
---What to do if hidden and bufhidden are false, and the buf being exited is only present in
---the targeted window. Defaults to "hide" if nil. nofile, nowrite, prompt, and terminal buffers
---are always allowed to be abandoned.
---- "save" will try to save, falling back to "hide" behavior if this is impossible.
---- "hide" sets bufhidden to hide. Saved buffers are allowed to be abandoned.
---- "" will try to save if autowriteall is true. Errors otherwise.
---- "abandon" makes no attempt to be non-destructive.
---@field force? "abandon"|"hide"|""|"save"
---Default nil. Requires cur_pos to be not nil. Ignored if buttype is terminal.
---@field fold_cmd? "zv"|"zO"
---cur_pos is the final cursor position in the destination window.
---@field on_open fun(cur_pos: { [1]:integer, [2]:integer })

---Hards errors if win or buf are invalid. Callers should gracefully handle if needed
---@param win integer window-ID
---@param buf integer
---@param opts nvim-tools.buf.OpenBufOpts
function M.open_buf(win, buf, opts)
    validate_open_buf_params(win, buf, opts)

    local cur_buf = api.nvim_win_get_buf(win)
    local already_open = cur_buf == buf
    local buftype = opts.buftype or api.nvim_get_option_value("buftype", { buf = buf })
    local cur_pos = opts.cur_pos

    if not already_open then
        handle_abandonment(cur_buf, opts.force or "hide")
        api.nvim_win_call(win, function()
            do_set_buf(win, buf, opts.buflisted, buftype, opts.focus, opts.clearjumps)
        end)
    end

    if cur_pos and buftype ~= "terminal" then
        if already_open then
            api.nvim_win_call(win, function()
                api.nvim_cmd({ cmd = "normal", args = { "m'" }, bang = true }, {})
            end)
        end

        -- Outside win_call to avoid recursively setting temporary window context
        cur_pos = require("nvim-tools.win").protected_set_cursor(win, cur_pos)
    end

    local not_term = buftype ~= "terminal"
    local do_zzze = opts.do_zzze and ((not already_open) or cur_pos ~= nil) and not_term
    local fold_cmd = (opts.fold_cmd and cur_pos ~= nil and not_term) and opts.fold_cmd or nil
    if opts.focus then
        api.nvim_set_current_win(win)
        do_open_buf_adjustments(fold_cmd, do_zzze)
    else
        if fold_cmd or do_zzze then
            api.nvim_win_call(win, function()
                do_open_buf_adjustments(fold_cmd, do_zzze)
            end)
        end
    end

    local on_open = opts.on_open
    if on_open then
        on_open(cur_pos or api.nvim_win_get_cursor(win))
    end
end

---@param buf integer
---@param delist boolean
---@param opts vim.api.keyset.buf_delete
---@return boolean, string|nil, string|nil
function M.protected_del(buf, delist, opts)
    if not api.nvim_buf_is_valid(buf) then
        return false, "Buf " .. buf .. " is not valid", ""
    end

    if opts.unload then
        local listed_bufs = M.get_listed_bufs()
        require("nvim-tools.list").filter(listed_bufs, function(b)
            return b ~= buf
        end)

        if #listed_bufs == 1 then
            return false, "E90: Cannot unload the last buffer", ""
        end

        if delist then
            api.nvim_set_option_value("buflisted", false, { buf = buf })
        end
    end

    local ok, err = pcall(api.nvim_buf_delete, buf, opts)
    if ok then
        return ok, nil, nil
    else
        return ok, err, "ErrorMsg"
    end
end

---Assumes buf has been validated
---@param buf integer|string
---@return boolean, integer, string|nil, string|nil
function M.resolve_buf(buf)
    if buf == 0 then
        return true, api.nvim_get_current_buf(), nil, nil
    end

    local bufnr = buf
    if type(bufnr) == "string" then
        bufnr = fn.bufadd(bufnr)
        if bufnr == 0 then
            return false, -1, buf .. " is not a valid file", "ErrorMsg"
        end
    end

    if api.nvim_buf_is_valid(bufnr) then
        return true, bufnr, nil, nil
    else
        return false, -1, "Bufnr " .. bufnr .. " is invalid", "ErrorMsg"
    end
end

---@param buf integer
---@return boolean, string|nil, string|nil
function M.save(buf)
    if not api.nvim_buf_is_valid(buf) then
        return false, "Buffer " .. buf .. " is invalid", ""
    end

    if #api.nvim_buf_get_name(buf) == 0 then
        return false, "E32: No file name", "ErrorMsg"
    end

    local ok, err = pcall(api.nvim_cmd, { cmd = "update", mods = { silent = true } }, {})
    if ok then
        return ok, nil, nil
    else
        return ok, err, "ErrorMsg"
    end
end

---@param buf integer
---@param delist boolean
---@param opts vim.api.keyset.buf_delete
---@return boolean, string|nil, string|nil
function M.save_and_del(buf, delist, opts)
    opts = require("nvim-tools.table").copy(opts)
    if not opts.force then
        if M.is_empty_noname_buf(buf) then
            opts.force = true
        else
            local ok, err, hl = M.save(buf)
            if not ok then
                return ok, err, hl
            end
        end
    end

    return M.protected_del(buf, delist, opts)
end
-- LOW: Should force still try to save, but ignore failures?

return M

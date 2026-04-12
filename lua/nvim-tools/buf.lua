local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv
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

---Create a temporary buffer. Always:
---- noml
---- nomod
---- noswf
---- noudf
---
---Set bufhidden.
---"hide" is useful for cached buffers such as previews.
---"wipe" is useful for placeholders, like temporary help buffers used to open helptags in a
---targeted window.
---@param bh ""|"hide"|"unload"|"delete"|"wipe"
---@param bl boolean Buflisted
---"nofile" will make the buffer display as "scratch" in the statusline
---"help" can be used for targeted helptag opening
---@param bt ""|"acwrite"|"help"|"nofile"|"nowrite"|"prompt"|"quickfix"|"terminal"
---@param ft string Set a filetype (useful for preview buffers). "" is a no-op
---@param noma boolean Sets nomodifiable and readonly
---@return integer
function M.create_temp_buf(bh, bl, bt, ft, noma)
    local buf = api.nvim_create_buf(false, false)
    local buf_scope = { buf = buf }

    if bt ~= "" then
        api.nvim_set_option_value("buftype", bt, buf_scope)
    end

    -- Set unconditionally because of autocmds/global settings
    api.nvim_set_option_value("bh", bh, buf_scope)
    api.nvim_set_option_value("ml", false, buf_scope)
    api.nvim_set_option_value("mod", false, buf_scope)
    api.nvim_set_option_value("swapfile", false, buf_scope)
    api.nvim_set_option_value("undofile", false, buf_scope)

    if noma then
        api.nvim_set_option_value("ma", false, buf_scope)
        api.nvim_set_option_value("ro", true, buf_scope)
    end

    if bl then
        api.nvim_set_option_value("bl", bl, buf_scope)
    end

    if ft ~= "" then
        api.nvim_set_option_value("ft", ft, buf_scope)
    end

    return buf
end
-- MID: On principle, I have ft delayed until the end. Can change if a use case comes up for why
-- it should be fired earlier.

---@param bufnr integer
---@return string
function M.get_bcd(bufnr)
    vim.validate("bufnr", bufnr, require("nvim-tools.types").is_uint)
    return fs.dirname(fs.normalize(api.nvim_buf_get_name(bufnr)))
end
-- FUTURE: Deprecate whenever an official implementation of this is rolled out.

---@param buf integer
---@param row integer
---@return integer
function M.get_indent(buf, row)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("buf", buf, is_uint)
    vim.validate("row", row, is_uint)

    ---@type string
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
function M.is_empty(buf)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint)
    return api.nvim_buf_call(buf, function()
        return fn.wordcount().bytes == 0
    end)
end

---@param buf integer
---@return boolean
function M.is_noname(buf)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint)
    return #api.nvim_buf_get_name(buf) == 0
end

---@param buf integer
---@return boolean
function M.is_empty_noname(buf)
    return M.is_empty(buf) and M.is_noname(buf)
end

---@param fold_cmd "zv"|"zO"|"zx"|"zR"|nil
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
    local buf_scope = { buf = buf }
    api.nvim_set_option_value("bh", "hide", buf_scope)
    api.nvim_set_option_value("swf", false, buf_scope)

    local local_scope = { scope = "local" }
    api.nvim_set_option_value("crb", false, local_scope)
    api.nvim_set_option_value("diff", false, local_scope)
    api.nvim_set_option_value("fdm", "manual", local_scope)
    api.nvim_set_option_value("scb", false, local_scope)
end

---Assumes proper window context
---Assumes buftype="help" has already been set
---See :h help-buffer-options
---@param buf integer
local function prepare_help_buffer(buf)
    local buf_scope = { buf = buf }
    api.nvim_set_option_value("binary", false, buf_scope)
    api.nvim_set_option_value("buflisted", false, buf_scope)
    api.nvim_set_option_value("modifiable", false, buf_scope)
    api.nvim_set_option_value("tabstop", 8, buf_scope)

    -- Try to avoid re-running buf_init_chartab
    local old_isk = api.nvim_get_option_value("iskeyword", buf_scope) ---@type string
    local help_isk = '!-~,^*,^|,^",192-255'
    local set_if_new = require("nvim-tools.opts").set_if_new
    set_if_new("isk", old_isk, help_isk, buf_scope)

    local local_scope = { scope = "local" }
    api.nvim_set_option_value("arabic", false, local_scope)
    api.nvim_set_option_value("cursorbind", false, local_scope)
    api.nvim_set_option_value("diff", false, local_scope)
    api.nvim_set_option_value("fdm", "manual", local_scope)
    api.nvim_set_option_value("fen", false, local_scope)
    api.nvim_set_option_value("list", false, local_scope)
    api.nvim_set_option_value("nu", false, local_scope)
    api.nvim_set_option_value("rightleft", false, local_scope)
    api.nvim_set_option_value("rnu", false, local_scope)
    api.nvim_set_option_value("scrollbind", false, local_scope)
    api.nvim_set_option_value("spell", false, local_scope)
end

---@param win integer
---@param buftype ""|"acwrite"|"help"|"nofile"|"nowrite"|"prompt"|"quickfix"|"terminal"
---@return string, string
local function get_eiw(win, buftype)
    local old_eiw = api.nvim_get_option_value("eventignorewin", { win = win })
    local new_eiw_tbl = { "WinEnter,WinLeave" } -- Caller will handle these

    -- Both of these FileTypes are meant to set two categories of options:
    -- - Buffer local options that run after loading (Should overwrite autocmds)
    -- - Buffer-scoped window options, which cannot be run until after the buf is set
    --   (Should be overwritten by FileType autocmds)
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
---@param bl boolean|nil
---@param bt ""|"acwrite"|"help"|"nofile"|"nowrite"|"prompt"|"quickfix"|"terminal"
---@param clearjumps boolean
---@return boolean
local function do_set_buf(win, buf, bl, bt, clearjumps)
    local buf_opt = { buf = buf }
    local win_opt = { win = win }

    local old_eiw, new_eiw = get_eiw(win, bt)
    local set_if_new = require("nvim-tools.opts").set_if_new
    set_if_new("eiw", old_eiw, new_eiw, win_opt)
    -- Set now since buf init can be tied into buftype, such as |local-additions| in help
    api.nvim_set_option_value("bt", bt, buf_opt)
    if not clearjumps then
        api.nvim_cmd({ cmd = "normal", args = { "m'" }, bang = true }, {})
    end

    local global_opt = { scope = "global" }
    local old_lz = api.nvim_get_option_value("lz", global_opt)
    set_if_new("lz", old_lz, true, global_opt)

    local ok, err = pcall(api.nvim_set_current_buf, buf)
    set_if_new("eiw", new_eiw, old_eiw, win_opt)
    if (not ok) or api.nvim_win_get_buf(win) ~= buf then
        set_if_new("lz", true, old_lz, global_opt)
        error(err or ("Unable to set buf " .. buf .. " into win " .. win))
    end

    if bt == "help" then
        prepare_help_buffer(buf)
        api.nvim_set_option_value("filetype", "help", buf_opt)
    elseif bt == "quickfix" then
        qf_set_cwindow_options(buf)
        api.nvim_set_option_value("filetype", "qf", buf_opt)
    end

    set_if_new("lz", true, old_lz, global_opt)
    if clearjumps then
        api.nvim_cmd({ cmd = "clearjumps" }, {})
    end

    local buflisted = require("nvim-tools.misc").if_not_nil(bl, bt ~= "help")
    api.nvim_set_option_value("bl", buflisted, buf_opt)
    return true
end
-- NOTE: nvim_set_current_buf uses open_buffer in buffer.c as its backend
-- TODO: Test buf open failure handling by using a once autocmd on BufReadPre or something

---@param buf integer
---@param force "force"|"hide"|""|"save"
local function handle_force(buf, force)
    if force == "force" then
        return
    end

    local global_opt = { scope = "global" }
    if api.nvim_get_option_value("hid", global_opt) == true then
        return
    end

    local buf_opt = { buf = buf }
    local bufhidden = api.nvim_get_option_value("bh", buf_opt) ---@type string
    if bufhidden == "hide" or #fn.win_findbuf(buf) > 1 then
        return
    end

    local bt = api.nvim_get_option_value("buftype", buf_opt)
    local no_save = bt == "nowrite" or bt == "nofile" or bt == "terminal" or bt == "prompt"
    if no_save or not api.nvim_get_option_value("mod", buf_opt) then
        return
    end

    if force == "hide" then
        api.nvim_set_option_value("bh", "hide", buf_opt)
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
-- TODO: This is directionally correct but sloppy

---@param win integer window-ID
---@param buf integer
---@param opts nvim-tools.buf.OpenBufOpts
local function resolve_open_buf_params(win, buf, opts)
    -- The resolve functions run vim.validate
    local ok_w, win_id, err_w, _ = require("nvim-tools.win").resolve_win_id(win)
    if not ok_w then
        error(err_w or ("Invalid window ID " .. win))
    end

    local ok_b, bufnr, err_b, _ = M.resolve_bufnr(buf)
    if not ok_b then
        error(err_b or ("Invalid buffer " .. buf))
    end

    vim.validate("opts", opts, "table")
    return win_id, bufnr
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
---Default true. Focus the buffer after opening?
---@field focus? boolean
---What to do if hidden and bufhidden are false, and the buf being exited is only present in
---the targeted window. Defaults to "hide" if nil. nofile, nowrite, prompt, and terminal buffers
---are always allowed to be abandoned.
---- "save" will try to save, falling back to "hide" behavior if this is impossible.
---- "hide" sets bufhidden to hide. Saved buffers are allowed to be abandoned.
---- "" will try to save if autowriteall is true. Errors otherwise.
---- "abandon" makes no attempt to be non-destructive.
---@field force? "force"|"hide"|""|"save"
---Default nil. Requires cur_pos to be not nil. Ignored if buttype is terminal.
---@field fold_cmd? "zv"|"zO"|"zx"|"zR"
---cur_pos is the final cursor position in the destination window.
---@field on_open? fun(cur_pos: { [1]:integer, [2]:integer })

---Versatile buffer opening logic meant for user-facing contexts in which any buftype could be
---opened in any window. Sets temporary window context and uses eventignorewin + lazyredraw to
---emulate proper help buffer opening.
---Hards errors on failure, including win or buf invalid.
---@param win integer window-ID
---@param buf integer
---@param opts nvim-tools.buf.OpenBufOpts
function M.open_buf(win, buf, opts)
    win, buf = resolve_open_buf_params(win, buf, opts)
    if api.nvim_get_option_value("wfb", { win = win }) then
        error("Vim:E1513: Cannot switch buffer. 'winfixbuf' is enabled")
    end

    local start_win = api.nvim_get_current_win()
    local dest_win_cur_buf = api.nvim_win_get_buf(win)
    local already_open = dest_win_cur_buf == buf
    local buftype = opts.buftype or api.nvim_get_option_value("bt", { buf = buf })
    local cur_pos = opts.cur_pos

    if not already_open then
        handle_force(dest_win_cur_buf, opts.force or "hide")
        api.nvim_win_call(win, function()
            return do_set_buf(win, buf, opts.buflisted, buftype, opts.clearjumps)
        end)
    end

    local not_term = buftype ~= "terminal"
    if cur_pos and not_term then
        if already_open then
            api.nvim_win_call(win, function()
                api.nvim_cmd({ cmd = "normal", args = { "m'" }, bang = true }, {})
            end)
        end

        -- Outside win_call to avoid recursively setting temporary window context
        cur_pos = require("nvim-tools.win").protected_set_cursor(win, cur_pos)
    end

    local focus = opts.focus
    local do_focus = focus == true or focus == nil
    local in_dest_win = start_win == win
    if do_focus and not in_dest_win then
        api.nvim_set_current_win(win)
    end

    local do_zzze = opts.do_zzze and (cur_pos or not already_open) and not_term
    local fold_cmd = (opts.fold_cmd and cur_pos and not_term) and opts.fold_cmd or nil
    if do_focus or in_dest_win then
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

---@param bufnr integer
---@return boolean, integer, string|nil, string|nil
function M.resolve_bufnr(bufnr)
    vim.validate("bufnr", bufnr, require("nvim-tools.types").is_uint)

    if bufnr == 0 then
        return true, api.nvim_get_current_buf(), nil, nil
    end

    if api.nvim_buf_is_valid(bufnr) then
        return true, bufnr, nil, nil
    else
        return false, -1, "Bufnr " .. bufnr .. " is invalid", "ErrorMsg"
    end
end

---Note that "" can be a valid bufname.
---@param bufnr integer
---@return boolean, string, string|nil, string|nil
function M.bufnr_to_full_bufname(bufnr)
    local ok, resolved_bufnr, err, hl = M.resolve_bufnr(bufnr)
    if not ok then
        return ok, "", err, hl
    end

    return true, api.nvim_buf_get_name(resolved_bufnr), nil, nil
end
-- TODO: Is "" the correct return on err?

---@param bufname string
---@return boolean, string, string|nil, string|nil
function M.resolve_full_bufname(bufname)
    vim.validate("bufname", bufname, "string")
    return true, fs.normalize(fn.fnamemodify(bufname, ":p")), nil, nil
end

---@param bufname string
---@return boolean, integer, string|nil, string|nil
function M.bufname_to_bufnr(bufname)
    vim.validate("bufname", bufname, "string")

    local full_bufname = fs.normalize(fn.fnamemodify(bufname, ":p"))
    local ok, err, err_name = uv.fs_access(full_bufname, 4)
    if not ok then
        local err_str = err or "fs_access error"
        local err_msg = err_name .. ": " .. err_str
        return false, -1, err_msg, "ErrorMsg"
    end

    local bufnr = fn.bufadd(full_bufname)
    if bufnr == 0 then
        return false, -1, "Unable to add " .. full_bufname, "ErrorMsg"
    else
        return true, bufnr, nil, nil
    end
end
-- MAYBE: I'm assuming for now that this function wouldn't be used in a situation where nofile
-- buffers are co-mingled with actual files. Can add guard code if something comes up.

---@param buf integer|string
---@return boolean, integer, string|nil, string|nil
function M.buf_to_bufnr(buf)
    -- Doing the if this way makes Lua_Ls happy
    if type(buf) == "string" then
        return M.bufname_to_bufnr(buf)
    else
        -- Assumes is_uint will be checked in here
        return M.resolve_bufnr(buf)
    end
end

---@param buf integer|string
---@return boolean, string, string|nil, string|nil
function M.buf_to_full_bufname(buf)
    -- Doing the if this way makes Lua_Ls happy
    if type(buf) == "string" then
        return true, fs.normalize(fn.fnamemodify(buf, ":p")), nil, nil
    else
        -- Assumes is_uint will be checked in here
        return M.bufnr_to_full_bufname(buf)
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
-- TODO: This error comes up on qflists, where it really shouldn't.
-- FUTURE: Could bcd or workspace config be used for saving here?

---@param buf integer
---@param delist boolean
---@param opts vim.api.keyset.buf_delete
---@return boolean, string|nil, string|nil
function M.save_and_del(buf, delist, opts)
    opts = require("nvim-tools.table").copy(opts)
    if not api.nvim_buf_is_valid(buf) then
        return false, "Buffer " .. buf .. " is invalid", ""
    end

    if not opts.force then
        if M.is_empty_noname(buf) then
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

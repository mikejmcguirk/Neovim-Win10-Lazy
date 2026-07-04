local api = vim.api
local fn = vim.fn
local fs = vim.fs
local vimv = vim.v

local M = {}

---Create a temporary buffer. Always:
---- noml
---- nomod
---- noswf
---- noudf
---
---@param bh? ""|"hide"|"unload"|"delete"|"wipe" Set bufhidden
---"hide" is useful for cached buffers such as previews.
---"wipe" is useful for placeholders, like temporary help buffers used to open helptags in a
---targeted window.
---(default: `hide`)
---@param bl? boolean Set buflisted
---(default: `true`)
---@param bt? ""|"acwrite"|"help"|"nofile"|"nowrite"|"prompt"|"quickfix"|"terminal"
---"nofile" will make the buffer display as "scratch" in the statusline
---"help" can be used for targeted helptag opening
---(default: `""`)
---@param ft? string Set a filetype (useful for preview buffers). nil is a no-op
---(default: `""`)
---@param ma? boolean Set modifiable
---(default: `true`)
---@return integer
function M.create_temp_buf(bh, bl, bt, ft, ma)
    vim.validate("bh", bh, "string")
    vim.validate("bl", bl, "boolean")
    vim.validate("bt", bt, "string", true)
    vim.validate("ft", ft, "string", true)
    vim.validate("noma", ma, "boolean", true)

    local buf = api.nvim_create_buf(false, false)
    local buf_scope = { buf = buf }

    if bt then
        api.nvim_set_option_value("buftype", bt, buf_scope)
    end

    -- Set unconditionally because of autocmds/global settings
    bh = bh or "hide"
    api.nvim_set_option_value("bh", bh, buf_scope)
    api.nvim_set_option_value("ml", false, buf_scope)
    api.nvim_set_option_value("mod", false, buf_scope)
    api.nvim_set_option_value("swf", false, buf_scope)
    api.nvim_set_option_value("udf", false, buf_scope)

    if ma == false then
        api.nvim_set_option_value("ma", false, buf_scope)
    end

    if bl ~= false then
        api.nvim_set_option_value("bl", true, buf_scope)
    end

    if ft then
        api.nvim_set_option_value("ft", ft, buf_scope)
    end

    return buf
end
-- TODO: This function does two much. Fundamentally, we need to address two cases:
-- - Creating a "scratch" buffer, which has weird properties about filetype and what can drop
-- into it.
-- - Creating temporary buffers to open new windows and tabs, because it makes a lot of other
-- processes more sane.

---@audited 2026-07-03
---@param bufnr integer
---@return string
function M.get_bcd(bufnr)
    return fs.dirname(fs.normalize(api.nvim_buf_get_name(bufnr)))
end

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
        ---@type string|number?
        local indent = api.nvim_buf_call(buf, function()
            return api.nvim_eval(indentexpr)
        end)

        vimv.lnum = old_row
        indent = tonumber(indent)
        if type(indent) == "number" and indent >= 0 then
            return indent
        end
    elseif api.nvim_get_option_value("cindent", { buf = buf }) then
        ---@type integer
        local cindent = api.nvim_buf_call(buf, function()
            return vim.call("cindent", row)
        end)

        if cindent >= 0 then
            return cindent
        end
    elseif
        api.nvim_get_option_value("ai", { buf = buf })
        and api.nvim_get_option_value("lisp", { buf = buf })
    then
        ---@type integer
        local lispindent = api.nvim_buf_call(buf, function()
            return vim.call("lispindent", row)
        end)

        if lispindent >= 0 then
            return lispindent
        end
    end

    return api.nvim_buf_call(buf, function()
        return math.max(fn.indent(fn.prevnonblank(row)), 0)
    end)
end

---@audited 2026-07-03
---@return integer[]
function M.get_listed_bufs()
    local bufs = api.nvim_list_bufs()
    return require("nvim-tools.table").i_keep(bufs, function(buf)
        return api.nvim_get_option_value("buflisted", { buf = buf })
    end)
end

---@audited 2026-07-03
---@param buf integer
---@return boolean
function M.is_empty(buf)
    local line_count = api.nvim_buf_line_count(buf)
    if line_count == 0 then
        return true
    elseif line_count > 1 then
        return false
    end

    local lines = api.nvim_buf_get_lines(buf, 0, 1, false)
    return #lines == 0 or lines[1] == ""
end

---@audited 2026-07-03
---@param buf integer
---@return boolean
function M.is_empty_noname(buf)
    return M.is_empty(buf) and #api.nvim_buf_get_name(buf) == 0
end

---@param dest_win integer
---@param is_term? boolean
---@param fold_cmd? "zv"|"zO"|"zx"|"zR"
---@param do_zzze? boolean
function M.buf_post_open(dest_win, is_term, fold_cmd, do_zzze)
    if not (fold_cmd or do_zzze) then
        return
    end

    if is_term == nil then
        local dest_buf = api.nvim_win_get_buf(dest_win)
        ---@type string
        local bt = api.nvim_get_option_value("bt", { buf = dest_buf })
        is_term = bt == "terminal"
    end

    if is_term then
        return
    end

    api.nvim_win_call(dest_win, function()
        if fold_cmd then
            api.nvim_cmd({ cmd = "normal", args = { fold_cmd }, bang = true }, {})
        end

        if do_zzze then
            api.nvim_cmd({ cmd = "normal", args = { "zzze" }, bang = true }, {})
        end
    end)
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
    local old_eiw = api.nvim_get_option_value("eventignorewin", { win = win }) or ""
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
    api.nvim_set_current_buf(buf)
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

    local buflisted = require("nvim-tools.misc").nonnil(bl, bt ~= "help")
    api.nvim_set_option_value("bl", buflisted, buf_opt)
    return true
end
-- NOTE: nvim_set_current_buf uses open_buffer in buffer.c as its backend

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
    local bh = api.nvim_get_option_value("bh", buf_opt) ---@type string
    if bh == "hide" or #fn.win_findbuf(buf) > 1 then
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

    if force == "" and not api.nvim_get_option_value("awa", global_opt) then
        error("No write since last change")
    end

    local ok, err, _ = M.save(buf)
    if ok then
        return
    else
        error(err or ("Unable to save " .. fn.bufname(buf)))
    end
end

---@param win integer window-ID
---@param buf integer
---@param opts nvim-tools.buf.OpenBufOpts
local function resolve_open_buf_params(win, buf, opts)
    -- The resolve functions run vim.validate
    if not api.nvim_win_is_valid(win) then
        error("Invalid window ID " .. win)
    end

    if not api.nvim_buf_is_valid(buf) then
        error("invalid buffer " .. buf)
    end

    vim.validate("opts", opts, "table")
    return win, buf
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
---Hard errors on failure, including win or buf invalid.
---@param win integer See |window-ID|
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
        cur_pos = require("nvim-tools.win").protected_set_cursor(win, cur_pos, not not_term)
    end

    local focus = opts.focus
    local do_focus = focus == true or focus == nil
    local in_dest_win = start_win == win
    if do_focus and not in_dest_win then
        api.nvim_set_current_win(win)
    end

    local do_zzze = opts.do_zzze and (cur_pos ~= nil or not already_open)
    local fold_cmd = (opts.fold_cmd and cur_pos) and opts.fold_cmd or nil
    M.buf_post_open(win, not not_term, fold_cmd, do_zzze)

    local on_open = opts.on_open
    if on_open then
        on_open(cur_pos or api.nvim_win_get_cursor(win))
    end
end
-- TODO: A few things that need to happen for this to stick around:
-- - Cannot be doing temp option sets. Insane point point if something breaks
-- - Try to do prepare_help_buffer on BufReadPost.
-- - Disfavor manually setting win context. For stuff like zzze there's no real way out of it,
-- but especially for buf opening we want to try nvim_win_set_buf (though triggering BufEnter
-- is quite bad)
-- - There are too many options baked into here, and maybe zome of the zzze stuff needs to be
-- broken out as well. It should be possible to do like, a conditional save of a buffer then
-- opening it then like scrolling and entrance as separate things. Composable pieces.

---@param buf integer Buffer to delete
---@param delist? boolean De-list buffer?
---@param opts vim.api.keyset.buf_delete
---@return boolean, string|nil, string|nil
function M.protected_del(buf, delist, opts)
    vim.validate("buf", buf, require("nvim-tools.types").is_uint)
    vim.validate("delist", delist, "boolean", true)
    vim.validate("opts", opts, "table")

    if not api.nvim_buf_is_valid(buf) then
        return false, "Buf " .. buf .. " is not valid", ""
    end

    if opts.unload then
        local listed_bufs = M.get_listed_bufs()
        -- TODO: this should be any() ~= buf
        require("nvim-tools.table").i_discard(listed_bufs, function(b)
            return b == buf
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

---@audited 2026-07-03
---@param range nvim-tools.Range|nvim-tools.range.BufRange
---@param buf uinteger
---@return string
function M.text_from_range(range, buf)
    return api.nvim_buf_get_text(buf, range[1], range[2], range[3], range[4], {})[1] or ""
end

---@audited 2026-07-03
---@param cur_pos_ext [uinteger, uinteger] 0, 0 indexed
---@param buf uinteger
---@param pattern string See |pattern|
---@return nvim-tools.range.BufRange?
function M.line_match_under_cursor(cur_pos_ext, buf, pattern)
    local re = vim.regex(pattern)
    local init = 0
    local row = cur_pos_ext[1]
    local col = cur_pos_ext[2]
    while true do
        local sc, ec_ = re:match_line(buf, row, init)
        if sc == nil or ec_ == nil then
            return nil
        end

        sc = sc + init
        ec_ = ec_ + init
        if sc <= col and col < ec_ then
            return { row, sc, row, ec_, buf }
        end

        init = ec_
    end
end

---@audited 2026-07-03
---@param bufname string
---@return uinteger
function M.bufname_to_bufnr(bufname)
    local ntf = require("nvim-tools.fs")
    local full_bufname = ntf.path_norm_abs_get(bufname)
    return fn.bufadd(full_bufname)
end
-- NON: Filepath validation. bufadd() handles this.

---@param buf integer
---@return boolean, string|nil, string|nil
function M.save(buf)
    if not api.nvim_buf_is_valid(buf) then
        return false, "Buffer " .. buf .. " is invalid", ""
    end

    local bt = api.nvim_get_option_value("bt", { buf = buf })
    if bt == "nofile" or bt == "quickfix" then
        return false, "Cannot save buftype " .. bt, ""
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

return M

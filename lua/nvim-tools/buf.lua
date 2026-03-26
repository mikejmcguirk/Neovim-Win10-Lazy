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

---Assumes proper window context
---@param buf integer
---@return nil
--- See :h help-buffer-options
local function prep_help_buf(buf)
    local cur_buf = { buf = buf }
    api.nvim_set_option_value("binary", false, cur_buf)
    api.nvim_set_option_value("buflisted", false, cur_buf)
    api.nvim_set_option_value("iskeyword", '!-~,^*,^|,^",192-255', cur_buf)
    api.nvim_set_option_value("modifiable", false, cur_buf)
    api.nvim_set_option_value("tabstop", 8, cur_buf)

    local local_scope = { scope = "local" }
    api.nvim_set_option_value("arabic", false, local_scope)
    api.nvim_set_option_value("cursorbind", false, local_scope)
    api.nvim_set_option_value("diff", false, local_scope)
    api.nvim_set_option_value("foldenable", false, local_scope)
    api.nvim_set_option_value("foldmethod", "manual", local_scope)
    api.nvim_set_option_value("list", false, local_scope)
    api.nvim_set_option_value("number", false, local_scope)
    api.nvim_set_option_value("rightleft", false, local_scope)
    api.nvim_set_option_value("relativenumber", false, local_scope)
    api.nvim_set_option_value("scrollbind", false, local_scope)
    api.nvim_set_option_value("spell", false, local_scope)

    api.nvim_set_option_value("buftype", "help", cur_buf)
    -- NOTE: Let the filetype be set on load as normal
end

---@param buf integer|string
---@return integer
local function get_open_bufnr(buf)
    if type(buf) == "string" then
        local bufnr = fn.bufadd(buf)
        if bufnr == 0 then
            error("Unable to add bufname " .. buf)
        else
            return bufnr
        end
    end

    if type(buf) == "number" then
        if not api.nvim_buf_is_valid(buf) then
            error("Buf " .. buf .. " is invalid")
        else
            return buf
        end
    end

    error("buf " .. tostring(buf) .. " is not a string or a valid bufnr")
end
-- MID: Is hard error best here?

---@class nvim-tools.buf.OpenBufOpts
---@field buftype? string
---@field clearjumps? boolean
---@field cur_pos? { [1]:integer, [2]:integer }
---@field do_zzze? boolean
---@field focus? boolean
---@field fold_cmd? "zv"|"zO"|nil

---@param win integer window-ID
---@param buf integer|string
---@param opts nvim-tools.buf.OpenBufOpts
function M.open_buf(win, buf, opts)
    vim.validate("opts", opts, "table")
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("win", win, is_uint)
    if not api.nvim_win_is_valid(win) then
        return
    end

    local bufnr = get_open_bufnr(buf)
    if not api.nvim_buf_is_valid(bufnr) then
        return
    end

    local cur_pos = opts.cur_pos
    api.nvim_win_call(win, function()
        local already_open = api.nvim_win_get_buf(win) == bufnr
        if not already_open then
            if opts.buftype == "help" then
                prep_help_buf(bufnr)
            else
                api.nvim_set_option_value("buflisted", true, { buf = bufnr })
            end

            -- This loads the buf if necessary. Do not use bufload
            api.nvim_set_current_buf(bufnr)
            if opts.clearjumps then
                api.nvim_cmd({ cmd = "clearjumps" }, {})
            end
        end

        if cur_pos then
            if already_open then
                api.nvim_cmd({ cmd = "normal", args = { "m'" }, bang = true }, {})
            end

            require("nvim-tools").win.protected_set_cursor(cur_pos, { win = win })
        end

        if opts.do_zzze then
            api.nvim_cmd({ cmd = "normal", args = { "zzze" }, bang = true }, {})
        end

        local fold_cmd = opts.fold_cmd
        if fold_cmd then
            api.nvim_cmd({ cmd = "normal", args = { fold_cmd }, bang = true }, {})
        end
    end)

    if opts.focus and not cur_pos then
        api.nvim_set_current_win(win)
    end
end
-- TODO: Look at edit C code. Anything I'm missing?
-- TODO: Is the cur_win check necessary? Wouldn't/shouldn't the API do this check internally?
-- TODO: Add error handling
-- TODO: Does opening a buf set the pcmark by default?
-- MAYBE: Have a noautocmd opt and run this using vim._with

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

---@param buf integer
---@return boolean, string|nil, string|nil
function M.save(buf)
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
    if not opts.force then
        if M.is_empty_noname_buf(buf) then
            opts.force = true
        else
            local ok, err = M.save(buf)
            if not ok then
                return ok, err, "ErrorMsg"
            end
        end
    end

    return M.protected_del(buf, delist, opts)
end

return M

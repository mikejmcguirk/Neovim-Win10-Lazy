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
-- TODO: This function does too much. Fundamentally, we need to address two cases:
-- - Creating a "scratch" buffer, which has weird properties about filetype and what can drop
-- into it.
-- - Creating temporary buffers to open new windows and tabs, because it makes a lot of other
-- processes more sane.

---@param buf uinteger
---@return string
function M.bcd_get(buf)
    if fn.has("nvim-0.13") == 1 then
        return fn.getcwd(-1, -1, buf)
    else
        return fn.fnamemodify(api.nvim_buf_get_name(buf), ":h")
    end
end
-- TODO-DEP: Remove this when 0.14 comes out.

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
---@return uinteger[]
function M.bufs_get_listed()
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
        local listed_bufs = M.bufs_get_listed()
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
---@param range nvim-tools.Range
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

---@audited 2026-08-07
---@param bufname string
---@return uinteger
function M.bufname_to_bufnr(bufname)
    return fn.bufadd(fs.normalize(fn.fnamemodify(bufname, ":p")))
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

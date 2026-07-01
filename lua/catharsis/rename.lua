local api = vim.api
local fn = vim.fn
local lsp = vim.lsp
local util = lsp.util
local uv = vim.uv

---------------------
-- MARK: Constants --
---------------------

local PREP_RN = "textDocument/prepareRename"
local REFS = "textDocument/references"
local RENAME = "textDocument/rename"

-----------------
-- MARK: State --
-----------------

---@class (exact) catharsis.rename.Session
---@field cmdline string
---@field cmdpos uinteger
---@field cur_pos_idx uinteger
---@field cur_win uinteger
---@field cur_win_info catharsis.rename.WinInfo
---@field ref_win_info table<uinteger, catharsis.rename.WinInfo>
---@field symbol_len uinteger

-- LOW: It would be better for the ranges before and after the cursor to be stored separately
-- to avoid tortured iteration code. But this also means that the current win data can't be
-- stored as a WinInfo struct.

---@class (exact) catharsis.rename.WinInfo
---@field buf uinteger
---@field ns_dim uinteger
---@field ns_dynamic uinteger
---@field ranges nvim-tools.range.BufRange[]

local state_ns_cur_pos = api.nvim_create_namespace("catharsis.rename.cur_pos")
local state_ns_dims = {} ---@type uinteger[]
local state_ns_dynamics = {} ---@type uinteger[]
local state_req_prep_rn_timer = assert(uv.new_timer())
local state_req_refs_id = nil ---@type uinteger?

local ns_basename = "catharsis.rename"
local ns_basename_dim = ns_basename .. ".dim"
local ns_basename_dynamic = ns_basename .. ".dynamic"

---@param session catharsis.rename.Session
local function clear_dim_namespaces(session)
    local cur_buf = session.cur_win_info.buf
    local cur_win_ns_dim = session.cur_win_info.ns_dim
    api.nvim_buf_clear_namespace(cur_buf, cur_win_ns_dim, 0, -1)
    for _, info in pairs(session.ref_win_info) do
        api.nvim_buf_clear_namespace(info.buf, info.ns_dim, 0, -1)
    end
end

---@param session catharsis.rename.Session
local function clear_win_dynamic_namespaces(session)
    local cur_buf = session.cur_win_info.buf
    local cur_win_ns_dynamic = session.cur_win_info.ns_dynamic
    api.nvim_buf_clear_namespace(cur_buf, cur_win_ns_dynamic, 0, -1)
    for _, info in pairs(session.ref_win_info) do
        api.nvim_buf_clear_namespace(info.buf, info.ns_dynamic, 0, -1)
    end
end

---@param total_needed uinteger
local function ns_ensure(total_needed)
    local ns_needed_dim = total_needed - #state_ns_dims
    if ns_needed_dim > 0 then
        for _ = 1, ns_needed_dim do
            local ns_name_new = ns_basename_dim .. "." .. tostring(#state_ns_dims + 1)
            -- TODO: not the same as the dim ones
            state_ns_dims[#state_ns_dims + 1] = api.nvim_create_namespace(ns_name_new)
        end
    end

    local ns_needed_dynamic = total_needed - #state_ns_dynamics
    if ns_needed_dynamic > 0 then
        local ns_dynamics_len = #state_ns_dynamics
        for i = 1, ns_needed_dynamic do
            local idx_new = ns_dynamics_len + i
            local ns_name_new = ns_basename_dynamic .. "." .. tostring(idx_new)
            state_ns_dynamics[idx_new] = api.nvim_create_namespace(ns_name_new)
        end
    end
end

---@param win uinteger
---@param ranges nvim-tools.range.BufRange[]
---@return nvim-tools.range.BufRange[]
local function ranges_extract_for_win(win, ranges)
    local ranges_len = #ranges
    if ranges_len == 0 then
        return {}
    end

    local top = fn.line("w0", win) - 1
    local bot = fn.line("w$", win) - 1
    local vim_list_bisect = vim.list.bisect
    local lo = vim_list_bisect(ranges, { top, 0, 0, 0, 0 }, {
        key = function(r)
            return r[1]
        end,
    })

    if ranges_len < lo then
        return {}
    end

    local hi = vim_list_bisect(ranges, { 0, 0, bot, 0, 0 }, {
        bound = "upper",
        key = function(r)
            return r[3]
        end,
    })

    if hi < lo then
        return {}
    end

    return require("nvim-tools.table").i_splice_to(ranges, lo, hi)
end
-- LOW: Use a bespoke bisect function that doesn't require turning top and bot into tables.

---@param session catharsis.rename.Session
local function ns_clear(session)
    local cur_win_info = session.cur_win_info
    local cur_win_buf = cur_win_info.buf
    api.nvim_buf_clear_namespace(cur_win_buf, state_ns_cur_pos, 0, -1)
    api.nvim_buf_clear_namespace(cur_win_buf, cur_win_info.ns_dim, 0, -1)
    api.nvim_buf_clear_namespace(cur_win_buf, cur_win_info.ns_dynamic, 0, -1)

    for _, info in pairs(session.ref_win_info) do
        local info_buf = info.buf
        api.nvim_buf_clear_namespace(info_buf, info.ns_dim, 0, -1)
        api.nvim_buf_clear_namespace(info_buf, info.ns_dynamic, 0, -1)
    end
end

---@param win uinteger
---@param buf uinteger
---@return catharsis.rename.Session
local function session_create(win, buf)
    ns_ensure(1)
    local ns_dim = state_ns_dims[1]
    local ns_dynamic = state_ns_dynamics[1]
    api.nvim__ns_set(ns_dim, { wins = { win } })
    api.nvim__ns_set(ns_dynamic, { wins = { win } })

    return {
        cmdline = "",
        cmdpos = 0,
        cur_pos_idx = 0,
        cur_win = win,
        cur_win_info = {
            buf = buf,
            ns_dim = ns_dim,
            ns_dynamic = ns_dynamic,
            ranges = {},
        },
        ref_win_info = {},
        symbol_len = 0,
    }
end

---@param session catharsis.rename.Session
---@param ranges nvim-tools.range.BufRange[]
---@param cur_pos_idx uinteger
local function session_add_cur_win_ranges(session, ranges, cur_pos_idx)
    local cur_pos_range = ranges[cur_pos_idx]
    session.symbol_len = cur_pos_range[4] - cur_pos_range[2]
    session.cur_pos_idx = cur_pos_idx
    session.cur_win_info.ranges = ranges
end
-- TODO: Can more of the determining logic be put into here

---@param session catharsis.rename.Session
---@param cur_pos_ext [uinteger, uinteger]
---@param ref_wins uinteger[]
---@param win_bufs table<uinteger, uinteger>
---@param buf_ranges table<uinteger, nvim-tools.range.BufRange[]>
---@return boolean, string
local function session_set_from_refs(session, cur_pos_ext, ref_wins, win_bufs, buf_ranges)
    local cur_win = session.cur_win
    local cur_win_buf_ranges = buf_ranges[win_bufs[cur_win]]

    -- A valid response includes all references the server can find, which would include the
    -- original text document position. This module includes declaration and does not stream
    -- results. Errors/empty results should have already been handled.
    local cur_win_ranges = ranges_extract_for_win(cur_win, cur_win_buf_ranges)
    if 0 == #cur_win_ranges then
        return false, "No references in request origin window."
    end

    local ntr = require("nvim-tools.range")
    local cur_pos_idx = ntr.find_pos(cur_win_ranges, cur_pos_ext)
    if cur_pos_idx == nil then
        return false, "No reference for the text document position."
    end

    session_add_cur_win_ranges(session, cur_win_ranges, cur_pos_idx)

    local wins_count = 1
    local ref_win_info = session.ref_win_info
    for _, win in ipairs(ref_wins) do
        local win_buf = win_bufs[win]
        local win_ranges = ranges_extract_for_win(win, buf_ranges[win_buf])
        if 0 < #win_ranges then
            wins_count = wins_count + 1
            ref_win_info[win] = {
                buf = win_buf,
                ns_dim = -1,
                ns_dynamic = -1,
                ranges = win_ranges,
            }
        end
    end

    ns_ensure(wins_count)
    local ns_idx = 2 -- The original win already owns idx one.
    for win, win_info in pairs(ref_win_info) do
        local ns_dim = state_ns_dims[ns_idx]
        local ns_preview = state_ns_dynamics[ns_idx]
        ns_idx = ns_idx + 1

        api.nvim__ns_set(ns_dim, { wins = { win } })
        api.nvim__ns_set(ns_preview, { wins = { win } })
        win_info.ns_dim = ns_dim
        win_info.ns_dynamic = ns_preview
    end

    return true, ""
end

------------------------------------
-- MARK: Hl Groups and Priorities --
------------------------------------

local hl_dim_priority = vim.hl.priorities.user + 2
local hl_padding_priority = hl_dim_priority - 1
local hl_priority_preview = hl_dim_priority + 1

do
    local new_fg, new_bg = require("nvim-tools.misc").cursor_hl_get()
    api.nvim_set_hl(0, "catharsisRenameCursor", { fg = new_fg, bg = new_bg, default = true })

    -- TODO-DEP: Remove this when 0.14 comes out.
    api.nvim_set_hl(0, "Dimmed", { default = true, link = "Comment" })

    api.nvim_set_hl(0, "catharsisRenameDim", { default = true, link = "Dimmed" })
    api.nvim_set_hl(0, "catharsisRenameNew", { default = true, link = "Substitute" })
    api.nvim_set_hl(0, "catharsisRenamePosNew", { default = true, link = "IncSearch" })
end

local hl_cursor = api.nvim_get_hl_id_by_name("catharsisRenameCursor")
local hl_dim = api.nvim_get_hl_id_by_name("catharsisRenameDim")
local hl_new = api.nvim_get_hl_id_by_name("catharsisRenameNew")
local hl_pos_new = api.nvim_get_hl_id_by_name("catharsisRenamePosNew")

local hl_error = api.nvim_get_hl_id_by_name("ErrorMsg")
local hl_norm = api.nvim_get_hl_id_by_name("Normal")
local hl_warn = api.nvim_get_hl_id_by_name("WarningMsg")

---------------------------------------
-- MARK: Preview Management Autocmds --
---------------------------------------

---@param win_info catharsis.rename.WinInfo
local function marks_dim_set_from_info(win_info)
    local ranges = win_info.ranges
    local ranges_len = #ranges
    local buf = win_info.buf
    local ns = win_info.ns_dim
    for i = 1, ranges_len do
        local range = ranges[i]
        api.nvim_buf_set_extmark(buf, ns, range[1], range[2], {
            end_row = range[3],
            end_col = range[4],
            hl_group = hl_dim,
            priority = hl_dim_priority,
        })
    end
end

---@param session catharsis.rename.Session
local function marks_dim_new(session)
    clear_dim_namespaces(session)
    marks_dim_set_from_info(session.cur_win_info)
    for _, info in pairs(session.ref_win_info) do
        marks_dim_set_from_info(info)
    end
end

---@param start_idx uinteger
---@param end_idx uinteger
---@param ranges nvim-tools.range.BufRange[]
---@param buf uinteger
---@param ns uinteger
---@param padding string
local function marks_padding_iter_for_std(start_idx, end_idx, ranges, buf, ns, padding)
    for i = start_idx, end_idx do
        local range = ranges[i]
        api.nvim_buf_set_extmark(buf, ns, range[3], range[4], {
            virt_text = { { padding, hl_norm } },
            virt_text_pos = "inline",
            priority = hl_padding_priority,
        })
    end
end

---@param start_idx uinteger
---@param end_idx uinteger
---@param ranges nvim-tools.range.BufRange[]
---@param buf uinteger
---@param ns uinteger
---@param new_text string
local function marks_preview_iter_new_text(start_idx, end_idx, ranges, buf, ns, new_text)
    for i = start_idx, end_idx do
        local range = ranges[i]
        api.nvim_buf_set_extmark(buf, ns, range[1], range[2], {
            priority = hl_priority_preview,
            virt_text = { { new_text, hl_new } },
            virt_text_pos = "overlay",
        })
    end
end

---@param cmdline string
---@param cmdpos uinteger
---@return string, string, string, string, boolean
local function preview_text_parts_get(cmdline, cmdpos)
    local text_before = string.sub(cmdline, 1, cmdpos - 1)
    local text_at = string.sub(cmdline, cmdpos, cmdpos)
    local text_after = string.sub(cmdline, cmdpos + 1, #cmdline)
    local ext_at = false
    if text_at == "" then
        text_at = " " -- Cursor after line. Draw a block.
        ext_at = true
    end

    return cmdline, text_before, text_at, text_after, ext_at
end

---@param session catharsis.rename.Session
---@param t_before string
---@param t_at string
---@param t_after string
---@param padding_len uinteger
---@param ext_at boolean
local function marks_cur_pos_refresh(session, t_before, t_at, t_after, padding_len, ext_at)
    local cur_win_info = session.cur_win_info
    local buf = cur_win_info.buf
    local range = cur_win_info.ranges[session.cur_pos_idx]
    api.nvim_buf_set_extmark(buf, state_ns_cur_pos, range[1], range[2], {
        priority = hl_priority_preview,
        virt_text = {
            { t_before, hl_pos_new },
            { t_at, hl_cursor },
            { t_after, hl_pos_new },
        },
        virt_text_pos = "overlay",
    })

    local padding_len_cur_pos = ext_at and padding_len + 1 or padding_len
    if padding_len_cur_pos == 0 then
        return
    end

    local padding_cur_pos = string.rep(" ", padding_len_cur_pos)
    api.nvim_buf_set_extmark(buf, state_ns_cur_pos, range[3], range[4], {
        virt_text = { { padding_cur_pos, hl_norm } },
        virt_text_pos = "inline",
        priority = hl_padding_priority,
    })
end

---@param session catharsis.rename.Session
local function marks_dynamic_refresh_cursor(session)
    local cmdline = fn.getcmdline()
    local cmdpos = fn.getcmdpos()
    -- Check because this fires after CmdLineChanged
    if cmdline == session.cmdline and cmdpos == session.cmdpos then
        return
    end

    local t_new, t_before, t_at, t_after, ext_at = preview_text_parts_get(cmdline, cmdpos)
    local padding_len = #t_new - session.symbol_len

    api.nvim_buf_clear_namespace(session.cur_win_info.buf, state_ns_cur_pos, 0, -1)
    marks_cur_pos_refresh(session, t_before, t_at, t_after, padding_len, ext_at)
    session.cmdline = cmdline
    session.cmdpos = cmdpos
end

---@param session catharsis.rename.Session
local function marks_dynamic_refresh_all(session)
    clear_win_dynamic_namespaces(session)

    local cmdline = fn.getcmdline()
    local cmdpos = fn.getcmdpos()
    local t_new, t_before, t_at, t_after, ext_at = preview_text_parts_get(cmdline, cmdpos)
    local padding_len = #t_new - session.symbol_len

    -- Skip checking session data because this should fire before CursorMovedC
    api.nvim_buf_clear_namespace(session.cur_win_info.buf, state_ns_cur_pos, 0, -1)
    marks_cur_pos_refresh(session, t_before, t_at, t_after, padding_len, ext_at)
    session.cmdline = cmdline
    session.cmdpos = cmdpos

    if #t_new == 0 then
        return
    end

    local cur_pos_idx = session.cur_pos_idx
    local cur_win_info = session.cur_win_info
    local ranges = cur_win_info.ranges
    local buf = cur_win_info.buf
    local ns_dynamic = cur_win_info.ns_dynamic
    marks_preview_iter_new_text(1, cur_pos_idx - 1, ranges, buf, ns_dynamic, t_new)
    marks_preview_iter_new_text(cur_pos_idx + 1, #ranges, ranges, buf, ns_dynamic, t_new)

    for _, win_info in pairs(session.ref_win_info) do
        local info_ranges = win_info.ranges
        local info_buf = win_info.buf
        local ns = win_info.ns_dynamic
        marks_preview_iter_new_text(1, #info_ranges, info_ranges, info_buf, ns, t_new)
    end

    if padding_len == 0 then
        return
    end

    local padding = string.rep(" ", padding_len)
    marks_padding_iter_for_std(1, cur_pos_idx - 1, ranges, buf, ns_dynamic, padding)
    marks_padding_iter_for_std(cur_pos_idx + 1, #ranges, ranges, buf, ns_dynamic, padding)

    for _, win_info in pairs(session.ref_win_info) do
        local info_ranges = win_info.ranges
        local info_buf = win_info.buf
        local info_ns = win_info.ns_dynamic
        marks_padding_iter_for_std(1, #info_ranges, info_ranges, info_buf, info_ns, padding)
    end
end

local group_name = "catharsis.rename"

---@param session catharsis.rename.Session
local function preview_listener_init(session)
    -- Re-create the group in case the previous del_autocmd failed to run.
    local group = api.nvim_create_augroup(group_name, {})
    api.nvim_create_autocmd("CmdlineChanged", {
        group = group,
        callback = function()
            marks_dynamic_refresh_all(session)
        end,
    })

    api.nvim_create_autocmd("CursorMovedC", {
        -- Re-create the group in case the previous del_autocmd failed to run.
        group = group,
        callback = function()
            marks_dynamic_refresh_cursor(session)
        end,
    })

    marks_dim_new(session)
end

local function preview_listener_stop()
    for _, autocmd in ipairs(api.nvim_get_autocmds({ group = group_name })) do
        local id = autocmd.id
        if id ~= nil then
            api.nvim_del_autocmd(id)
        end
    end
end

---------------------
-- MARK: Do Rename --
---------------------

---@param client vim.lsp.Client
---@param buf uinteger
---@param cur_pos_ext [uinteger, uinteger]
---@param new_name string
local function rename_do(client, buf, cur_pos_ext, new_name)
    local encoding = client.offset_encoding
    local nts = require("nvim-tools.lsp")
    local params = nts.rename_params_create(buf, cur_pos_ext, encoding, new_name)
    -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocument_rename
    client:request(RENAME, params, function(err, result, _)
        if err ~= nil then
            local msg = err.code .. ": " .. err.message .. "(" .. vim.inspect(err.data) .. ")"
            require("nvim-tools.lsp").log_and_echo(msg, 4, hl_error, true)
            return
        end

        if result == nil then
            local msg = "Language server did not provide rename result"
            require("nvim-tools.lsp").log_and_echo(msg, 2, "", false)
            return
        end

        util.apply_workspace_edit(result, encoding)
    end, buf)
end
-- MID: Unsure what an empty table result means or how to handle it.

--------------------------
-- MARK: Get References --
--------------------------

---@param ctx lsp.HandlerContext
---@param req_id uinteger
---@param client_id uinteger
---@return boolean, vim.lsp.Client?, mjm.lsp.HandlerContext_Validated?
local function req_refs_handler_ctx_check(ctx, req_id, client_id)
    local request_id = ctx.request_id
    if not (request_id and request_id == req_id) then
        return false
    end

    if ctx.client_id ~= client_id then
        return false
    end

    local client = lsp.get_client_by_id(client_id)
    if not client then
        return false
    end

    return true, client, ctx --[[@as mjm.lsp.HandlerContext_Validated]]
end

---@param err lsp.ResponseError?
---@param result lsp.Location[]
---@param ctx lsp.HandlerContext
---@param client_id uinteger
---@param session catharsis.rename.Session
---@param cur_pos_ext [uinteger, uinteger]
local function req_refs_handler(err, result, ctx, client_id, session, cur_pos_ext)
    local req_id = state_req_refs_id
    state_req_refs_id = nil
    if req_id == nil then
        return
    end

    local ok, client, ctx_validated = req_refs_handler_ctx_check(ctx, req_id, client_id)
    if ok == false or client == nil or ctx_validated == nil then
        return
    end

    if err ~= nil then
        -- No echo because it causes hl previews to freeze in legacy ui.
        lsp.log.error(err.code .. ": " .. err.message .. "(" .. vim.inspect(err.data) .. ")")
        return
    end

    if result == nil or #result == 0 then
        -- Valid per the spec.
        return
    end

    local cur_win = session.cur_win
    local ref_wins = api.nvim_tabpage_list_wins(0)
    local ntt = require("nvim-tools.table")
    ntt.i_discard(ref_wins, function(win)
        return win == cur_win
            or vim.call("win_gettype", win) ~= ""
            or api.nvim_win_get_config(win).hide == true
    end)

    local win_bufs = ntt.rebuild_to(ref_wins, function(_, ref_win)
        return ref_win, api.nvim_win_get_buf(ref_win)
    end)
    win_bufs[cur_win] = session.cur_win_info.buf

    local nts = require("nvim-tools.lsp")
    local encoding = client.offset_encoding
    ---@type table<uinteger, true>
    ---@diagnostic disable-next-line: assign-type-mismatch
    local bufs = ntt.rebuild_to(win_bufs, function(_, buf)
        return buf, true
    end)

    local buf_ranges = nts.locations_to_api_ranges_by_buf(result, encoding, bufs)
    if next(buf_ranges) == nil then
        return
    end

    local ok_r, err_r = session_set_from_refs(session, cur_pos_ext, ref_wins, win_bufs, buf_ranges)
    if not ok_r then
        -- DOC: Document this behavior, so users can check the logs with level warning.
        -- Do not echo because it siezes up highlights in legacy UI.
        lsp.log.warn(err_r)
        return
    end

    marks_dim_new(session)
    marks_dynamic_refresh_all(session)
    api.nvim__redraw({ flush = true, valid = true })
end

---@param client vim.lsp.Client
local function ref_req_checked_clear(client)
    local req_refs_id = state_req_refs_id
    if req_refs_id == nil then
        return
    end

    client:cancel_request(req_refs_id)
    state_req_refs_id = nil
end

---https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocument_references
---@param client vim.lsp.Client
---@param session catharsis.rename.Session
---@param cur_pos_ext [uinteger, uinteger]
local function ref_req_create(client, session, cur_pos_ext)
    local buf = session.cur_win_info.buf
    local nts = require("nvim-tools.lsp")
    local encoding = client.offset_encoding
    local params = nts.references_params_create(buf, cur_pos_ext, encoding, true)
    local req_success, req_id = client:request(REFS, params, function(err, results, ctx)
        req_refs_handler(err, results, ctx, client.id, session, cur_pos_ext)
    end, buf)

    if req_success == true and req_id ~= nil then
        state_req_refs_id = req_id
    else
        -- Don't echo because it freezes previews on legacy UI.
        lsp.log.debug("References request unsuccessful")
    end
end
-- MID: Send a partial result token and handle the streaming results.

----------------------------
-- MARK: Get Rename Input --
----------------------------

---@param client vim.lsp.Client
---@param session catharsis.rename.Session
---@param cur_pos_ext [uinteger, uinteger]
---@param default string
---@parma preferred boolean
local function rename_get_input(client, session, cur_pos_ext, default, preferred)
    preview_listener_init(session)
    if preferred then
        ref_req_create(client, session, cur_pos_ext)
    end

    local prompt_opts = { default = default, prompt = "New Name: ", scope = "cursor" }
    local ok, text = require("nvim-tools.ui").input(prompt_opts)

    ref_req_checked_clear(client)
    preview_listener_stop()
    ns_clear(session)

    if text == "" then
        return
    elseif ok == false then
        local msg = text or ""
        api.nvim_echo({ { "Input error: " .. msg, hl_error } }, true, {})
        return
    end

    rename_do(client, session.cur_win_info.buf, cur_pos_ext, text)
end
-- MID: Use `input()`'s highlighting for better aesthetics.

-------------------------------
-- MARK: prepareRename Handling
-------------------------------

---@param ctx lsp.HandlerContext
---@param buf uinteger
---@return boolean, vim.lsp.Client?, mjm.lsp.HandlerContext_Validated?
local function req_prep_rn_handler_check_ctx(ctx, buf)
    local resp_buf = ctx.bufnr
    if not (resp_buf and resp_buf == buf) then
        return false
    end

    local ctx_version = ctx.version
    if not (ctx_version and ctx_version == util.buf_versions[resp_buf]) then
        return false
    end

    local client_id = ctx.client_id
    local client = lsp.get_client_by_id(client_id)
    if not client then
        return false
    end

    return true, client, ctx --[[@as mjm.lsp.HandlerContext_Validated]]
end

---@param err lsp.ResponseError?
---@param result (lsp.Range|{ range: lsp.Range, placeholder: string }|{ defaultBehavior: boolean })?
---@param ctx lsp.HandlerContext
---@param session catharsis.rename.Session
---@param cur_pos_ext [uinteger, uinteger]
---@param prompt_default boolean
local function req_prep_rn_handler(err, result, ctx, session, cur_pos_ext, prompt_default)
    if uv.is_active(state_req_prep_rn_timer) then
        uv.timer_stop(state_req_prep_rn_timer)
    else
        lsp.log.info("prepareRename request arrived after timeout.")
        return
    end

    local buf = session.cur_win_info.buf
    local ok, client, ctx_validated = req_prep_rn_handler_check_ctx(ctx, buf)
    if ok == false or buf == nil or client == nil or ctx_validated == nil then
        return
    end

    if err ~= nil then
        local msg = "Error on prepareRename: " .. (err.message or "")
        require("nvim-tools.lsp").log_and_echo(msg, 4, hl_error, true)
        return
    end

    if result == nil then
        local msg = "Nothing to rename."
        require("nvim-tools.lsp").log_and_echo(msg, 2, "", false)
        return
    end

    local default_range
    local encoding = client.offset_encoding
    -- MID-DEP: If I have occasion to make a single-range LSP > API function, use here.
    if result.range then
        default_range = vim.range.lsp(buf, result.range, encoding)
    elseif result.start then
        default_range = vim.range.lsp(buf, result, encoding)
    else
        -- Likely a PrepareRenameDefaultBehavior response.
        local ntb = require("nvim-tools.buf")
        default_range = ntb.line_match_under_cursor(cur_pos_ext, buf, [[\k\+]])
    end

    if default_range == nil then
        api.nvim_echo({ { "No range to rename", hl_warn } }, false, {})
        return
    end

    local ntb = require("nvim-tools.buf")
    local default = prompt_default and ntb.text_from_range(default_range, buf) or ""
    session_add_cur_win_ranges(session, { default_range }, 1)
    rename_get_input(client, session, cur_pos_ext, default, true)
end

-----------------------
-- MARK: Dispatching --
-----------------------

---@param buf uinteger
---@param filter fun(client:vim.lsp.Client): boolean
---@return uinteger?, vim.lsp.Client?, boolean
---Client id, client, preferred client (supports prepareRename and references)
local function client_find(buf, filter)
    local clients = lsp.get_clients({ bufnr = buf })
    local ntt = require("nvim-tools.table")
    ntt.i_keep(clients, filter)
    if #clients == 0 then
        return nil, nil, false
    end

    local nts = require("nvim-tools.lsp")
    local all_methods = { PREP_RN, REFS, RENAME }
    local id, client = nts.clients_find_top_scoring(clients, buf, all_methods)
    if id == nil or client == nil then
        id, client = nts.clients_find_top_scoring(clients, buf, { RENAME })
        return id, client, false
    end

    return id, client, true
end
-- MID-DEP: Revisit if there's a typical multi-server situation this handles poorly.

---@class catharsis.rename.Opts
---(Default: `nil`) Predicate to filter clients. Clients matching the predicate are included.
---@field filter? fun(client:vim.lsp.Client): boolean
---(Default: `nil`) If provided, immediately send the rename request.
---@field new_name? string
---(Default: `true`) Provide a default name in the prompt? If true, the LSP suggestion will be
---used if provided, falling back to the |<cword>| under the cursor.
---@field prompt_default? boolean

---@nodoc
---@class (private) catharsis.rename.Ctx
---@field filter fun(client:vim.lsp.Client): boolean
---@field new_name string?
---@field prompt_default boolean

---@param opts? catharsis.rename.Opts
---@return catharsis.rename.Ctx
local function opts_to_ctx(opts)
    if opts == nil then
        opts = {}
    else
        vim.validate("opts", opts, "table")
        opts = vim.deepcopy(opts)
    end

    if opts.filter == nil then
        opts.filter = function(_)
            return true
        end
    else
        vim.validate("opts.filter", opts.filter, "callable")
    end

    vim.validate("opts.new_name", opts.new_name, "string", true)
    if opts.prompt_default == nil then
        opts.prompt_default = true
    else
        vim.validate("opts.prompt_default", opts.prompt_default, "boolean")
    end

    return opts --[[@as catharsis.rename.Ctx]]
end

local M = {}

---Rename all references to the symbol under the cursor.
---@param opts? catharsis.rename.Opts
function M._dispatcher(opts)
    local nts = require("nvim-tools.lsp")
    if uv.is_active(state_req_prep_rn_timer) then
        nts.log_and_echo("prepareRename request currently active.", 2, "", true)
        return
    end

    local opts_ctx = opts_to_ctx(opts)
    local cur_win = api.nvim_get_current_win()
    api.nvim__ns_set(state_ns_cur_pos, { wins = { cur_win } })
    local cur_buf = api.nvim_win_get_buf(cur_win)
    local client_id, client, preferred = client_find(cur_buf, opts_ctx.filter)
    if client_id == nil or client == nil then
        local msg = "No clients supporting textDocument/rename were found"
        nts.log_and_echo(msg, 3, hl_warn, true)
        return
    end

    local ntp = require("nvim-tools.pos")
    local cur_pos_ext = ntp.mark_to_ext_pos(api.nvim_win_get_cursor(cur_win))
    local new_name = opts_ctx.new_name
    if new_name ~= nil then
        rename_do(client, cur_buf, cur_pos_ext, new_name)
        return
    end

    local session = session_create(cur_win, cur_buf)
    local prompt_default = opts_ctx.prompt_default
    if not preferred then
        local ntb = require("nvim-tools.buf")
        local cword_range = ntb.line_match_under_cursor(cur_pos_ext, cur_buf, [[\k\+]])
        if cword_range == nil then
            api.nvim_echo({ { "No range to rename", hl_warn } }, false, {})
            return
        end

        local default = prompt_default and ntb.text_from_range(cword_range, cur_buf) or ""
        session_add_cur_win_ranges(session, { cword_range }, 1)
        rename_get_input(client, session, cur_pos_ext, default, preferred)
        return
    end

    local encoding = client.offset_encoding
    local params = nts.text_doc_pos_params_create(cur_buf, cur_pos_ext, encoding)
    -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocument_prepareRename
    local req_success, req_id = client:request(PREP_RN, params, function(err, result, ctx)
        req_prep_rn_handler(err, result, ctx, session, cur_pos_ext, prompt_default)
    end, cur_buf)

    if req_success and req_id then
        uv.timer_start(
            state_req_prep_rn_timer,
            5000,
            0,
            vim.schedule_wrap(function()
                nts.log_warn_and_echo("prepareRename timed out")
            end)
        )
    end
end

return M

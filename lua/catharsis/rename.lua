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

local HUGE_INT = math.floor(math.huge)

-----------------
-- MARK: State --
-----------------

---@class (exact) catharsis.rename.Session
---@field buf_ranges table<uinteger, nvim-tools.range.BufRange[]>
---@field cur_pos_idx uinteger
---@field cur_win uinteger
---@field cur_win_info catharsis.rename.WinInfo
---@field mark_cursor_preview uinteger
---@field mark_cursor_padding uinteger
---@field ref_win_info table<uinteger, catharsis.rename.WinInfo>
---@field symbol_len uinteger

---@class (exact) catharsis.rename.WinInfo
---@field bot uinteger 0-indexed
---@field bot_idx -1|uinteger
---@field buf -1|uinteger
---@field ns_dim -1|uinteger
---@field ns_dynamic -1|uinteger
---@field top uinteger 0-indexed
---@field top_idx -1|uinteger

local state_ns_dims = {} ---@type uinteger[]
local state_ns_dynamics = {} ---@type uinteger[]
local state_req_prep_rn_timer = assert(uv.new_timer())
local state_req_refs_id = nil

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
local function clear_dynamic_preview_namespaces(session)
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

---@param ranges nvim-tools.range.BufRange[]
---@param top uinteger
---@param bot uinteger
---@return uinteger, uinteger
local function win_iters_get(ranges, top, bot)
    local ranges_len = #ranges
    if ranges_len == 0 then
        return 0, 0
    end

    local lo = vim.list.bisect(ranges, { top }, {
        key = function(r)
            return r[1]
        end,
    })

    if lo > ranges_len then
        return 0, 0
    end

    local hi = vim.list.bisect(ranges, { 0, 0, bot }, {
        bound = "upper",
        key = function(r)
            return r[3]
        end,
    })

    if hi < lo then
        return 0, 0
    end

    return lo, hi - 1
end
-- TODO: This needs the re-written, generic bisect function that takes two keys.
-- I would use list.bisect() as the base so try and make the logic less removed.

---@param session catharsis.rename.Session
local function ns_clear(session)
    local cur_win_info = session.cur_win_info
    local cur_win_buf = cur_win_info.buf
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
        buf_ranges = {},
        cur_pos_idx = 0,
        cur_win = win,
        cur_win_info = {
            bot = vim.call("line", "w$", win) - 1,
            bot_idx = HUGE_INT,
            buf = buf,
            mark_preview_cursor = -1,
            mark_preview_padding = -1,
            ns_dim = ns_dim,
            ns_dynamic = ns_dynamic,
            top = vim.call("line", "w0", win) - 1,
            top_idx = -1,
        },
        ref_win_info = {},
        symbol_len = 0,
    }
end

---@param session catharsis.rename.Session
---@param range nvim-tools.range.BufRange
local function session_add_symbol_range(session, range)
    session.symbol_len = range[4] - range[2]
    local cur_win_info = session.cur_win_info
    local cur_buf = cur_win_info.buf
    session.buf_ranges[cur_buf] = { range }

    session.cur_pos_idx = 1
    cur_win_info.bot_idx = 1
    cur_win_info.top_idx = 1
end

---@param session catharsis.rename.Session
---@param cur_pos_ext [uinteger, uinteger]
---@param ref_wins uinteger[]
---@param win_bufs table<uinteger, uinteger>
---@param buf_ranges table<uinteger, nvim-tools.range.BufRange>
local function session_set_from_refs(session, cur_pos_ext, ref_wins, win_bufs, buf_ranges)
    session.buf_ranges = buf_ranges
    buf_ranges = session.buf_ranges
    local cur_win_buf = win_bufs[session.cur_win]
    local ntr = require("nvim-tools.range")

    session.cur_pos_idx = assert(ntr.find_pos(buf_ranges[cur_win_buf], cur_pos_ext))
    local cur_win_top = session.cur_win_info.top
    local cur_win_bot = session.cur_win_info.bot
    local cur_win_top_idx, cur_win_bot_idx =
        win_iters_get(buf_ranges[cur_win_buf], cur_win_top, cur_win_bot)
    session.cur_win_info.top_idx = cur_win_top_idx
    session.cur_win_info.bot_idx = cur_win_bot_idx

    local wins_count = 1
    local ref_win_info = session.ref_win_info
    for _, win in ipairs(ref_wins) do
        local win_buf = win_bufs[win]
        local ranges = buf_ranges[win_buf]
        if ranges then
            local top = fn.line("w0", win) - 1
            local bot = fn.line("w$", win) - 1
            local top_idx, bot_idx = win_iters_get(ranges, top, bot)
            if top_idx > 0 and bot_idx > 0 then
                session.buf_ranges[win_buf] = ranges
                wins_count = wins_count + 1
                ref_win_info[win] = {
                    bot = bot,
                    bot_idx = bot_idx,
                    buf = win_buf,
                    ns_dim = -1,
                    ns_dynamic = -1,
                    top = top,
                    top_idx = top_idx,
                }
            end
        end
    end

    ns_ensure(wins_count)
    local ns_idx = 2 -- The original win already owns idx one.
    for win, win_info in pairs(session.ref_win_info) do
        local ns_dim = state_ns_dims[ns_idx]
        local ns_preview = state_ns_dynamics[ns_idx]
        ns_idx = ns_idx + 1

        api.nvim__ns_set(ns_dim, { wins = { win } })
        api.nvim__ns_set(ns_preview, { wins = { win } })
        win_info.ns_dim = ns_dim
        win_info.ns_dynamic = ns_preview
    end
end

------------------------------------
-- MARK: Hl Groups and Priorities --
------------------------------------

local hl_dim_priority = vim.hl.priorities.user + 2
local hl_padding_priority = hl_dim_priority - 1
local hl_priority_preview = hl_dim_priority + 1

do
    local normal = api.nvim_get_hl(0, { name = "Normal", link = false }) or {}
    local orig_fg = normal.fg
    local orig_bg = normal.bg

    local new_fg = orig_bg ---@type integer|string?
    local new_bg = orig_fg ---@type integer|string?

    if not orig_bg then
        if orig_fg then
            new_bg = (vim.o.background == "dark") and "#EFEFEF" or "#1E1E1E"
        else
            new_fg = (vim.o.background == "dark") and "#222222" or "#EFEFEF"
            new_bg = (vim.o.background == "dark") and "#EFEFEF" or "#1E1E1E"
        end
    end

    if not new_fg then
        new_fg = (vim.o.background == "dark") and "#222222" or "#EFEFEF"
    end

    api.nvim_set_hl(0, "catharsisRenameCursor", { fg = new_fg, bg = new_bg, default = true })
end
-- TODO: This is still very vibe coded coded.
-- TODO: nvim-tools this since we need it for farsight.

-- TODO-DEP: Remove this when 0.14 comes out.
api.nvim_set_hl(0, "Dimmed", { default = true, link = "Comment" })

api.nvim_set_hl(0, "catharsisRenameDim", { default = true, link = "Dimmed" })
api.nvim_set_hl(0, "catharsisRenameNew", { default = true, link = "Substitute" })
api.nvim_set_hl(0, "catharsisRenamePosNew", { default = true, link = "IncSearch" })
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

---@param session catharsis.rename.Session
---@param win_info catharsis.rename.WinInfo
local function marks_dim_set_from_info(session, win_info)
    local buf = win_info.buf
    local ranges = session.buf_ranges[buf]
    local top_idx = win_info.top_idx
    local bot_idx = win_info.bot_idx
    local ns = win_info.ns_dim
    for i = top_idx, bot_idx do
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
    marks_dim_set_from_info(session, session.cur_win_info)
    for _, info in pairs(session.ref_win_info) do
        marks_dim_set_from_info(session, info)
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

---@param session catharsis.rename.Session
---@param padding string
local function marks_padding_set_ref_wins(session, padding)
    for _, win_info in pairs(session.ref_win_info) do
        local buf = win_info.buf
        local ranges = session.buf_ranges[buf]
        local top_idx = win_info.top_idx
        local bot_idx = win_info.bot_idx
        local ns = win_info.ns_dynamic
        marks_padding_iter_for_std(top_idx, bot_idx, ranges, buf, ns, padding)
    end
end

---@param session catharsis.rename.Session
---@param padding string
local function marks_padding_set_cur_win(session, padding)
    local cur_win_info = session.cur_win_info
    local buf = cur_win_info.buf
    local ns_dynamic = cur_win_info.ns_dynamic
    local ranges = session.buf_ranges[buf]
    local cur_pos_idx = session.cur_pos_idx

    local top_idx = cur_win_info.top_idx
    marks_padding_iter_for_std(top_idx, cur_pos_idx - 1, ranges, buf, ns_dynamic, padding)
    local bot_idx = cur_win_info.bot_idx
    marks_padding_iter_for_std(cur_pos_idx + 1, bot_idx, ranges, buf, ns_dynamic, padding)
end

---@param session catharsis.rename.Session
---@param cur_pos_padding string
local function marks_padding_set_cursor(session, cur_pos_padding)
    local cur_win_info = session.cur_win_info
    local buf = cur_win_info.buf
    local ns_dynamic = cur_win_info.ns_dynamic
    local cur_pos_range = session.buf_ranges[buf][session.cur_pos_idx]
    local id = api.nvim_buf_set_extmark(buf, ns_dynamic, cur_pos_range[3], cur_pos_range[4], {
        virt_text = { { cur_pos_padding, hl_norm } },
        virt_text_pos = "inline",
        priority = hl_padding_priority,
    })

    session.mark_cursor_padding = id
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

---@param session catharsis.rename.Session
---@param new_text string
local function marks_preview_set_ref_wins(session, new_text)
    if #new_text == 0 then
        return
    end

    for _, win_info in pairs(session.ref_win_info) do
        local buf = win_info.buf
        local ranges = session.buf_ranges[buf]
        local top_idx = win_info.top_idx
        local bot_idx = win_info.bot_idx
        local ns = win_info.ns_dynamic
        marks_preview_iter_new_text(top_idx, bot_idx, ranges, buf, ns, new_text)
    end
end

---@param session catharsis.rename.Session
---@param new_text string
local function marks_preview_set_cur_win(session, new_text)
    local cur_win_info = session.cur_win_info
    local buf = cur_win_info.buf
    local ns_dynamic = cur_win_info.ns_dynamic
    local ranges = session.buf_ranges[buf]
    local cur_pos_idx = session.cur_pos_idx

    local top_idx = cur_win_info.top_idx
    marks_preview_iter_new_text(top_idx, cur_pos_idx - 1, ranges, buf, ns_dynamic, new_text)
    local bot_idx = cur_win_info.bot_idx
    marks_preview_iter_new_text(cur_pos_idx + 1, bot_idx, ranges, buf, ns_dynamic, new_text)
end

---@param session catharsis.rename.Session
---@param text_before string
---@param text_at string
---@param text_after string
local function marks_preview_set_cursor(session, text_before, text_at, text_after)
    local cur_win_info = session.cur_win_info
    local buf = cur_win_info.buf
    local ns_dynamic = cur_win_info.ns_dynamic
    local cur_pos_range = session.buf_ranges[buf][session.cur_pos_idx]

    local id = api.nvim_buf_set_extmark(buf, ns_dynamic, cur_pos_range[1], cur_pos_range[2], {
        priority = hl_priority_preview,
        virt_text = {
            { text_before, hl_pos_new },
            { text_at, hl_cursor },
            { text_after, hl_pos_new },
        },
        virt_text_pos = "overlay",
    })

    session.mark_cursor_preview = id
end

---@return string, string, string, string, boolean
local function marks_dynamic_text_parts_get()
    local new_text = fn.getcmdline()
    local cmdpos = fn.getcmdpos()
    local text_before = string.sub(new_text, 1, cmdpos - 1)
    local text_at = string.sub(new_text, cmdpos, cmdpos)
    local text_after = string.sub(new_text, cmdpos + 1, #new_text)

    local ext_at = false
    if text_at == "" then
        text_at = " " -- Cursor after line. Draw a block.
        ext_at = true
    end

    return new_text, text_before, text_at, text_after, ext_at
end

---@param session catharsis.rename.Session
local function marks_dynamic_set_new_cursor(session)
    local cur_win_info = session.cur_win_info
    local cur_win_buf = cur_win_info.buf
    local ns_dynamic = cur_win_info.ns_dynamic
    local mark_cursor_preview = session.mark_cursor_preview
    if type(mark_cursor_preview) == "number" then
        api.nvim_buf_del_extmark(cur_win_buf, ns_dynamic, mark_cursor_preview)
    end

    local mark_cursor_padding = session.mark_cursor_padding
    if type(mark_cursor_padding) == "number" then
        api.nvim_buf_del_extmark(cur_win_buf, ns_dynamic, mark_cursor_padding)
    end

    local new_text, text_before, text_at, text_after, ext_at = marks_dynamic_text_parts_get()
    local padding_len_cur_pos = #new_text - session.symbol_len
    if ext_at then
        padding_len_cur_pos = padding_len_cur_pos + 1
    end

    marks_preview_set_cursor(session, text_before, text_at, text_after)
    if #new_text > 0 then
        marks_padding_set_cursor(session, string.rep(" ", padding_len_cur_pos))
    end
end

---@param session catharsis.rename.Session
local function marks_dynamic_set_new(session)
    clear_dynamic_preview_namespaces(session)
    local new_text, text_before, text_at, text_after, ext_at = marks_dynamic_text_parts_get()
    marks_preview_set_cursor(session, text_before, text_at, text_after)
    if #new_text == 0 then
        return
    end

    marks_preview_set_cur_win(session, new_text)
    marks_preview_set_ref_wins(session, new_text)
    local padding_len = #new_text - session.symbol_len
    local padding_len_cur_pos = padding_len
    if ext_at then
        padding_len_cur_pos = padding_len_cur_pos + 1
    end

    if padding_len_cur_pos > 0 then
        marks_padding_set_cursor(session, string.rep(" ", padding_len_cur_pos))
    end

    if padding_len > 0 then
        local padding = string.rep(" ", padding_len)
        marks_padding_set_cur_win(session, padding)
        marks_padding_set_ref_wins(session, padding)
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
            marks_dynamic_set_new(session)
        end,
    })

    api.nvim_create_autocmd("CursorMovedC", {
        -- Re-create the group in case the previous del_autocmd failed to run.
        group = group,
        callback = function()
            marks_dynamic_set_new_cursor(session)
        end,
    })

    marks_dim_new(session)
end
-- MID: These can double-fire. Not a *huge* deal since CursorMovedC only impacts the curosr
-- symbol, but still unnecessary. You would need to independently track the latest cmdtext
-- and cmdpos and use a data structure to mark which cmd has acted on it.

local function preview_listener_stop()
    for _, autocmd in ipairs(api.nvim_get_autocmds({ group = group_name })) do
        api.nvim_del_autocmd(autocmd.id)
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

        util.apply_workspace_edit(result, client.offset_encoding)
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
---@param result lsp.Location[]|lsp.LocationLink
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
    require("nvim-tools.table").i_discard(ref_wins, function(win)
        return win == cur_win
            or vim.call("win_gettype", win) ~= ""
            or api.nvim_win_get_config(win).hide == true
    end)

    ---@type table<uinteger, uinteger>
    local win_bufs = { [cur_win] = session.cur_win_info.buf }
    for _, ref_win in ipairs(ref_wins) do
        win_bufs[ref_win] = api.nvim_win_get_buf(ref_win)
    end

    local encoding = client.offset_encoding
    local bufs = {} ---@type table<uinteger, true>
    for _, buf in pairs(win_bufs) do
        bufs[buf] = true
    end

    local nts = require("nvim-tools.lsp")
    local buf_ranges = nts.ranges_from_locations_by_buf(result, encoding, bufs)
    if next(buf_ranges) == nil then
        return
    end

    session_set_from_refs(session, cur_pos_ext, ref_wins, win_bufs, buf_ranges)
    marks_dim_new(session)
    marks_dynamic_set_new(session)
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
    if not client:supports_method(REFS) then
        return
    end

    local buf = session.cur_win_info.buf
    local nts = require("nvim-tools.lsp")
    local encoding = client.offset_encoding
    local params = nts.reference_params_create(buf, cur_pos_ext, encoding, true)
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
local function rename_get_input(client, session, cur_pos_ext, default)
    local prompt_opts = { default = default, prompt = "New Name: ", scope = "cursor" }

    preview_listener_init(session)
    ref_req_create(client, session, cur_pos_ext)
    local nti = require("nvim-tools.ui")
    local ok, text = nti.input(prompt_opts)

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
---@param result (lsp.Range|{ range: lsp.Range, placeholder: string })?
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
    session_add_symbol_range(session, default_range)
    rename_get_input(client, session, cur_pos_ext, default)
end

-----------------------
-- MARK: Dispatching --
-----------------------

---@param buf uinteger
---@param finder catharsis.rename.opts.Finder
---@return uinteger?, vim.lsp.Client?, boolean
---Client id, client, supports prepareRename.
local function client_find(buf, finder)
    local all_clients = lsp.get_clients({ bufnr = buf, method = RENAME })
    local ntt = require("nvim-tools.table")
    if type(finder) == "string" then
        ntt.i_select(all_clients, finder, function(client)
            return client.name
        end)
    elseif type(finder) == "function" then
        ntt.i_keep(all_clients, finder)
    end

    if #all_clients == 0 then
        return nil, nil, false
    end

    local nts = require("nvim-tools.lsp")
    local preferred = ntt.i_copy(all_clients)
    nts.clients_filter_supporting_multiple(preferred, buf, { PREP_RN, REFS })
    if #preferred > 0 then
        local all_methods = { PREP_RN, REFS, RENAME }
        local client_id, client = nts.clients_find_top_scoring(preferred, all_methods, buf)
        if client_id ~= nil and client ~= nil then
            return client_id, client, true
        end
    end

    local client_id, client = nts.clients_find_top_scoring(all_clients, { RENAME }, buf)
    return client_id, client, false
end
-- MID-DEP: Can revisit this if there's a typical multi-server situation this handles poorly.

---@alias catharsis.rename.opts.Finder nil|string|fun(client:vim.lsp.Client): boolean

---@class catharsis.rename.Opts
---(Default: `nil`) Similar to `opts.filter` and `opts.name` in |vim.lsp.buf.rename()|.
---- If nil, find the best match client. From all attached to the buffer.
---- If a string, look for a client with a matching name.
---- If a function, only consider clients that pass the predicate.
---@field finder? catharsis.rename.opts.Finder
---(Default: `nil`) If provided, immediately send the rename request.
---@field new_name? string
---(Default: `true`) Provide a default name in the prompt? If true, the LSP suggestion will be
---used if provided. Otherwise, the |<cword>| under the cursor.
---@field prompt_default? boolean

---@nodoc
---@class (private) catharsis.rename.Ctx
---@field finder catharsis.rename.opts.Finder
---@field new_name string?
---@field prompt_default boolean

---@param opts? catharsis.rename.Opts
---@return catharsis.rename.Ctx
local function opts_to_ctx(opts)
    opts = opts and vim.deepcopy(opts) or {}
    vim.validate("opts", opts, "table")

    vim.validate("opts.finder", opts.finder, { "callable", "string" }, true)
    vim.validate("opts.new_name", opts.new_name, "string", true)
    if opts.prompt_default == nil then
        opts.prompt_default = true
    else
        vim.validate("opts.prompt_default", opts.prompt_default, "boolean")
    end

    return opts --[[@as catharsis.rename.Ctx]]
end
-- MID: Add highlight display options.

local M = {}

---Rename all references to the symbol under the cursor.
---@param opts? catharsis.rename.Opts
function M._dispatcher(opts)
    local nts = require("nvim-tools.lsp")
    if uv.is_active(state_req_prep_rn_timer) then
        nts.log_and_echo("prepareRename request currently active.", 3, hl_warn, true)
        return
    end

    local opts_ctx = opts_to_ctx(opts)
    local cur_win = api.nvim_get_current_win()
    local cur_buf = api.nvim_win_get_buf(cur_win)
    local client_id, client, supports_prep = client_find(cur_buf, opts_ctx.finder)
    if not (client_id ~= nil and client ~= nil) then
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
    if not supports_prep then
        local ntb = require("nvim-tools.buf")
        local cword_range = ntb.line_match_under_cursor(cur_pos_ext, cur_buf, [[\k\+]])
        if cword_range == nil then
            api.nvim_echo({ { "No range to rename", hl_warn } }, false, {})
            return
        end

        local default = prompt_default and ntb.text_from_range(cword_range, cur_buf) or ""
        session_add_symbol_range(session, cword_range)
        rename_get_input(client, session, cur_pos_ext, default)
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

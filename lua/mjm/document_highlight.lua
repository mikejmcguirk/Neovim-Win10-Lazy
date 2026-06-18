local api = vim.api
local bit = require("bit")
local fn = vim.fn
local hl_user = vim.hl.priorities.user
local lsp = vim.lsp
local util = lsp.util
local uv = vim.uv

local METHOD = "textDocument/documentHighlight"
local protocol = require("vim.lsp.protocol")
-- local KIND_TEXT = protocol.DocumentHighlightKind.Text
local KIND_READ = protocol.DocumentHighlightKind.Read
local KIND_WRITE = protocol.DocumentHighlightKind.Write

local text_hl = api.nvim_get_hl_id_by_name("LspReferenceText")
local read_hl = api.nvim_get_hl_id_by_name("LspReferenceRead")
local write_hl = api.nvim_get_hl_id_by_name("LspReferenceWrite")

---Kind is optional per the spec. Falls back to `Text` if not present.
---@param kind? integer
---@return integer
local function get_kind_hl(kind)
    if kind == KIND_READ then
        return read_hl
    elseif kind == KIND_WRITE then
        return write_hl
    else
        return text_hl
    end
end

local M = {}

-- Rather than create a duplicate source of truth for active bufs/clients, only track what the
-- user has explicitly disabled.
local bufs_disabled = {} ---@type table<integer, true|nil>
local client_ids_disabled = {} ---@type table<integer, true|nil>
local is_enabled = true

local ns = api.nvim_create_namespace("mjm.lsp.document_highlight")

---@class mjm.lsp.documentHighlight.Request
---@field cur_pos [integer, integer]
---@field id integer
---@field win integer

-- start_row, start_col, end_row, end_col, hl_group
---@alias mjm.lsp.documentHighlight.Hl [integer, integer, integer, integer, integer]

---@class mjm.lsp.documentHighlight.Result
---@field bot? integer
---@field bot_idx? integer
---@field client_ids integer[]
---@field cur_pos [integer, integer]
---@field has_decor boolean
---@field highlights mjm.lsp.documentHighlight.Hl[]
---@field top? integer
---@field top_idx? integer
---@field version integer

local client_reqs = {} ---@type table<integer, mjm.lsp.documentHighlight.Request>
local results = {} ---@type table<integer, mjm.lsp.documentHighlight.Result|nil>
local timers = {} ---@type table<integer, uv.uv_timer_t|nil>

---@param buf integer
---@param client_id integer
---@param cur_pos [integer, integer]
---@param hls mjm.lsp.documentHighlight.Hl[]
---@param version integer
local function result_set_or_new(buf, client_id, cur_pos, hls, version)
    local res = results[buf]
    if res then
        res.bot = -1
        res.bot_idx = -1
        res.client_ids = { client_id }
        res.cur_pos = cur_pos
        res.has_decor = false
        res.highlights = hls
        res.top = -1
        res.top_idx = -1
        res.version = version
        return
    end

    results[buf] = {
        bot = -1,
        bot_idx = -1,
        client_ids = { client_id },
        cur_pos = cur_pos,
        has_decor = false,
        highlights = hls,
        top = -1,
        top_idx = -1,
        version = version,
    }
end

---@param buf integer
---@param res mjm.lsp.documentHighlight.Result
local function result_reset_unchecked(buf, res)
    if res.has_decor then
        api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end

    local ntt = require("nvim-tools.table")
    ntt.clear(res.client_ids)
    ntt.clear(res.highlights)
    res.bot = -1
    res.bot_idx = -1
    res.cur_pos[1] = -1
    res.cur_pos[2] = -1
    res.has_decor = false
    res.top = -1
    res.top_idx = -1
    res.version = -1
end

---@param buf integer
local function result_reset(buf)
    local res = results[buf]
    if not res then
        return
    end

    result_reset_unchecked(buf, res)
end

---@param buf integer
---@param res mjm.lsp.documentHighlight.Result
local function result_reset_decor_unchecked(buf, res)
    if not res.has_decor then
        return
    end

    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    res.bot = -1
    res.bot_idx = -1
    res.has_decor = false
    res.top = -1
    res.top_idx = -1
end

---@param buf integer
---@return boolean `true` if results are valid.
local function result_reset_if_stale(buf)
    local res = results[buf]
    if not res then
        return false
    end

    if res.version ~= util.buf_versions[buf] then
        result_reset_unchecked(buf, res)
        return false
    end

    return true
end

---@param buf integer
---@param res mjm.lsp.documentHighlight.Result
local function result_clear_and_redraw_unchecked(buf, res)
    local has_decor = res.has_decor
    results[buf] = nil
    if has_decor and api.nvim_buf_is_valid(buf) then
        api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        api.nvim__redraw({ buf = buf, valid = true, flush = false })
    end
end

---@param buf integer
local function result_clear_and_redraw_checked(buf)
    local res = results[buf]
    if not res then
        return
    end

    result_clear_and_redraw_unchecked(buf, res)
end

---@param client_id integer
---@return uv.uv_timer_t
local function timer_get_or_create(client_id)
    local timer = timers[client_id]
    if timer then
        return timer
    end

    timer = assert(uv.new_timer())
    timers[client_id] = timer
    return timer
end

-- Terrible for performance. Good for ergonomics.
---@param client_id integer?
---@param client? vim.lsp.Client
local function cancel_req(client_id, client)
    client_id = client_id or (client and client.id)
    if not client_id then
        return
    end

    local req = client_reqs[client_id]
    if not req then
        return
    end

    client = client or lsp.get_client_by_id(client_id)
    if client then
        client:cancel_request(req.id)
        return
    end

    client_reqs[client_id] = nil
end

---@param buf integer
---@param hl_info mjm.lsp.documentHighlight.Hl
local function set_mark(buf, hl_info)
    api.nvim_buf_set_extmark(buf, ns, hl_info[1], hl_info[2], {
        end_col = hl_info[4],
        end_row = hl_info[3],
        hl_group = hl_info[5],
        priority = hl_user,
        strict = false,
    })
end

---@param mode string
---@return boolean
local function can_decorate_mode(mode)
    if string.byte(mode, 1) == 110 and (#mode == 1 or string.byte(mode, 2) == 111) then
        return true
    end

    if string.byte(mode, 1) == 99 then
        return true
    end

    return false
end

-- Don't need win param because the namespace is window-scoped.
---@param buf integer
---@param top integer
---@param bot integer
local function on_win(_, _, buf, top, bot)
    local res = results[buf]
    if not res then
        return
    end

    local hls = res.highlights
    if #hls == 0 then
        return
    end

    local has_decor = res.has_decor
    if res.version ~= util.buf_versions[buf] then
        result_reset(buf)
        return
    end

    if not can_decorate_mode(api.nvim_get_mode().mode) then
        result_reset_decor_unchecked(buf, res)
        return
    end

    if not has_decor then
        local top_idx = vim.list.bisect(hls, { 0, 0, top }, {
            key = function(hl)
                return hl[3]
            end,
        })

        local bot_idx = vim.list.bisect(hls, { bot + 1 }, {
            key = function(hl)
                return hl[1]
            end,
        }) - 1

        for i = top_idx, bot_idx do
            set_mark(buf, hls[i])
        end

        res.bot = bot
        res.bot_idx = bot_idx
        res.has_decor = true
        res.top = top
        res.top_idx = top_idx
        return
    end

    local cur_top = res.top
    if top < cur_top then
        local cur_top_idx = res.top_idx or #hls
        local top_idx = vim.list.bisect(hls, { 0, 0, top }, {
            hi = cur_top_idx,
            key = function(hl)
                return hl[3]
            end,
        })

        for i = top_idx, cur_top_idx - 1 do
            set_mark(buf, hls[i])
        end

        res.top = top
        res.top_idx = top_idx
    end

    local cur_bot = res.bot
    if cur_bot < bot then
        local cur_bot_idx = res.bot_idx or 1
        local bot_idx = vim.list.bisect(hls, { bot + 1 }, {
            lo = cur_bot_idx + 1,
            key = function(hl)
                return hl[1]
            end,
        }) - 1

        for i = cur_bot_idx + 1, bot_idx do
            set_mark(buf, hls[i])
        end

        res.bot = bot
        res.bot_idx = bot_idx
    end
end
-- MID: Would prefer to not have to wrap top and bot in tables for bisect. I'm not sure what the
-- solution is other than to pre-store the highlight comparisons, which feels worse.
-- MID: This could skip folded lines here, but then you would have to iterate through them again
-- on each redraw to see if they're unfolded.

api.nvim_set_decoration_provider(ns, { on_win = on_win })

---Non-trivially faster than using the public APIS.
---@param buf integer
---@param position lsp.Position
---@param offset_encoding lsp.PositionEncodingKind
---@return uinteger, uinteger
local function lsp_to_nvim(buf, position, offset_encoding)
    local row, col = position.line, position.character
    if col > 0 and offset_encoding ~= "utf-8" then
        local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
        col = vim._str_byteindex(line, col, offset_encoding == "utf-16") ---@type uinteger
    end

    return row, col
end

---@param response lsp.DocumentHighlight[]
---@param buf integer
---@param offset_encoding lsp.PositionEncodingKind
---@return mjm.lsp.documentHighlight.Hl[]
local function response_to_ranges(response, buf, offset_encoding)
    local ntl = require("nvim-tools.list")
    local hls = ntl.filter_map_to(response, function(resp)
        local range = resp.range -- Mandatory per the spec.
        local sr, sc = lsp_to_nvim(buf, range["start"], offset_encoding)
        local er, ec = lsp_to_nvim(buf, range["end"], offset_encoding)
        return { sr, sc, er, ec, get_kind_hl(resp["kind"]) }
    end)

    -- Run the sanitation Helix does.
    local ntr = require("nvim-tools.range")
    ntl.filter(hls, function(hl)
        return ntr.valid_(hl)
    end)

    -- The spec does not guarantee order.
    table.sort(hls, ntr.range_sort_predicate)
    -- Reduce the amount of decorations to draw.
    ntl.combine(hls, function(a, b)
        local cmp = ntr.cmp_(a, b)
        local abs_cmp = math.abs(cmp)
        if abs_cmp == 1 then
            return
        end

        if cmp <= 0 then
            if -4 < cmp then
                a[3] = b[3]
                a[4] = b[4]
            end

            return a
        end

        if cmp < 4 then
            b[3] = a[3]
            b[4] = a[4]
        end

        return b
    end)

    return hls
end

---@param res mjm.lsp.documentHighlight.Result Modified in place.
---@param response lsp.DocumentHighlight[]
---@param buf integer
---@param client_id integer
---@param encoding lsp.PositionEncodingKind
local function result_add_addtl_client_hls(res, response, buf, encoding, client_id)
    local res_client_ids = res.client_ids
    res_client_ids[#res_client_ids + 1] = client_id

    local hls_addtl = response_to_ranges(response, buf, encoding)
    if #hls_addtl == 0 then
        return
    end

    local ntl = require("nvim-tools.list")
    local hls_old = res.highlights
    ntl.subtract(function(hl)
        return bit.lshift(hl[1], 0)
            + bit.lshift(hl[2], 14)
            + bit.lshift(hl[3], 24)
            + bit.lshift(hl[4], 38)
    end, hls_addtl, hls_old)

    if #hls_addtl == 0 then
        return
    end

    local ntr = require("nvim-tools.range")
    local hls_new = ntl.merge_sorted_to(ntr.range_sort_predicate, hls_old, hls_addtl)
    ntl.combine(hls_new, function(a, b)
        if math.abs(ntr.cmp_(a, b)) == 1 then
            return
        end

        return a -- Overlap. Just discard b.
    end)

    res.highlights = hls_new
    res.top = nil
    res.top_idx = nil
    res.bot = nil
    res.bot_idx = nil
end
-- MID-DEP: It might be possible to resolve subtraction and overlap in one step before
-- merging. Would not do that though without a use case where a commonly highlighted symbol
-- from two LSPs takes > 5ms to process.

---@param res mjm.lsp.documentHighlight.Result
---@param req_win integer
---@param resp_buf integer
---@param req_cur_pos [integer, integer]
---@return boolean
local function response_addtl_has_uptd_state(res, req_win, resp_buf, req_cur_pos)
    local ns_wins = api.nvim__ns_get(ns).wins
    local ntl = require("nvim-tools.list")
    if not (ns_wins and ntl.contains(ns_wins, req_win)) then
        return false
    end

    if resp_buf ~= api.nvim_win_get_buf(req_win) then
        return false
    end

    if not ntl.cmp(req_cur_pos, res.cur_pos) then
        return false
    end

    return true
end

---@param req_win integer
---@param resp_buf integer
---@param req_cur_pos [integer, integer]
---@return boolean
local function response_new_has_uptd_state(req_win, resp_buf, req_cur_pos)
    if req_win ~= api.nvim_get_current_win() then
        return false
    end

    if resp_buf ~= api.nvim_win_get_buf(req_win) then
        return false
    end

    local ntl = require("nvim-tools.list")
    if not ntl.cmp(req_cur_pos, api.nvim_win_get_cursor(req_win)) then
        return false
    end

    return true
end

---@class mjm.lsp.HandlerContext_Validated : lsp.HandlerContext
---@field bufnr integer
---@field request_id integer
---@field version integer

---@param ctx lsp.HandlerContext
---@return boolean, mjm.lsp.documentHighlight.Request?, vim.lsp.Client?, mjm.lsp.HandlerContext_Validated?
local function response_should_handle(ctx)
    local client_id = ctx.client_id
    local req = client_reqs[client_id]
    client_reqs[client_id] = nil
    local request_id = ctx.request_id
    if not (req and request_id and req.id == request_id) then
        return false
    end

    local resp_buf = ctx.bufnr
    if not resp_buf then
        return false
    end

    if is_enabled == false or bufs_disabled[resp_buf] or client_ids_disabled[client_id] then
        return false
    end

    local ctx_version = ctx.version
    if not (ctx_version and ctx_version == util.buf_versions[resp_buf]) then
        return false
    end

    local client = lsp.get_client_by_id(client_id)
    if not client then
        return false
    end

    return true, req, client, ctx --[[@as mjm.lsp.HandlerContext_Validated]]
end

---@param err lsp.ResponseError?
---@param response lsp.DocumentHighlight[]
---@param ctx lsp.HandlerContext
local function response_handler(err, response, ctx)
    local ok, req, client, ctx_validated = response_should_handle(ctx)
    if ok == false or not req or not client or not ctx_validated then
        return
    end

    if err then
        local msg = client.name .. " - " .. err.code .. ": " .. err.message
        -- TODO: This is roughly correct but kind of an issue because if you have something like
        -- ts_ls not able to document highlight and it will spam those errors.
        require("nvim-tools.lsp").log_error_and_echo(msg)
        return
    end

    -- No error because both of these are valid per the spec.
    if response == nil or #response == 0 then
        return
    end

    local client_id = ctx_validated.client_id
    local req_cur_pos = req.cur_pos
    local req_win = req.win
    local resp_buf = ctx_validated.bufnr
    result_reset_if_stale(resp_buf)
    local res = results[resp_buf]
    if (not res) or #res.client_ids == 0 then
        if not response_new_has_uptd_state(req_win, resp_buf, req_cur_pos) then
            return
        end

        local hls = response_to_ranges(response, resp_buf, client.offset_encoding)
        result_set_or_new(resp_buf, client_id, req_cur_pos, hls, ctx_validated.version)
    else
        local ntl = require("nvim-tools.list")
        if ntl.contains(res.client_ids, client_id) then
            -- request_auto() should clear the result state before sending a new request.
            -- Otherwise, the spec doesn't provide for streaming or amended results, so any repeats
            -- of the same client id should be treated as duplicates.
            return
        end

        if not response_addtl_has_uptd_state(res, req_win, resp_buf, req_cur_pos) then
            return
        end

        result_add_addtl_client_hls(res, response, resp_buf, client.offset_encoding, client_id)
    end

    api.nvim__redraw({ buf = resp_buf, valid = true, flush = false })
end
-- MID-DEP: Print the err data if a use case appears.

local group_name = "mjm.lsp.document_highlight"

---@param buf integer
local function buf_group_name_get(buf)
    return group_name .. "." .. tostring(buf)
end

---@param buf integer
local function buf_rm_autocmds(buf)
    local buf_group = buf_group_name_get(buf)
    if fn.exists("#" .. buf_group) == 1 then
        api.nvim_del_augroup_by_name(buf_group)
    end
end

---Assume the request is still valid here. If the underlying conditions changed, an auto-request
---should have already prevented this from triggering.
---@param client vim.lsp.Client
---@param win integer
---@param buf integer
---@param cur_pos [integer, integer]
local function request_send(client, win, buf, cur_pos)
    -- For if the buffer is unloaded during debounce.
    if not api.nvim_buf_is_valid(buf) then
        buf_rm_autocmds(buf)
        return
    end

    local encoding = client.offset_encoding
    local params = {
        textDocument = util.make_text_document_params(buf),
        position = vim.pos.cursor(buf, cur_pos):to_lsp(encoding),
    }

    local req_success, req_id = client:request(METHOD, params, response_handler, buf)
    if req_success and req_id then
        client_reqs[client.id] = { id = req_id, cur_pos = cur_pos, win = win }
    end
end

---@param buf integer
---@param cur_pos [integer, integer]
---@return boolean
local function has_ref_under_cursor(buf, cur_pos)
    local ntp = require("nvim-tools.pos")
    local ntl = require("nvim-tools.list")
    local ext_pos = ntp.mark_to_ext_pos(ntl.copy(cur_pos))
    return #api.nvim_buf_get_extmarks(buf, ns, ext_pos, ext_pos, {
        details = true,
        limit = 1,
        overlap = true,
    }) > 0
end
-- MID: The extmark solution is not lightweight.

---@param buf integer
local function request_auto(buf)
    if is_enabled == false or bufs_disabled[buf] == true then
        return
    end

    local has_uptd_results = result_reset_if_stale(buf)
    if not has_uptd_results then
        api.nvim__redraw({ buf = buf, valid = true, flush = false })
    end

    local mode = api.nvim_get_mode().mode
    if not (#mode == 1 and string.byte(mode) == 110) then
        return
    end

    local win = api.nvim_get_current_win()
    if vim.call("win_gettype", win) ~= "" then
        return
    end

    -- MID-DEP: Un-comment this if there's a reason to.
    -- local win_buf = api.nvim_win_get_buf(win)
    -- if win_buf ~= buf then
    --     return
    -- end

    local cur_pos = api.nvim_win_get_cursor(win)
    if has_uptd_results then
        if has_ref_under_cursor(buf, cur_pos) then
            return
        else
            result_reset(buf)
            api.nvim__redraw({ buf = buf, valid = true, flush = false })
        end
    end

    local clients = lsp.get_clients({ bufnr = buf, method = METHOD })
    if #clients == 0 then
        buf_rm_autocmds(buf)
        return
    end

    for _, client in ipairs(clients) do
        local client_id = client.id
        local timer = timer_get_or_create(client_id)
        if uv.is_active(timer) then
            uv.timer_stop(timer)
        end

        cancel_req(client_id, client)
        local debounce = client.flags.debounce_text_changes or 150
        uv.timer_start(
            timer,
            debounce,
            0,
            vim.schedule_wrap(function()
                request_send(client, win, buf, cur_pos)
            end)
        )
    end
end
-- TODO: Because this handles canceling, does this mean we can do direct requests again?
-- If you wanted to have direct and debounced request paths, you would need to take a lot of the
-- validation in here and outline it into a common function. You would then want request_auto
-- to run the outlined validation then the timer business. Whereas, for the request_direct
-- path, you would want it to run the outlined validation, then iterate clients to immediately
-- run request_send.

---@param bufnr integer
local function buf_autocmds_create(bufnr)
    local buf_group_name = buf_group_name_get(bufnr)
    -- Keep this logic in here because:
    -- - Getting buf_group_name twice or passing it as an arg is wasteful/sloppy.
    -- - If multiple LSPs attach to a buffer, we don't want to force the clear logic.
    if fn.exists("#" .. buf_group_name) == 1 then
        return
    end

    local buf_group = api.nvim_create_augroup(buf_group_name, {})
    api.nvim_create_autocmd({ "CursorMoved" }, {
        group = buf_group,
        -- TODO-DEP: Change this to "buf" when v0.14 comes out.
        buffer = bufnr,
        desc = "Refresh document highlights",
        callback = function(ev)
            request_auto(ev.buf)
        end,
    })

    api.nvim_create_autocmd("LspNotify", {
        buffer = bufnr,
        group = buf_group,
        desc = "Refresh document highlights on document changes",
        callback = function(ev)
            -- PR: Update this annotation.
            local method = ev.data.method --- @type string
            if method == "textDocument/didChange" or method == "textDocument/didOpen" then
                request_auto(ev.buf)
                return
            end

            if method == "textDocument/didClose" then
                -- Per the spec, the client sends this notification when it closes the document,
                -- but not necessarily on detach. Don't do the full teardown here.
                result_reset(ev.buf)
            end
        end,
    })

    -- Do this as a buffer autocmd so only the current buffer fires.
    api.nvim_create_autocmd("ModeChanged", {
        group = buf_group,
        -- TODO-DEP: Change this to "buf" when v0.14 comes out.
        buffer = bufnr,
        desc = "Refresh document highlights on returning to normal mode",
        callback = function(ev)
            ---@diagnostic disable-next-line: undefined-field
            local nm = vim.v.event.new_mode
            local buf = ev.buf
            if #nm == 1 and string.byte(nm, 1) == 110 then
                -- Manually restore decorations without redrawing so they can be detected by
                -- request_auto.
                on_win(_, _, buf, vim.call("line", "w0"), vim.call("line", "w$"))
                request_auto(buf)
            end
        end,
        -- MID: Manually restoring decorations is a blunt solution.
        -- PR: Add old_mode and new_mode to the vim.v.event annotation. vvars_extra.lua. Not
        -- auto-generated.
    })
end

local function autocmds_create()
    local group = api.nvim_create_augroup(group_name, {})
    api.nvim_create_autocmd("LspAttach", {
        group = group,
        callback = function(ev)
            local client_id = ev.data.client_id
            if client_ids_disabled[client_id] then
                return
            end

            local buf = ev.buf
            if bufs_disabled[buf] == true then
                return
            end

            local client = lsp.get_client_by_id(client_id)
            if not client then
                return
            end

            if not client:supports_method(METHOD) then
                return
            end

            buf_autocmds_create(buf)
            local cur_win = api.nvim_get_current_win()
            local cur_win_buf = api.nvim_win_get_buf(cur_win)
            if cur_win_buf == buf then
                -- Since WinEnter didn't have a chance to fire.
                api.nvim__ns_set(ns, { wins = { cur_win } })
            end

            request_auto(buf)
        end,
    })

    api.nvim_create_autocmd("LspDetach", {
        group = group,
        -- Schedule wrap so that the detached client's active buffers are updated.
        callback = vim.schedule_wrap(function(ev)
            local buf = ev.buf
            local buf_clients = lsp.get_clients({ bufnr = buf, method = METHOD })
            if #buf_clients == 0 then
                result_clear_and_redraw_checked(buf)
            end

            local client_id = ev.data.client_id
            if not client_id then
                return
            end

            local client = lsp.get_client_by_id(client_id)
            if not client then
                cancel_req(client_id)
                return
            end

            if not next(client.attached_buffers) then
                cancel_req(client_id, client)
            end
        end),
    })

    api.nvim_create_autocmd("WinEnter", {
        group = group,
        callback = function(ev)
            api.nvim__ns_set(ns, { wins = { api.nvim_get_current_win() } })
            local buf = ev.buf
            -- TODO: Hacky
            local buf_group = buf_group_name_get(buf)
            if fn.exists("#" .. buf_group) == 1 then
                request_auto(buf)
            end
        end,
    })
end
-- MID: Dumb because if you want default disabled you still have to wait for the autocmds to
-- spawn on first require.

autocmds_create()

---@param buf integer
local function buf_enable(buf)
    bufs_disabled[buf] = nil
    buf_autocmds_create(buf)
    if buf == api.nvim_get_current_buf() then
        api.nvim__ns_set(ns, { wins = { api.nvim_get_current_win() } })
        request_auto(buf)
    end
end

---@param buf integer
local function buf_disable(buf)
    bufs_disabled[buf] = true
    buf_rm_autocmds(buf)
    result_clear_and_redraw_checked(buf)
end

---@param client vim.lsp.Client
local function buf_autocmds_create_for_client(client)
    for buf, _ in pairs(client.attached_buffers) do
        buf_autocmds_create(buf)
        if buf == api.nvim_get_current_buf() then
            api.nvim__ns_set(ns, { wins = { api.nvim_get_current_win() } })
            request_auto(buf)
        end
    end
end

---@param client_id integer
local function client_enable(client_id)
    local client = lsp.get_client_by_id(client_id)
    if not client then
        require("nvim-tools.lsp").log_warn_and_echo("[LSP] Client not found")
        return
    end

    if not client:supports_method(METHOD) then
        local msg = "[LSP] Server does not support document highlight"
        require("nvim-tools.lsp").log_warn_and_echo(msg)
        return
    end

    client_ids_disabled[client_id] = nil
    buf_autocmds_create_for_client(client)
end

---@param client_id integer
local function client_disable(client_id)
    cancel_req(client_id)
    client_ids_disabled[client_id] = true
end

---@param enabled boolean?
---@param bufs integer[]?
---@param client_ids integer[]?
function M.enable(enabled, bufs, client_ids)
    if enabled ~= false then
        enabled = true
    end

    if bufs == nil and client_ids == nil then
        is_enabled = enabled
        if is_enabled == true then
            autocmds_create()
            for _, client in ipairs(lsp.get_clients({ method = METHOD })) do
                buf_autocmds_create_for_client(client)
            end

            return
        end

        for client_id, _ in pairs(client_reqs) do
            cancel_req(client_id)
        end

        if fn.exists("#" .. group_name) == 1 then
            api.nvim_del_augroup_by_name(group_name)
        end

        for _, client in ipairs(lsp.get_clients({ method = METHOD })) do
            for buf, _ in pairs(client.attached_buffers) do
                buf_rm_autocmds(buf)
            end
        end

        for buf, res in pairs(results) do
            result_clear_and_redraw_unchecked(buf, res)
        end

        return
    end

    if bufs then
        local status_fn = enabled == true and buf_enable or buf_disable
        for _, buf in ipairs(bufs) do
            status_fn(buf)
        end
    end

    if client_ids then
        local status_fn = enabled == true and client_enable or client_disable
        for _, client_id in ipairs(client_ids) do
            status_fn(client_id)
        end
    end
end

---@param buf integer?
---@param client_id integer?
function M.is_enabled(buf, client_id)
    if buf ~= nil then
        -- Nvim checks for a vim.b enabled var, indirectly requiring that the buf exist.
        return bufs_disabled[buf] ~= true and api.nvim_buf_is_valid(buf)
    elseif client_id ~= nil then
        -- Nvim requires that the client exist.
        local client = lsp.get_client_by_id(client_id)
        return client ~= nil and client_ids_disabled[client_id] ~= true
    else
        return is_enabled
    end
end

function M.get_results()
    return vim.inspect(results)
end

return M

-- TODO-DEP: Let this live in my config for a bit then make it a plugin.
-- - Remove "mjm" annotations.
-- - Move nvim-tools functions into a plugin-specific util module. Check carefully that nvim-tools
--   isn't being required anywhere.

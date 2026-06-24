local api = vim.api
local fn = vim.fn
local hl_user = vim.hl.priorities.user
local lsp = vim.lsp
local util = lsp.util

------------------------
-- MARK: Enabled Info --
------------------------

local is_enabled = true
-- Don't create a duplicate source of truth for what is "enabled".
local bufs_disabled = {} ---@type table<uinteger, true|nil>
local client_ids_disabled = {} ---@type table<uinteger, true|nil>

----------------------------------------------
-- MARK: Highlight Group and Namespace Info --
----------------------------------------------

local METHOD = "textDocument/documentHighlight"
local protocol = require("vim.lsp.protocol")
local KIND_READ = protocol.DocumentHighlightKind.Read
-- local KIND_TEXT = protocol.DocumentHighlightKind.Text
local KIND_WRITE = protocol.DocumentHighlightKind.Write

local ns = api.nvim_create_namespace("mjm.lsp.document_highlight")
local read_hl = api.nvim_get_hl_id_by_name("LspReferenceRead")
local text_hl = api.nvim_get_hl_id_by_name("LspReferenceText")
local write_hl = api.nvim_get_hl_id_by_name("LspReferenceWrite")

---Kind is optional per the spec.
---@param kind? uinteger
---@return uinteger
local function get_kind_hl(kind)
    if kind == KIND_READ then
        return read_hl
    elseif kind == KIND_WRITE then
        return write_hl
    else
        return text_hl
    end
end

----------------
-- MARK: Util --
----------------

---@param mode? string
---@return -1|0|1
----  1: Normal mode. Can redraw and create new requests.
----  0: Operator pending or cmd mode. Can redraw, but not create new requests.
---- -1: Others. Do not advance highlight state.
local function mode_get_status(mode)
    mode = mode or api.nvim_get_mode().mode
    local byte_one = string.byte(mode, 1)
    local byte_one_n = byte_one == 110
    if byte_one_n and #mode == 1 then
        return 1
    end

    if byte_one_n and #mode > 1 and string.byte(mode, 2) == 111 then
        return 0
    end

    if byte_one == 99 then
        return 0
    end

    return -1
end

------------------------------
-- MARK: Request Management --
------------------------------

---@class mjm.lsp.documentHighlight.PendingRequest
---@field client_id uinteger
---@field cur_pos_ext [uinteger, uinteger]
---@field id uinteger
---@field win uinteger

local reqs = {} ---@type table<uinteger, mjm.lsp.documentHighlight.PendingRequest>
local timers = {} ---@type table<uinteger, uv.uv_timer_t>

---@param buf uinteger
---@param client_id? uinteger
local function req_cancel(buf, client_id)
    local buf_req = reqs[buf]
    if not buf_req then
        return
    end

    local req_client_id = buf_req.client_id
    if client_id and client_id ~= req_client_id then
        return
    end

    local client = lsp.get_client_by_id(req_client_id)
    if client then
        client:cancel_request(buf_req.id)
    end

    reqs[buf] = nil
end

---@param buf integer
local function req_and_timer_stop(buf)
    require("nvim-tools.timers").timers_stop(timers, buf)
    req_cancel(buf)
end

---------------------------------------
-- MARK: Results Data and Management --
---------------------------------------

-- start_row, start_col, end_row, end_col, hl_group
---@alias mjm.lsp.documentHighlight.Hl [uinteger, uinteger, uinteger, uinteger, uinteger]

---@class mjm.lsp.documentHighlight.Result
---@field bot? integer
---@field bot_idx? integer
---@field has_decor boolean
---@field highlights mjm.lsp.documentHighlight.Hl[]
---@field top? integer
---@field top_idx? integer
---@field version integer

local results = {} ---@type table<integer, mjm.lsp.documentHighlight.Result|nil>

---@param res mjm.lsp.documentHighlight.Result
---@param buf uinteger
---@param wipe "all"|"decor"|"del"
local function res_reset(res, buf, wipe)
    local has_decor = res.has_decor == true
    if has_decor then
        api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end

    if has_decor and wipe ~= "del" then
        res.bot = -1
        res.bot_idx = -1
        res.has_decor = false
        res.top = -1
        res.top_idx = -1
    end

    if wipe == "all" then
        if res.version > -1 then
            local ntl = require("nvim-tools.list")
            ntl.clear(res.highlights)
            res.version = -1
        end
    end

    if wipe == "del" then
        results[buf] = nil
    end

    if has_decor then
        api.nvim__redraw({ buf = buf, valid = true, flush = false })
    end
end

---@param buf uinteger
---@param wipe "all"|"decor"|"del"
local function from_buf_res_reset(buf, wipe)
    local buf_res = results[buf]
    if buf_res then
        res_reset(buf_res, buf, wipe)
    end
end

---@param res mjm.lsp.documentHighlight.Result
---@param buf uinteger
---@param version boolean
---@param cur_pos_ext? [uinteger, uinteger]
---@return boolean
local function res_ensure_updated(res, buf, version, cur_pos_ext)
    if version then
        local res_version = res.version
        if res_version > -1 and res_version ~= util.buf_versions[buf] then
            res_reset(res, buf, "all")
            return false
        end
    end

    if cur_pos_ext ~= nil then
        local ntr = require("nvim-tools.range")
        if ntr.ranges_have_pos(res.highlights, cur_pos_ext) then
            if res.has_decor ~= true then
                api.nvim__redraw({ buf = buf, valid = true, flush = false })
            end
        else
            res_reset(res, buf, "all")
            return false
        end
    end

    return true
end

---@param buf uinteger
---@param version boolean
---@param cur_pos_ext? [uinteger, uinteger]
local function from_buf_res_ensure_uptd(buf, version, cur_pos_ext)
    local buf_res = results[buf]
    if buf_res then
        return res_ensure_updated(buf_res, buf, version, cur_pos_ext)
    end

    return false
end

---@param buf integer
---@param hls mjm.lsp.documentHighlight.Hl[]
---@param version integer
local function result_set_or_new(buf, hls, version)
    local res = results[buf]
    if res then
        res.bot = -1
        res.bot_idx = -1
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
        has_decor = false,
        highlights = hls,
        top = -1,
        top_idx = -1,
        version = version,
    }
end

---------------------
-- MARK: Redrawing --
---------------------

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

    if mode_get_status() < 0 then
        return
    end

    local function vis_range_cmp(r)
        if bot < r[1] then
            return -1
        elseif r[3] < top then
            return 1
        else
            return 0
        end
    end

    local has_decor = res.has_decor
    if not has_decor then
        local ntr = require("nvim-tools.range")
        local top_idx = ntr.bisect_lo(hls, vis_range_cmp)
        local bot_idx = ntr.bisect_hi(hls, vis_range_cmp)
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
        local ntr = require("nvim-tools.range")
        local top_idx = ntr.bisect_lo(hls, vis_range_cmp)
        local cur_top_idx = res.top_idx or #hls
        for i = top_idx, cur_top_idx - 1 do
            set_mark(buf, hls[i])
        end

        res.top = top
        res.top_idx = top_idx
    end

    local cur_bot = res.bot
    if cur_bot < bot then
        local cur_bot_idx = res.bot_idx or 1
        local ntr = require("nvim-tools.range")
        local bot_idx = ntr.bisect_hi(hls, vis_range_cmp)
        for i = cur_bot_idx + 1, bot_idx do
            set_mark(buf, hls[i])
        end

        res.bot = bot
        res.bot_idx = bot_idx
    end
end

api.nvim_set_decoration_provider(ns, { on_win = on_win })

----------------------------------------
-- MARK: Request Sending and Handling --
----------------------------------------

---@param response lsp.DocumentHighlight[]
---@param buf integer
---@param offset_encoding lsp.PositionEncodingKind
---@return mjm.lsp.documentHighlight.Hl[]
local function response_to_ranges(response, buf, offset_encoding)
    local ntl = require("nvim-tools.list")
    local ntp = require("nvim-tools.pos")
    local hls = ntl.filter_map_to(response, function(resp)
        local range = resp.range -- Mandatory per the spec.
        local sr, sc = ntp.lsp_to_ext_buf_loaded(buf, range["start"], offset_encoding)
        local er, ec = ntp.lsp_to_ext_buf_loaded(buf, range["end"], offset_encoding)
        return { sr, sc, er, ec, get_kind_hl(resp["kind"]) }
    end)

    -- Run the sanitation Helix performs.
    local ntr = require("nvim-tools.range")
    ntl.filter(hls, function(hl)
        return ntr.valid_(hl)
    end)

    -- The spec does not guarantee order.
    table.sort(hls, ntr.range_sort_predicate_asc)
    -- Worthwhile because setting/drawing extmarks is a non-trivial cost.
    ntl.combine(hls, function(a, b)
        local cmp = ntr.cmp_(a, b)
        if math.abs(cmp) == 1 then
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

---@param req_win integer
---@param resp_buf integer
---@param req_cur_pos_ext [integer, integer]
---@return boolean
local function response_has_current_state(req_win, resp_buf, req_cur_pos_ext)
    if req_win ~= api.nvim_get_current_win() then
        return false
    end

    if resp_buf ~= api.nvim_win_get_buf(req_win) then
        return false
    end

    local cur_pos = api.nvim_win_get_cursor(req_win)
    local cur_pos_ext = require("nvim-tools.pos").mark_to_ext_pos(cur_pos)
    if not require("nvim-tools.list").cmp(req_cur_pos_ext, cur_pos_ext) then
        return false
    end

    return true
end

---@class mjm.lsp.HandlerContext_Validated : lsp.HandlerContext
---@field bufnr integer
---@field request_id integer
---@field version integer

---@param ctx lsp.HandlerContext
---@return boolean, mjm.lsp.documentHighlight.PendingRequest?, vim.lsp.Client?, mjm.lsp.HandlerContext_Validated?
local function doc_hl_req_handler_check_ctx(ctx)
    local resp_buf = ctx.bufnr
    if not resp_buf then
        return false
    end

    local buf_req = reqs[resp_buf]
    if buf_req == nil then
        return false
    end

    -- TODO: pass the module level req id as a variable so it can be deleted beforehand
    local request_id = ctx.request_id
    if not (request_id and request_id == buf_req.id) then
        return false
    end

    reqs[resp_buf] = nil
    local client_id = ctx.client_id
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

    return true, buf_req, client, ctx --[[@as mjm.lsp.HandlerContext_Validated]]
end

---@param err lsp.ResponseError?
---@param response lsp.DocumentHighlight[]?
---@param ctx lsp.HandlerContext
local function doc_hl_req_handler(err, response, ctx)
    -- TODO get req id immediately and nil it here.
    -- TODO: Use the closure version of this.
    local ok, req, client, ctx_validated = doc_hl_req_handler_check_ctx(ctx)
    if ok == false or not req or not client or not ctx_validated then
        return
    end

    if err then
        local msg = client.name .. " - " .. err.code .. ": " .. err.message
        require("nvim-tools.lsp").log_error_and_echo(msg)
        return
    end

    -- No error because both of these are valid per the spec.
    if response == nil or #response == 0 then
        return
    end

    local resp_buf = ctx_validated.bufnr
    local buf_res = results[resp_buf]
    if buf_res and buf_res.version > -1 then
        return
    end

    local req_win = req.win
    local req_cur_pos_ext = req.cur_pos_ext
    if not response_has_current_state(req_win, resp_buf, req_cur_pos_ext) then
        return
    end

    local hls = response_to_ranges(response, resp_buf, client.offset_encoding)
    result_set_or_new(resp_buf, hls, ctx_validated.version)
    api.nvim__redraw({ buf = resp_buf, valid = true, flush = false })
end

---@param client_id integer
---@param win integer
---@param buf integer
---@param cur_pos_ext [integer, integer]
local function request_send(client_id, win, buf, cur_pos_ext)
    local client = lsp.get_client_by_id(client_id)
    if not client then
        return
    end

    if not api.nvim_buf_is_valid(buf) then
        return
    end

    local text_document = util.make_text_document_params(buf)
    local row = cur_pos_ext[1]
    local col = cur_pos_ext[2]
    local encoding = client.offset_encoding
    local position = vim.pos.extmark(buf, row, col):to_lsp(encoding)
    local params = { textDocument = text_document, position = position }

    local req_success, req_id = client:request(METHOD, params, doc_hl_req_handler, buf)
    if req_success and req_id then
        reqs[buf] = {
            client_id = client_id,
            cur_pos_ext = cur_pos_ext,
            id = req_id,
            win = win,
        }
    end
end

---@param win uinteger
---@return [uinteger, uinteger]
local function cur_pos_ext_get(win)
    local ntp = require("nvim-tools.pos")
    return ntp.mark_to_ext_pos(api.nvim_win_get_cursor(win))
end

---@param buf uinteger
---@return uinteger?
local function win_for_request_get(buf)
    if mode_get_status() < 1 then
        return
    end

    local cur_win = api.nvim_get_current_win()
    local cur_win_buf = api.nvim_win_get_buf(cur_win)
    if cur_win_buf ~= buf then
        return
    end

    local ns_wins = api.nvim__ns_get(ns).wins
    return (ns_wins ~= nil and ns_wins[1] == cur_win) and cur_win or nil
end

---@param buf uinteger
---@param version boolean Verify current result is up to date.
---@param prev_hls boolean Abort if a valid highlight is present.
local function request_debounced(buf, version, prev_hls)
    local win = win_for_request_get(buf)
    if win == nil then
        return
    end

    local cur_pos_ext = cur_pos_ext_get(win)
    if from_buf_res_ensure_uptd(buf, version, (prev_hls and cur_pos_ext or nil)) == true then
        return
    end

    req_and_timer_stop(buf)
    local nts = require("nvim-tools.lsp")
    local client_id, client = nts.client_get_from_doc_sel_score(buf, { METHOD })
    if not (client_id and client) then
        return
    end

    local nti = require("nvim-tools.timers")
    nti.timers_do_after_debounce(
        timers,
        buf,
        client.flags.debounce_text_changes or 150,
        vim.schedule_wrap(function()
            request_send(client_id, win, buf, cur_pos_ext)
        end)
    )
end

------------------
-- MARK: Events --
------------------

local group_name = "mjm.lsp.document_highlight"

---@param buf uinteger
local function buf_group_name_get(buf)
    return group_name .. "." .. tostring(buf)
end

---@param bufnr uinteger
local function buf_autocmds_create(bufnr)
    local buf_group_name = buf_group_name_get(bufnr)
    -- Keep this logic inlined to avoid having to handle buf_group_name as an optional arg.
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
            request_debounced(ev.buf, false, true)
        end,
    })

    api.nvim_create_autocmd("LspNotify", {
        buffer = bufnr,
        group = buf_group,
        desc = "Refresh document highlights on document changes",
        callback = function(ev)
            local method = ev.data.method --- @type string
            if method == "textDocument/didChange" then
                request_debounced(ev.buf, true, false)
            elseif method == "textDocument/didOpen" then
                request_debounced(ev.buf, true, false)
            elseif method == "textDocument/didClose" then
                from_buf_res_reset(ev.buf, "all")
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
            local nm_status = mode_get_status(vim.v.event.new_mode)
            local buf = ev.buf
            if nm_status == 1 then
                request_debounced(buf, true, true)
            elseif nm_status == -1 then
                from_buf_res_reset(buf, "decor")
            end
        end,
    })
end

---@param win uinteger
local function set_ns_win(win)
    if fn.win_gettype(win) == "" then
        api.nvim__ns_set(ns, { wins = { win } })
    end
end

---@param buf uinteger
local function buf_rm_autocmds(buf)
    local buf_group = buf_group_name_get(buf)
    if fn.exists("#" .. buf_group) == 1 then
        api.nvim_del_augroup_by_name(buf_group)
    end
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
            if not (client ~= nil and client:supports_method(METHOD)) then
                return
            end

            buf_autocmds_create(buf)
        end,
    })

    api.nvim_create_autocmd("LspDetach", {
        group = group,
        -- Schedule wrap so that the detached client's active buffers are updated.
        callback = vim.schedule_wrap(function(ev)
            local buf = ev.buf
            local client_id = ev.data.client_id ---@type uinteger?
            if client_id then
                req_cancel(buf, client_id)
            end

            local buf_clients = lsp.get_clients({ bufnr = buf, method = METHOD })
            if #buf_clients == 0 then
                buf_rm_autocmds(buf)
                from_buf_res_reset(ev.buf, "del")
            end
        end),
    })

    api.nvim_create_autocmd("WinEnter", {
        group = group,
        callback = function()
            set_ns_win(api.nvim_get_current_win())
        end,
    })

    -- Because WinEnter can't have fired yet.
    set_ns_win(api.nvim_get_current_win())
end

-- MID: This fires if the user does something like
-- require("catharsis.document_highlight").enable(false), requiring the whole teardown to be
-- performed.
autocmds_create()

----------------------
-- MARK: Enablement --
----------------------

---@param buf integer
local function buf_enable(buf)
    bufs_disabled[buf] = nil
    if is_enabled == false then
        return
    end

    buf_autocmds_create(buf)
    request_debounced(buf, true, false)
end

---@param buf integer
local function buf_disable(buf)
    require("nvim-tools.timers").timers_rm(timers, buf)
    buf_rm_autocmds(buf)
    from_buf_res_reset(buf, "del")
    bufs_disabled[buf] = true
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
    if is_enabled == false then
        return
    end

    local cur_buf = api.nvim_get_current_buf()
    local client_has_cur_buf = false
    for buf, _ in pairs(client.attached_buffers) do
        if bufs_disabled[buf] == nil then
            buf_autocmds_create(buf)
            if buf == cur_buf then
                client_has_cur_buf = true
            end
        end
    end

    if client_has_cur_buf == false then
        return
    end

    request_debounced(cur_buf, true, true)
end

---@param client_id integer
local function client_disable(client_id)
    for buf, _ in pairs(reqs) do
        req_cancel(buf, client_id)
    end

    client_ids_disabled[client_id] = true
end

local M = {}

---@param enabled boolean?
---@param bufs integer[]?
---@param client_ids integer[]?
function M.enable(enabled, bufs, client_ids)
    if enabled ~= false then
        enabled = true
    end

    local has_specifics = false
    if bufs then
        has_specifics = true
        local status_fn = enabled == true and buf_enable or buf_disable
        for _, buf in ipairs(bufs) do
            status_fn(buf)
        end
    end

    if client_ids then
        has_specifics = true
        local status_fn = enabled == true and client_enable or client_disable
        for _, client_id in ipairs(client_ids) do
            status_fn(client_id)
        end
    end

    if has_specifics == true then
        return
    end

    local was_enabled = is_enabled
    is_enabled = enabled
    if is_enabled == true then
        if was_enabled == false then
            autocmds_create()
            for _, client in ipairs(lsp.get_clients({ method = METHOD })) do
                for buf, _ in pairs(client.attached_buffers) do
                    if bufs_disabled[buf] == nil then
                        buf_autocmds_create(buf)
                    end
                end
            end
        end

        return
    end

    for buf, _ in pairs(reqs) do
        req_cancel(buf)
    end

    local nti = require("nvim-tools.timers")
    for buf, _ in pairs(timers) do
        nti.timers_rm(timers, buf)
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
        res_reset(res, buf, "del")
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

return M

-- TODO: If you open the first win on a valid highlight it doesn't highlight.
-- TODO: Issue where you have foo.bar, you change to foo_bar with your cursor on the middle char
-- and it perceives an active highlight and doesn't redraw. Or was it going from _ to .?

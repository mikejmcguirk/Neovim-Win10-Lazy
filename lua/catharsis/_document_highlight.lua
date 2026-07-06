local api = vim.api
local fn = vim.fn
local hl_user = vim.hl.priorities.user
local lsp = vim.lsp
local util = lsp.util
local uv = vim.uv

local DOC_HL = "textDocument/documentHighlight"
local protocol = require("vim.lsp.protocol")
local KIND_READ = protocol.DocumentHighlightKind.Read
-- local KIND_TEXT = protocol.DocumentHighlightKind.Text
local KIND_WRITE = protocol.DocumentHighlightKind.Write

local read_hl = api.nvim_get_hl_id_by_name("LspReferenceRead")
local text_hl = api.nvim_get_hl_id_by_name("LspReferenceText")
local write_hl = api.nvim_get_hl_id_by_name("LspReferenceWrite")

-----------------
-- MARK: State --
-----------------

---@class mjm.lsp.documentHighlight.Result
---@field bot? integer
---@field bot_idx? integer
---@field has_decor boolean
---@field highlights nvim-tools.range.DocHl[]
---@field top? integer
---@field top_idx? integer
---@field version integer

local state_actv_req = { buf = 0, client_id = 0, id = 0 }
local state_client_ids_disabled = {} ---@type table<uinteger, true|nil>
local state_ns = api.nvim_create_namespace("mjm.lsp.document_highlight")
local state_results = {} ---@type table<integer, mjm.lsp.documentHighlight.Result|nil>
local state_timer = assert(uv.new_timer()) ---@type uv.uv_timer_t

local function actv_req_clear()
    state_actv_req.buf = 0
    state_actv_req.client_id = 0
    state_actv_req.id = 0
end

---@param buf uinteger
---@param client_id? uinteger
---@param client? vim.lsp.Client
local function actv_req_cancel(buf, client_id, client)
    if buf ~= state_actv_req.buf then
        return
    end

    local actv_req_client_id = state_actv_req.client_id
    client_id = client_id or actv_req_client_id
    if client_id ~= actv_req_client_id then
        return
    end

    client = client or lsp.get_client_by_id(client_id)
    if not client or client.id ~= client_id then
        return
    end

    client:cancel_request(state_actv_req.id)
    actv_req_clear()
end

---@param buf integer
local function actv_req_and_timer_stop(buf)
    require("nvim-tools.timers").timer_stop(state_timer)
    actv_req_cancel(buf)
end

---@param buf uinteger
---@param client_id uinteger
---@param req_id uinteger
local function actv_req_new(buf, client_id, req_id)
    state_actv_req.buf = buf
    state_actv_req.client_id = client_id
    state_actv_req.id = req_id
end

---@param res mjm.lsp.documentHighlight.Result
---@param buf uinteger
---@param wipe "all"|"decor"|"del"
local function res_reset(res, buf, wipe)
    local has_decor = res.has_decor == true
    if has_decor then
        api.nvim_buf_clear_namespace(buf, state_ns, 0, -1)
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
            local ntt = require("nvim-tools.table")
            ntt.i_clear(res.highlights)
            res.version = -1
        end
    end

    if wipe == "del" then
        state_results[buf] = nil
    end

    if has_decor then
        api.nvim__redraw({ buf = buf, valid = true, flush = false })
    end
end

---@param buf uinteger
---@param wipe "all"|"decor"|"del"
local function from_buf_res_reset(buf, wipe)
    local buf_res = state_results[buf]
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
        if ntr.find_pos(res.highlights, cur_pos_ext) ~= nil then
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
    local buf_res = state_results[buf]
    if buf_res then
        return res_ensure_updated(buf_res, buf, version, cur_pos_ext)
    end

    return false
end

---@param buf integer
---@param hls nvim-tools.range.DocHl[]
---@param version integer
local function result_set_or_new(buf, hls, version)
    local res = state_results[buf]
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

    state_results[buf] = {
        bot = -1,
        bot_idx = -1,
        has_decor = false,
        highlights = hls,
        top = -1,
        top_idx = -1,
        version = version,
    }
end

----------------
-- MARK: Util --
----------------

---@param mode string
---@return -1|0|1
----  1: Normal mode. Can create new requests and decorate.
----  0: Operator pending or cmd mode. Can decorate only.
---- -1: Others. Do not advance highlight state.
local function mode_get_status(mode)
    local byte_one = string.byte(mode, 1)
    if byte_one == 110 then
        if #mode == 1 then
            return 1
        elseif string.byte(mode, 2) == 111 then
            return 0
        else
            return -1
        end
    end

    return byte_one == 99 and 0 or -1
end

---------------------
-- MARK: Redrawing --
---------------------

---@param buf integer
---@param hl_info nvim-tools.range.DocHl
local function set_mark(buf, hl_info)
    api.nvim_buf_set_extmark(buf, state_ns, hl_info[1], hl_info[2], {
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
    local res = state_results[buf]
    if not res then
        return
    end

    local hls = res.highlights
    if #hls == 0 then
        return
    end

    if mode_get_status(api.nvim_get_mode().mode) < 0 then
        return
    end

    if not res.has_decor then
        local top_idx = vim.list.bisect(hls, { top, 0, 0, 0 }, {
            key = function(hl)
                return hl[1]
            end,
        })

        local bot_idx = vim.list.bisect(hls, { 0, 0, bot, 0 }, {
            bound = "upper",
            key = function(hl)
                return hl[3]
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

    if top < res.top then
        local top_idx = vim.list.bisect(hls, { top, 0, 0, 0 }, {
            key = function(hl)
                return hl[1]
            end,
        })

        local old_top_idx = res.top_idx or 1
        for i = top_idx, old_top_idx - 1 do
            set_mark(buf, hls[i])
        end

        res.top = top
        res.top_idx = top_idx
    end

    if res.bot < bot then
        local bot_idx = vim.list.bisect(hls, { 0, 0, bot, 0 }, {
            bound = "upper",
            key = function(hl)
                return hl[3]
            end,
        }) - 1

        local old_bot_idx = res.bot_idx or #hls
        for i = old_bot_idx + 1, bot_idx do
            set_mark(buf, hls[i])
        end

        res.bot = bot
        res.bot_idx = bot_idx
    end
end

api.nvim_set_decoration_provider(state_ns, { on_win = on_win })

----------------------------------------
-- MARK: Request Sending and Handling --
----------------------------------------

---@param win integer
---@param buf integer
---@param cur_pos_ext [integer, integer]
---@return boolean
local function response_has_current_nvim_state(win, buf, cur_pos_ext)
    if win ~= api.nvim_get_current_win() then
        return false
    end

    if buf ~= api.nvim_win_get_buf(win) then
        return false
    end

    local cur_pos = api.nvim_win_get_cursor(win)
    local cur_cur_pos_ext = require("nvim-tools.pos").mark_to_ext_pos(cur_pos)
    if not require("nvim-tools.table").i_equals(cur_pos_ext, cur_cur_pos_ext) then
        return false
    end

    return true
end

---@param err lsp.ResponseError?
---@param response lsp.DocumentHighlight[]?
---@param ctx lsp.HandlerContext
---@param buf uinteger
---@param win uinteger
---@param cur_pos_ext[uinteger, uinteger]
local function doc_hl_req_handler(err, response, ctx, buf, win, cur_pos_ext)
    local client_id = state_actv_req.client_id
    local req_id = state_actv_req.id
    actv_req_clear()

    if ctx.bufnr ~= buf then
        return
    end

    if ctx.request_id ~= req_id or ctx.client_id ~= client_id then
        return
    end

    local ctx_version = ctx.version
    if ctx_version == nil or ctx_version < util.buf_versions[buf] then
        return
    end

    local client = lsp.get_client_by_id(client_id)
    if not client then
        return false
    end

    if err then
        local msg = client.name .. " - " .. err.code .. ": " .. err.message
        require("nvim-tools.lsp").log_and_echo(msg, 4, "ErrorMsg", true)
        return
    end

    -- Both valid per the spec.
    if response == nil or #response == 0 then
        return
    end

    local buf_res = state_results[buf]
    if buf_res and ctx_version <= buf_res.version then
        return
    end

    if not response_has_current_nvim_state(win, buf, cur_pos_ext) then
        return
    end

    local nts = require("nvim-tools.lsp")
    local hls = nts.doc_hls_to_api_ranges(response, client.offset_encoding, buf)
    for _, hl in ipairs(hls) do
        local kind = hl[5]
        if kind == KIND_READ then
            hl[5] = read_hl
        elseif kind == KIND_WRITE then
            hl[5] = write_hl
        else
            hl[5] = text_hl
        end
    end

    result_set_or_new(buf, hls, ctx_version)
    api.nvim__redraw({ buf = buf, valid = true, flush = false })
end

---@param buf uinteger
---@param version boolean Verify current result is up to date.
---@param prev_hls boolean Abort if a valid highlight is present.
local function request_debounced(buf, version, prev_hls)
    if mode_get_status(api.nvim_get_mode().mode) < 1 then
        return
    end

    local cur_win = api.nvim_get_current_win()
    local cur_win_buf = api.nvim_win_get_buf(cur_win)
    if cur_win_buf ~= buf then
        return
    end

    local ns_wins = api.nvim__ns_get(state_ns).wins
    if ns_wins == nil or ns_wins[1] ~= cur_win then
        return
    end

    local ntp = require("nvim-tools.pos")
    local cur_pos_ext = ntp.mark_to_ext_pos(api.nvim_win_get_cursor(cur_win))
    if from_buf_res_ensure_uptd(buf, version, (prev_hls and cur_pos_ext or nil)) == true then
        return
    end

    actv_req_and_timer_stop(buf)
    local clients = lsp.get_clients({ bufnr = buf, method = DOC_HL })
    require("nvim-tools.table").i_discard(clients, function(client)
        return state_client_ids_disabled[client.id] ~= nil
    end)

    local nts = require("nvim-tools.lsp")
    local client_id, client = nts.clients_find_top_scoring(clients, buf, { DOC_HL })
    if client_id == nil or client == nil then
        return
    end

    uv.timer_start(
        state_timer,
        client.flags.debounce_text_changes or 150,
        0,
        vim.schedule_wrap(function()
            if not api.nvim_buf_is_valid(buf) then
                return
            end

            local encoding = client.offset_encoding
            local params = nts.text_doc_pos_params_create(buf, cur_pos_ext, encoding)
            local req_success, req_id = client:request(DOC_HL, params, function(err, response, ctx)
                doc_hl_req_handler(err, response, ctx, buf, cur_win, cur_pos_ext)
            end, buf)

            if req_success and req_id then
                actv_req_new(buf, client_id, req_id)
            end
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

---@param win uinteger
---@return boolean
local function set_ns_win(win)
    if fn.win_gettype(win) == "" then
        api.nvim__ns_set(state_ns, { wins = { win } })
        return true
    end

    return false
end

---@type catharsis.feature.Spec
local M = {
    on_client_add = function(client_id)
        state_client_ids_disabled[client_id] = nil
    end,
    on_client_detach = function(buf, client_id, client)
        actv_req_cancel(buf, client_id, client)
    end,
    on_client_rm = function(client_id)
        state_client_ids_disabled[client_id] = true
    end,
    method = DOC_HL,
    on_buf_add = function(bufnr)
        local buf_group_name = buf_group_name_get(bufnr)
        if fn.exists("#" .. buf_group_name) == 1 then
            return
        end

        local buf_group = api.nvim_create_augroup(buf_group_name, {})
        api.nvim_create_autocmd({ "CursorMoved" }, {
            group = buf_group,
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

        api.nvim_create_autocmd("ModeChanged", {
            group = buf_group,
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

        api.nvim_create_autocmd("WinEnter", {
            group = buf_group,
            callback = function()
                set_ns_win(api.nvim_get_current_win())
            end,
        })

        local cur_win = api.nvim_get_current_win()
        local cur_buf = api.nvim_win_get_buf(cur_win)
        if cur_buf == bufnr and set_ns_win(cur_win) then
            request_debounced(cur_buf, false, false)
        end
    end,

    on_buf_rm = function(buf)
        local buf_group = buf_group_name_get(buf)
        if fn.exists("#" .. buf_group) == 1 then
            api.nvim_del_augroup_by_name(buf_group)
        end

        from_buf_res_reset(buf, "del")
    end,
    -- TODO-DEP: When v0.14 comes out, change all instances of "buffer" to "buf"
}

---@param count uinteger
---@param upward boolean
---@diagnostic disable-next-line: inject-field
function M.jump(count, upward)
    local win = api.nvim_get_current_win()
    local win_buf = api.nvim_win_get_buf(win)
    local res = state_results[win_buf]
    if not res or #res.highlights == 0 then
        api.nvim_echo({ { "No document highlights" } }, false, {})
        return
    end

    local hls = res.highlights
    local cur_pos_ext = require("nvim-tools.pos").mark_to_ext_pos(api.nvim_win_get_cursor(win))
    local row = cur_pos_ext[1]
    local col = cur_pos_ext[2]
    local idx = vim.list.bisect(hls, { row, col, row, col }, {
        key = require("nvim-tools.range").bit_pack_key,
    })

    local step = upward and -1 or 1
    local target_idx = idx + step * math.max(count, 1)
    if target_idx < 1 then
        target_idx = 1
    elseif target_idx > #hls then
        target_idx = #hls
    end

    if target_idx == idx then
        api.nvim_echo({ { "No more document highlights" } }, false, {})
        return
    end

    local target = hls[target_idx]
    api.nvim_win_set_cursor(win, { target[1] + 1, target[2] })
end
-- TODO: make a public interface for this

return M

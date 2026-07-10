local api = vim.api
local fn = vim.fn
local hl_user = vim.hl.priorities.user
local lsp = vim.lsp
local util = lsp.util

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
---@field highlights nvim-tools.range.DocHl[]
---@field top? integer
---@field top_idx? integer
---@field version integer

local state_client_ids_disabled = {} ---@type table<uinteger, true|nil>
local state_ns = api.nvim_create_namespace("mjm.lsp.document_highlight")
local state_reqs = {} ---@type table<uinteger, { client_id:uinteger, id:uinteger }>
local state_results = {} ---@type table<integer, mjm.lsp.documentHighlight.Result|nil>
local state_timers = {} ---@type table<uinteger, uv.uv_timer_t>

---@param buf uinteger
---@param client_id? uinteger
---@param client? vim.lsp.Client
local function req_cancel(buf, client_id, client)
    local req = state_reqs[buf]
    if req == nil then
        return
    end

    local req_client_id = req.client_id
    client_id = client_id or req.client_id
    if client_id ~= req_client_id then
        return
    end

    state_reqs[buf] = nil
    client = client or lsp.get_client_by_id(client_id)
    if not client or client.id ~= client_id then
        return
    end

    client:cancel_request(req.id)
end

---@param buf uinteger
local function timer_and_req_cancel(buf)
    req_cancel(buf)
    require("nvim-tools.timers").timers_stop(state_timers, buf)
end

---@param res mjm.lsp.documentHighlight.Result
---@param buf uinteger
---@param wipe "decor"|"del"
local function res_clear(res, buf, wipe)
    local has_decor = #api.nvim_buf_get_extmarks(buf, state_ns, 0, -1, { limit = 1 }) > 0
    if has_decor then
        if api.nvim_buf_is_valid(buf) then
            api.nvim_buf_clear_namespace(buf, state_ns, 0, -1)
        end
    end

    if wipe == "decor" then
        res.bot = -1
        res.bot_idx = -1
        res.top = -1
        res.top_idx = -1
    else
        state_results[buf] = nil
    end

    if has_decor then
        api.nvim__redraw({ buf = buf, valid = true, flush = false })
    end
end

---@param buf uinteger
---@param wipe "decor"|"del"
local function from_buf_res_clear(buf, wipe)
    local buf_res = state_results[buf]
    if buf_res then
        res_clear(buf_res, buf, wipe)
    end
end

---@param buf integer
---@param hls nvim-tools.range.DocHl[]
---@param version integer
local function result_set(buf, hls, version)
    state_results[buf] = {
        bot = -1,
        bot_idx = -1,
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

---@param kind lsp.DocumentHighlightKind?
---@return uinteger
local function hl_group_get(kind)
    if kind == KIND_READ then
        return read_hl
    elseif kind == KIND_WRITE then
        return write_hl
    else
        return text_hl
    end
end

---@param buf integer
---@param hl_info nvim-tools.range.DocHl
local function set_mark(buf, hl_info)
    api.nvim_buf_set_extmark(buf, state_ns, hl_info[1], hl_info[2], {
        end_col = hl_info[4],
        end_row = hl_info[3],
        hl_group = hl_group_get(hl_info[5]),
        priority = hl_user,
        strict = false,
    })
end

-- Don't need win param because the namespace is window-scoped.
---@param buf integer
---@param top integer
---@param bot integer
local function on_win(_, win, buf, top, bot)
    local res = state_results[buf]
    if not res then
        return
    end

    local hls = res.highlights
    if #hls == 0 or mode_get_status(api.nvim_get_mode().mode) < 0 then
        return
    end

    -- ns_set scopes which windows extmarks are drawn to, but not which wins on_win is called for.
    -- ISSUE: This is unintuitive behavior.
    local ns_wins = api.nvim__ns_get(state_ns).wins
    if ns_wins == nil or ns_wins[1] ~= win then
        return false
    end

    if #api.nvim_buf_get_extmarks(buf, state_ns, 0, -1, { limit = 1 }) == 0 then
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

---@param err lsp.ResponseError?
---@param response lsp.DocumentHighlight[]?
---@param ctx lsp.HandlerContext
---@param buf uinteger
---@param win uinteger
---@param pos_ext[uinteger, uinteger]
local function doc_hl_req_handler(err, response, ctx, buf, win, pos_ext)
    local req = state_reqs[buf]
    if not req then
        return
    end

    local client_id = req.client_id
    local req_id = req.id
    if ctx.request_id ~= req_id or ctx.client_id ~= client_id then
        return
    end

    state_reqs[buf] = nil
    local ctx_version = ctx.version
    if ctx_version == nil or ctx_version < util.buf_versions[buf] then
        return
    end

    local client = lsp.get_client_by_id(client_id)
    if not client then
        return false
    end

    if not require("catharsis._util").req_matches_nvim_state(win, buf, pos_ext) then
        return
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

    local nts = require("nvim-tools.lsp")
    local hls = nts.doc_hls_to_api_ranges(response, client.offset_encoding, buf)
    result_set(buf, hls, ctx_version)
    api.nvim__redraw({ buf = buf, valid = true, flush = false })
end

---@param res mjm.lsp.documentHighlight.Result
---@param buf uinteger
---@param pos_ext [uinteger, uinteger]
---@return boolean, boolean, boolean
local function from_res_hls_validate(res, buf, pos_ext)
    if require("nvim-tools.range").find_pos(res.highlights, pos_ext) == nil then
        return true, true, false
    else
        return false, false, #api.nvim_buf_get_extmarks(buf, state_ns, 0, -1, { limit = 1 }) == 0
    end
end

---@param buf uinteger
---@param pos_ext [uinteger, uinteger]
---@return boolean, boolean, boolean
local function hls_validate(buf, pos_ext)
    local res = state_results[buf]
    if res == nil then
        return true, false, false
    else
        return from_res_hls_validate(res, buf, pos_ext)
    end
end

---@param res mjm.lsp.documentHighlight.Result
---@param buf uinteger
---@return boolean, boolean, boolean
local function from_res_version_validate(res, buf, _)
    local res_version = res.version
    local uptd = res_version > -1 and res_version ~= util.buf_versions[buf]
    return uptd, uptd, false
end

---@param buf uinteger
---@return boolean, boolean, boolean
local function version_validate(buf, _)
    local res = state_results[buf]
    if res == nil then
        return true, false, false
    else
        return from_res_version_validate(res, buf)
    end
end

---@param buf uinteger
---@param pos_ext [uinteger, uinteger]
---@return boolean, boolean, boolean
local function both_validate(buf, pos_ext)
    local res = state_results[buf]
    if res == nil then
        return true, false, false
    end

    local do_req, rm_hls, do_redraw = from_res_version_validate(res, buf)
    if not do_req then
        do_req, rm_hls, do_redraw = from_res_hls_validate(res, buf, pos_ext)
    end

    return do_req, rm_hls, do_redraw
end

---@param buf uinteger
---@param f function
---Returns:
---- do_req : Continue req?
---- rm_hls : Remove current hls?
---- do_redraw : Perform redraw?
local function req_debounced(buf, f)
    if mode_get_status(api.nvim_get_mode().mode) < 1 then
        return
    end

    local win = api.nvim_get_current_win()
    local ns_wins = api.nvim__ns_get(state_ns).wins
    if ns_wins == nil or ns_wins[1] ~= win or api.nvim_win_get_buf(win) ~= buf then
        return
    end

    local pos_ext = require("nvim-tools.win").cursor_ext_get(win)
    local do_req, rm_hls, do_redraw = f(buf, pos_ext)
    if do_req then
        timer_and_req_cancel(buf)
    end

    if rm_hls then
        from_buf_res_clear(buf, "del")
    end

    if do_redraw then
        api.nvim__redraw({ buf = buf, valid = true, flush = false })
    end

    if not do_req then
        return
    end

    local clients = lsp.get_clients({ bufnr = buf, method = DOC_HL })
    require("nvim-tools.table").i_keep(clients, function(client)
        return state_client_ids_disabled[client.id] == nil
    end)

    local nts = require("nvim-tools.lsp")
    local client_id, client = nts.clients_find_top_scoring(clients, buf, { DOC_HL })
    if client_id == nil or client == nil then
        return
    end

    require("nvim-tools.timers").timers_do_after_debounce(
        state_timers,
        buf,
        client.flags.debounce_text_changes or 150,
        vim.schedule_wrap(function()
            if not api.nvim_buf_is_valid(buf) then
                return
            end

            local encoding = client.offset_encoding
            local params = nts.text_doc_pos_params_create(buf, pos_ext, encoding)
            local req_success, req_id = client:request(DOC_HL, params, function(err, response, ctx)
                doc_hl_req_handler(err, response, ctx, buf, win, pos_ext)
            end, buf)

            if req_success and req_id then
                state_reqs[buf] = { client_id = client_id, id = req_id }
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
    if fn.win_gettype(win) ~= "" then
        return false
    end

    -- ns_set stages a redraw. Avoid if we can.
    local ns_wins = api.nvim__ns_get(state_ns).wins
    if ns_wins == nil or ns_wins[1] ~= win then
        api.nvim__ns_set(state_ns, { wins = { win } })
    end

    return true
end

---@class catharsis.DocumentHighlight : catharsis.feature.Spec
local M = {
    on_client_add = function(client_id)
        state_client_ids_disabled[client_id] = nil
    end,
    on_client_detach = function(buf, client_id, client)
        req_cancel(buf, client_id, client)
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
            -- CursorMoved fires after WinEnter, so we don't need to req there. Because WinEnter
            -- is schedule wrapped, do the same here to maintain execution order.
            callback = vim.schedule_wrap(function(ev)
                req_debounced(ev.buf, hls_validate)
            end),
        })

        api.nvim_create_autocmd("LspNotify", {
            buffer = bufnr,
            group = buf_group,
            desc = "Refresh document highlights on document changes",
            callback = vim.schedule_wrap(function(ev)
                local method = ev.data.method --- @type string
                if method == "textDocument/didChange" then
                    req_debounced(ev.buf, version_validate)
                elseif method == "textDocument/didOpen" then
                    req_debounced(ev.buf, version_validate)
                elseif method == "textDocument/didClose" then
                    local buf = ev.buf
                    timer_and_req_cancel(buf)
                    from_buf_res_clear(buf, "del")
                end
            end),
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
                    req_debounced(buf, both_validate)
                elseif nm_status == -1 then
                    timer_and_req_cancel(buf)
                    from_buf_res_clear(buf, "decor")
                end
            end,
        })

        api.nvim_create_autocmd("WinEnter", {
            group = buf_group,
            callback = vim.schedule_wrap(function()
                set_ns_win(api.nvim_get_current_win())
            end),
        })

        -- nvim_exec_autocmds would be too broad here.
        vim.schedule(function()
            local cur_win = api.nvim_get_current_win()
            if api.nvim_win_get_buf(cur_win) == bufnr and set_ns_win(cur_win) then
                req_debounced(bufnr, version_validate)
            end
        end)
    end,

    on_buf_rm = function(buf)
        timer_and_req_cancel(buf)
        local buf_group = buf_group_name_get(buf)
        if fn.exists("#" .. buf_group) == 1 then
            api.nvim_del_augroup_by_name(buf_group)
        end

        from_buf_res_clear(buf, "del")
    end,
    -- TODO-DEP: When v0.14 comes out, change all instances of "buffer" to "buf"
}

---@param hls nvim-tools.range.DocHl[]
---@param abs boolean
---@param count uinteger
---@param upward boolean
---@param win uinteger
---@return boolean, uinteger
function jump_get_idx_dest(hls, abs, count, upward, win)
    if abs then
        return true, count == 0 and (upward and 1 or #hls) or math.min(#hls, count)
    end

    local pos_ext = require("nvim-tools.win").cursor_ext_get(win)
    local cursor_ext_range = { pos_ext[1], pos_ext[2], pos_ext[1], pos_ext[2] + 1 }
    local idx_cur = vim.list.bisect(hls, cursor_ext_range, {
        key = function(hl)
            local cmp_res = require("nvim-tools.range").cmp_(hl, cursor_ext_range)
            if cmp_res == -2 or cmp_res == -1 then
                return -1
            elseif cmp_res == 1 or cmp_res == 2 then
                return 1
            else
                return 0
            end
        end,
    })

    local idx_dest = idx_cur + (upward and -1 or 1) * math.max(count, 1)
    idx_dest = upward and math.max(idx_dest, 1) or math.min(idx_dest, #hls)
    return idx_dest ~= idx_cur and true or false, idx_dest
end

---@class catharsis.documentHighlight.JumpCtx
---@field zzze boolean

---@param win uinteger
---@param buf uinteger
---@param count uinteger If `abs` is `true`, count `0` will jump to the first or last highlight.
---A count greater than zero will jump to the highlight at that index, clamped to max.
---@param abs boolean
---@param upward boolean
---@param ctx catharsis.documentHighlight.JumpCtx
function M.jump(win, buf, count, abs, upward, ctx)
    ---@type nvim-tools.range.DocHl[]
    local hls = require("nvim-tools.table").get(state_results, buf, "highlights")
    if hls == nil or #hls == 0 then
        api.nvim_echo({ { "No document highlights" } }, false, {})
        return
    end

    local ok, idx_dest = jump_get_idx_dest(hls, abs, count, upward, win)
    if not ok then
        api.nvim_echo({ { "No more document highlights" } }, false, {})
        return
    end

    local dest = hls[idx_dest]
    local sr = dest[1]
    local off_screen = sr < vim.call("line", "w0") or vim.call("line", "w$") < sr
    if off_screen then
        api.nvim_cmd({ cmd = "norm", args = { "m'" }, bang = true }, {})
    end

    api.nvim_win_set_cursor(win, { sr + 1, dest[2] })
    api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
    if off_screen and ctx.zzze then
        api.nvim_cmd({ cmd = "norm", args = { "zzze" }, bang = true }, {})
    end
end

return M

local api = vim.api
local fn = vim.fn
local hl_user = vim.hl.priorities.user
local lsp = vim.lsp
local protocol = require("vim.lsp.protocol")
local util = lsp.util
local uv = vim.uv

local METHOD = "textDocument/documentHighlight"

local M = {}

local is_enabled = true
local active_bufs = {} ---@type table<integer, boolean>
local active_client_ids = {} ---@type table<integer, boolean>

local ns = api.nvim_create_namespace("mjm.lsp.document_highlight")

-- Hl group, start_row, start_col, end_row, end_col
---@alias mjm.lsp.DocumentHighlight.Hl [string, integer, integer, integer, integer]

---@class mjm.lsp.documentHighlight.Request
---@field id integer
---@field cur_pos [integer, integer]
---@field cur_win integer

local client_requests = {} ---@type table<integer, mjm.lsp.documentHighlight.Request>
local buf_timers = {} ---@type table<integer, uv.uv_timer_t>
local results = {} ---@type table<integer, mjm.lsp.documentHighlight.Result>

---@param buf integer
local function all_hls_clear(buf)
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    results[buf] = nil
end

---@param old_res mjm.lsp.documentHighlight.Result?
---@param win integer
---@param buf integer
---@param cur_pos [integer, integer]
local function handle_old_results(old_res, win, buf, cur_pos)
    if type(old_res) == "nil" then
        return
    end

    if old_res.version ~= util.buf_versions[buf] then
        all_hls_clear(buf)
        api.nvim__redraw({ buf = buf, valid = true, flush = false })
        return
    end

    if old_res.win ~= win then
        all_hls_clear(buf)
        api.nvim__redraw({ buf = buf, valid = true, flush = false })
        return
    end

    require("nvim-tools.pos").mark_to_ext_pos(cur_pos)
    local under_cursor = #api.nvim_buf_get_extmarks(0, ns, cur_pos, cur_pos, {
        details = true,
        limit = 1,
        overlap = true,
    }) > 0

    if not under_cursor then
        all_hls_clear(buf)
        api.nvim__redraw({ buf = buf, valid = true, flush = false })
    end
end

-- MID: Use array indexing for these.
---@class mjm.lsp.documentHighlight.Result
---@field version integer
---@field highlights mjm.lsp.DocumentHighlight.Hl[]
---@field top? integer
---@field bot? integer
---@field cur_pos [integer, integer]
---@field win integer

---@param enabled boolean?
---@param bufs integer[]?
---@param clients integer[]?
function M.enable(enabled, bufs, clients)
    if enabled ~= false then
        enabled = true
    else
        enabled = false
    end

    if bufs == nil and clients == nil then
        is_enabled = enabled
        if is_enabled == false then
            for client_id, request in pairs(client_requests) do
                local client = lsp.get_client_by_id(client_id)
                if client then
                    client:cancel_request(request.id)
                end

                client_requests[client_id] = nil
            end

            for buf, _ in pairs(active_bufs) do
                all_hls_clear(buf)
            end

            for buf, _ in pairs(results) do
                results[buf] = nil
            end
        end

        return
    end

    if bufs then
        for _, buf in ipairs(bufs) do
            active_bufs[buf] = enabled
        end
    end

    if clients then
        for _, client in ipairs(clients) do
            active_client_ids[client] = enabled
        end
    end
end
-- TODO: Better handle cleanup on disabling.

---@param buf integer?
---@param client_id integer?
function M.is_enabled(buf, client_id)
    if buf ~= nil then
        return active_bufs[buf]
    elseif client_id ~= nil then
        return active_client_ids[client_id]
    else
        return is_enabled
    end
end

local doc_hl_group = api.nvim_create_augroup("mjm.lsp.document_highlight", {})

local function set_mark(buf, nsp, grp, sr, sc, fr, fc)
    api.nvim_buf_set_extmark(buf, nsp, sr, sc, {
        hl_group = grp,
        end_row = fr,
        end_col = fc,
        priority = hl_user,
        strict = false,
    })
end

---@param buf integer
---@param top integer
---@param bot integer
local function on_win(_, _, buf, top, bot)
    local result = results[buf]
    if not result then
        return
    end

    local buf_version = util.buf_versions[buf]
    if result.version ~= buf_version then
        all_hls_clear(buf)
        return
    end

    local hls = result.highlights
    local res_top = result.top
    local res_bot = result.bot
    if res_top == nil or res_bot == nil then
        api.nvim_buf_clear_namespace(buf or 0, ns, 0, -1)
        for _, hl in ipairs(hls) do
            if top <= hl[4] or hl[2] <= bot then
                set_mark(buf, ns, hl[1], hl[2], hl[3], hl[4], hl[5])
            end
        end

        result.top = top
        result.bot = bot
    else
        if res_top < top then
            for _, hl in ipairs(hls) do
                if res_top <= hl[4] or hl[2] < bot then
                    set_mark(buf, ns, hl[1], hl[2], hl[3], hl[4], hl[5])
                end
            end
        end

        if bot < res_bot then
            for _, hl in ipairs(hls) do
                if bot < hl[4] or hl[2] <= res_bot then
                    set_mark(buf, ns, hl[1], hl[2], hl[3], hl[4], hl[5])
                end
            end
        end
    end
end
-- TODO: Sort then bisec these results so that traversal is more efficient.

api.nvim_set_decoration_provider(ns, {
    on_win = on_win,
})

local function handler(_, result, ctx)
    -- TODO: handle err

    local client_id = ctx.client_id
    local request = client_requests[client_id]
    client_requests[client_id] = nil
    if not request then
        return
    end

    local ctx_version = ctx.version
    local buf = ctx.bufnr
    local buf_version = util.buf_versions[buf]
    if ctx_version ~= buf_version then
        return
    end

    local cur_win = api.nvim_get_current_win()
    local cur_pos = api.nvim_win_get_cursor(cur_win)
    local ntl = require("nvim-tools.list")
    local prev_res = results[buf]
    if not (request.cur_win == cur_win and ntl.cmp(request.cur_pos, cur_pos)) then
        handle_old_results(prev_res, cur_win, buf, cur_pos)
        return
    end

    if result == nil then
        -- The spec allows the server to return a null result if it finds no valid highlights.
        -- Previous highlights might still be valid.
        handle_old_results(prev_res, cur_win, buf, cur_pos)
        return
    end

    if api.nvim_get_mode().mode ~= "n" then
        return
    end

    -- Unsure what the use case would be for allowing two servers to return documentHighlight data.
    if
        prev_res
        and prev_res.version == ctx_version
        and ntl.cmp(prev_res.cur_pos, cur_pos)
        and prev_res.win == cur_win
    then
        return
    end

    local client = lsp.get_client_by_id(ctx.client_id)
    if not client then
        return
    end

    local offset_encoding = client.offset_encoding
    local hls = {} ---@type mjm.lsp.DocumentHighlight.Hl[]
    local document_highlight_kind = {
        [protocol.DocumentHighlightKind.Text] = "LspReferenceText",
        [protocol.DocumentHighlightKind.Read] = "LspReferenceRead",
        [protocol.DocumentHighlightKind.Write] = "LspReferenceWrite",
    }

    for _, ref in ipairs(result) do
        local range = vim.range.lsp(buf, ref.range, offset_encoding)
        local kind = ref["kind"] or protocol.DocumentHighlightKind.Text
        hls[#hls + 1] = {
            document_highlight_kind[kind],
            range.start_row,
            range.start_col,
            range.end_row,
            range.end_col,
        }
    end

    results[buf] = {
        version = ctx.version,
        highlights = hls,
        cur_pos = cur_pos,
        win = cur_win,
    }

    api.nvim__redraw({ buf = buf, valid = true, flush = false })
end

---@param buf integer
local function request(buf)
    if not is_enabled then
        return
    end

    if api.nvim_get_mode().mode ~= "n" then
        return
    end

    local clients = lsp.get_clients({ bufnr = buf })
    if #clients == 0 then
        active_bufs[buf] = nil
        return
    end

    local ntl = require("nvim-tools.list")
    ntl.filter(clients, function(client)
        return active_client_ids[client.id] == true
    end)

    if #clients == 0 then
        active_bufs[buf] = nil
        return
    end

    local cur_win = api.nvim_get_current_win()
    local cur_win_buf = api.nvim_win_get_buf(cur_win)
    if cur_win_buf ~= buf then
        return
    end

    for _, client in ipairs(clients) do
        local client_id = client.id
        local prev_request = client_requests[client_id]
        if prev_request then
            client:cancel_request(prev_request.id)
            client_requests[client_id] = nil
        end
    end

    for _, client in ipairs(clients) do
        local cparams = {
            textDocument = util.make_text_document_params(cur_win_buf),
            position = vim.pos
                .cursor(cur_win_buf, api.nvim_win_get_cursor(cur_win))
                :to_lsp(client.offset_encoding),
        }

        local request_success, request_id = client:request(METHOD, cparams, handler, buf)
        local client_id = client.id
        if request_success and request_id then
            client_requests[client_id] = {
                id = request_id,
                cur_pos = api.nvim_win_get_cursor(cur_win),
                cur_win = cur_win,
            }
        end
    end
end

---@param buf integer
local function auto_request(buf)
    if not is_enabled then
        return
    end

    if api.nvim_get_mode().mode ~= "n" then
        return
    end

    local prev = results[buf]
    if prev then
        local cur_win = api.nvim_get_current_win()
        local cur_pos = api.nvim_win_get_cursor(0)
        handle_old_results(prev, cur_win, buf, cur_pos)
    end

    local timer
    local buf_timer = buf_timers[buf]
    if buf_timer ~= nil then
        if uv.is_active(buf_timer) then
            uv.timer_stop(buf_timer)
        end

        timer = buf_timer
    else
        timer = assert(uv.new_timer())
        buf_timers[buf] = timer
    end

    uv.timer_start(
        timer,
        200,
        0,
        vim.schedule_wrap(function()
            request(buf)
        end)
    )
end
-- MID: Try to do the thing again where requests are allowed to go immediately, but then a debounce
-- is applied to the next request.

---@param buf integer
local function augroup_name_get(buf)
    return "mjm.lsp.document_highlight." .. tostring(buf)
end

api.nvim_create_autocmd("LspAttach", {
    group = doc_hl_group,
    callback = function(ev)
        local client_id = ev.data.client_id
        local client = lsp.get_client_by_id(client_id)
        if not client then
            return
        end

        if not client:supports_method("textDocument/documentHighlight") then
            return
        end

        if active_client_ids[client_id] ~= false then
            active_client_ids[client_id] = true
        end

        local buf = ev.buf
        if active_bufs[buf] ~= false then
            active_bufs[buf] = true
        end

        api.nvim_buf_attach(buf, false, {
            on_lines = function(_, bufnr)
                -- TODO: How do you put this back.
                if not active_bufs[bufnr] then
                    return true
                end

                auto_request(bufnr)
            end,
            on_reload = function(_, bufnr)
                -- TODO: How do you clean this up?
                auto_request(bufnr)
            end,
        })

        local group = augroup_name_get(buf)
        api.nvim_create_autocmd({ "CursorHold", "CursorMoved" }, {
            group = api.nvim_create_augroup(group, {}),
            -- TODO:DEP: Change this to "buf" when v0.14 comes out.
            buffer = buf,
            callback = function(inner_ev)
                auto_request(inner_ev.buf)
            end,
        })

        api.nvim_create_autocmd("BufLeave", {
            group = group,
            buffer = buf,
            callback = function(inner_ev)
                local inner_buf = inner_ev.buf
                all_hls_clear(inner_buf)
                api.nvim__redraw({ buf = inner_buf, valid = true, flush = false })
            end,
        })

        api.nvim_create_autocmd("ModeChanged", {
            group = group,
            buffer = buf,
            callback = function(inner_ev)
                local inner_buf = inner_ev.buf

                ---@diagnostic disable-next-line: undefined-field
                local old_mode_trunc = string.sub(vim.v.event.old_mode, 1, 2)
                ---@diagnostic disable-next-line: undefined-field
                local new_mode_trunc = string.sub(vim.v.event.new_mode, 1, 2)

                local n_no = old_mode_trunc == "n" and new_mode_trunc == "no"
                local no_n = old_mode_trunc == "no" and new_mode_trunc == "n"
                if n_no or no_n then
                    return
                elseif new_mode_trunc == "n" then
                    request(inner_buf)
                else
                    all_hls_clear(inner_buf)
                    api.nvim__redraw({ buf = inner_buf, valid = true, flush = false })
                end
            end,
        })

        request(buf)
    end,
})

api.nvim_create_autocmd("LspDetach", {
    group = doc_hl_group,
    callback = vim.schedule_wrap(function(ev)
        local buf = ev.buf
        local buf_clients = lsp.get_clients({ bufnr = buf })
        local ntl = require("nvim-tools.list")
        local buf_has_clients = ntl.contains(buf_clients, function(client)
            return client:supports_method("textDocument/documentHighlight")
        end)

        if not buf_has_clients then
            active_bufs[buf] = nil
            local ntm = require("nvim-tools.misc")
            ntm.stop_timer(buf_timers[buf])
            local group = augroup_name_get(buf)
            if fn.exists("#" .. group) == 1 then
                api.nvim_del_augroup_by_name(group)
            end
        end

        local client_id = ev.data.client_id
        if not client_id then
            return
        end

        local client = lsp.get_client_by_id(client_id)
        if not client then
            -- TODO: There are probably more places this cleanup is appropriate.
            active_client_ids[client_id] = nil
            client_requests[client_id] = nil
        elseif not next(client.attached_buffers) then
            active_client_ids[client_id] = nil
            client_requests[client_id] = nil
        end
    end),
})

return M

-- TODO: Make window scoped with ns__set
-- TODO: Let this live in my config for a bit then make it a plugin.
-- TODO: Polish pass.

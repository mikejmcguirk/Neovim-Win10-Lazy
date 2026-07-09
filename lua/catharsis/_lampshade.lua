local api = vim.api
local fn = vim.fn
local lsp = vim.lsp
local util = lsp.util
local uv = vim.uv

local METHOD = "textDocument/codeAction" ---@type vim.lsp.protocol.Method.ClientToServer.Request

api.nvim_set_hl(0, "CatharsisLampshade", { link = "DiagnosticInfo" })
local lamp_hl_id = api.nvim_get_hl_id_by_name("CatharsisLampshade")

-----------------
-- MARK: State --
-----------------

---@class catharsis.lampshade.LampData
---@field display fun(buf:uinteger, row:uinteger, ns:uinteger, hl_id:uinteger)
---@field has_diagnostics boolean
---@field pos_ext [uinteger, uinteger]
---@field version uinteger

---@class catharsis.lampshade.Request
---@field cancel_func function
---@field pos_ext [uinteger, uinteger]
---@field version uinteger
---@field win uinteger

local state_buf_lamp_data = {} ---@type table<uinteger, catharsis.lampshade.LampData>
local state_buf_reqs = {} ---@type table<uinteger, catharsis.lampshade.Request>
local state_ns = api.nvim_create_namespace("catharsis.lampshade")

-- Global timer since we use buf_request_all. Clients per request may overlap.
---@diagnostic disable-next-line: unnecessary-assert, call-non-callable
local state_timer = assert(uv.new_timer()) ---@type uv.uv_timer_t

---@param buf uinteger
local function lamp_data_and_ns_clear(buf)
    state_buf_lamp_data[buf] = nil
    api.nvim_buf_clear_namespace(buf, state_ns, 0, -1)
end

---@param buf uinteger
local function req_cancel(buf)
    local req = state_buf_reqs[buf]
    if req == nil then
        return
    end

    req.cancel_func()
    state_buf_reqs[buf] = nil
end

----------------
-- MARK: Util --
----------------

---@param win uinteger
---@return [uinteger, uinteger]
local function cursor_ext_get(win)
    return require("nvim-tools.pos").mark_to_ext_pos(api.nvim_win_get_cursor(win))
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

----------------------
-- MARK: Decoration --
----------------------

local function on_win(_, _, buf, _, _)
    local lamp_data = state_buf_lamp_data[buf]
    if lamp_data == nil then
        return
    end

    if require("nvim-tools.misc").is_insert_mode(api.nvim_get_mode().mode) then
        return
    end

    if #api.nvim_buf_get_extmarks(buf, state_ns, 0, -1, {}) > 0 then
        return
    end

    lamp_data.display(buf, lamp_data.pos_ext[1], state_ns, lamp_hl_id)
end

api.nvim_set_decoration_provider(state_ns, { on_win = on_win })

----------------------------
-- MARK: Request Handling --
----------------------------

---@param win uinteger
---@param buf uinteger
---@param pos_ext [uinteger, uinteger]
local function req_nvim_state_is_valid(win, buf, pos_ext)
    if not api.nvim_win_is_valid(win) then
        return false
    end

    if api.nvim_win_get_buf(win) ~= buf then
        return
    end

    local cursor_ext = cursor_ext_get(win)
    return require("nvim-tools.table").i_equals(cursor_ext, pos_ext)
end

---@param entries table<integer, vim.lsp.CodeActionResultEntry>
---@return boolean
local function entries_have_diagnostics(entries)
    local get = require("nvim-tools.table").get
    for _, entry in pairs(entries) do
        local diagnostics = get(entry, "context", "params", "context", "diagnostics")
        if diagnostics ~= nil and #diagnostics > 0 then
            return true
        end
    end

    return false
end

---@param entries table<integer, vim.lsp.CodeActionResultEntry>
---@param action_filter fun(client:vim.lsp.Client, action:lsp.Command|lsp.CodeAction): boolean
---@return boolean
local function entries_have_valid_lens(entries, action_filter)
    local ntt = require("nvim-tools.table")
    return ntt.any(entries, function(client_id, entry)
        local client = lsp.get_client_by_id(client_id)
        local response = entry.result
        if client == nil or response == nil then
            return false
        end

        return ntt.i_any(response, function(action)
            return action.disabled == nil and action_filter(client, action)
        end)
    end)
end

---@param entries table<integer, vim.lsp.CodeActionResultEntry>
---@param buf integer
---@param ca_ctx catharsis.lampshade.Ctx
---@return nil
local function on_entries(entries, buf, ca_ctx)
    local req = state_buf_reqs[buf]
    if req == nil then
        return
    end

    local req_version = req.version
    local ntt = require("nvim-tools.table")
    local entries_valid = ntt.all_nonempty(entries, function(_, entry)
        local ctx = entry.context
        return ctx.bufnr == buf and ctx.version == req_version
    end)

    if not entries_valid then
        return
    end

    state_buf_reqs[buf] = nil
    lamp_data_and_ns_clear(buf)
    for client_id, entry in pairs(entries) do
        local err = entry.err
        if err ~= nil then
            local client = lsp.get_client_by_id(client_id) or { name = "Client ID 1" }
            local msg = client.name .. " - " .. err.code .. ": " .. err.message
            require("nvim-tools.lsp").log_and_echo(msg, 4, "ErrorMsg", true)
            return
        end
    end

    local req_pos_ext = req.pos_ext
    if not req_nvim_state_is_valid(req.win, buf, req_pos_ext) then
        return
    end

    if not entries_have_valid_lens(entries, ca_ctx.action_filter) then
        return
    end

    state_buf_lamp_data[buf] = {
        display = ca_ctx.display,
        has_diagnostics = entries_have_diagnostics(entries),
        pos_ext = req_pos_ext,
        version = req_version,
    }

    api.nvim__redraw({ buf = buf, valid = true, flush = false })
end

---@param row uinteger
---@param col uinteger
---@param diagnostic vim.Diagnostic
---@return boolean
local function diagnostic_contains_pos(row, col, diagnostic)
    local sr = diagnostic.lnum
    if row < sr or (diagnostic.end_lnum or sr) < row then
        return false
    end

    local sc = diagnostic.col
    return sc <= col and col < (diagnostic.end_col or sc)
end

---@param buf uinteger
---@return uinteger?
local function req_win_get(buf)
    local win = api.nvim_get_current_win()
    if api.nvim_win_get_buf(win) ~= buf or fn.win_gettype(win) ~= "" then
        return
    end
end

---@param win uinteger?
---@param buf uinteger
---@param pos_ext [uinteger, uinteger]? 0-indexed
local function req_auto(win, buf, pos_ext)
    local ok, ca_ctx, err = require("catharsis")._get_merged_config(buf, nil, "lampshade")
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    win = win or req_win_get(buf)
    if not win then
        return
    end

    pos_ext = pos_ext or cursor_ext_get(win)
    req_cancel(buf)
    require("nvim-tools.timers").timer_stop(state_timer)
    state_timer:start(
        ca_ctx.debounce,
        0,
        vim.schedule_wrap(function()
            if not api.nvim_buf_is_valid(buf) then
                return
            end

            local row = pos_ext[1]
            local col = pos_ext[2]
            local params = function(client, _)
                local nts = require("nvim-tools.lsp")
                local diagnostics = nts.lsp_diagnostics_get({ buf = buf, row = row })
                require("nvim-tools.table").i_keep(diagnostics, function(diagnostic)
                    return diagnostic_contains_pos(row, col, diagnostic)
                end)

                local range = { row, col, row, col }
                return nts.code_action_params_create(buf, range, client.offset_encoding, {
                    diagnostics = lsp.diagnostic.from(diagnostics),
                    triggerKind = lsp.protocol.CodeActionTriggerKind.Automatic,
                })
            end

            local cancel_func = lsp.buf_request_all(buf, METHOD, params, function(results)
                on_entries(results, buf, ca_ctx)
            end)

            state_buf_reqs[buf] = {
                cancel_func = cancel_func,
                pos_ext = pos_ext,
                version = util.buf_versions[buf],
                win = win,
            }
        end)
    )
end
-- Because the _features layer checks for compatible clients, and we don't do bepsoke filtering
-- here, no checking for valid clients here.

local group_name_root = "catharsis.lampshade."
local function get_buf_group_name(bufnr)
    return group_name_root .. tostring(bufnr)
end

--- @type catharsis.feature.Spec
local M = {
    method = "textDocument/codeAction",
    on_buf_add = function(bufnr)
        local buf_group_name = get_buf_group_name(bufnr)
        if fn.exists("#" .. buf_group_name) == 1 then
            return
        end

        local buf_group = api.nvim_create_augroup(buf_group_name, {})
        api.nvim_create_autocmd({ "CursorMoved", "InsertLeave" }, {
            group = buf_group,
            buffer = bufnr,
            desc = "Conditionally update the lamp",
            callback = function(ev)
                local win = api.nvim_get_current_win()
                if fn.win_gettype(win) ~= "" then
                    return
                end

                local buf = ev.buf
                local cur_pos_ext = cursor_ext_get(win)
                local lamp_data = state_buf_lamp_data[buf]
                if lamp_data ~= nil then
                    if require("nvim-tools.table").i_equals(lamp_data.pos_ext, cur_pos_ext) then
                        if ev.event == "InsertLeave" then
                            api.nvim__redraw({ buf = buf, valid = true, flush = false })
                        end

                        return
                    end
                end

                req_auto(win, buf, cur_pos_ext)
            end,
        })

        api.nvim_create_autocmd("DiagnosticChanged", {
            group = buf_group,
            buffer = bufnr,
            desc = "Update the lamp on diagnostic changes",
            callback = function(ev)
                if require("nvim-tools.misc").is_insert_mode(api.nvim_get_mode().mode) then
                    return
                end

                local buf = ev.buf
                local win = api.nvim_get_current_win()
                local is_cur_win = api.nvim_win_get_buf(win) ~= buf or fn.win_gettype(win) ~= ""
                local lamp = state_buf_lamp_data[buf]
                if lamp == nil and not is_cur_win then
                    return
                end

                if lamp ~= nil and lamp.has_diagnostics then
                    if is_cur_win then
                        req_auto(win, buf, cursor_ext_get(win))
                    else
                        lamp_data_and_ns_clear(buf)
                    end

                    return
                end

                local ntt = require("nvim-tools.table")
                local lamp_pos_ext = lamp.pos_ext
                local row = lamp_pos_ext[1]
                local col = lamp_pos_ext[2]
                local ev_diagnostics_have_pos = ntt.i_any(ev.data.diagnostics, function(diagnostic)
                    return diagnostic_contains_pos(row, col, diagnostic)
                end)

                if not ev_diagnostics_have_pos then
                    return
                end

                if is_cur_win then
                    req_auto(win, buf, cursor_ext_get(win))
                else
                    lamp_data_and_ns_clear(buf)
                end
            end,
        })
        -- NON: Don't send ev diagnostics for the request, since they could become stale.

        api.nvim_create_autocmd("InsertEnter", {
            group = buf_group,
            buffer = bufnr,
            desc = "Clear lamp on insert mode",
            callback = function(ev)
                local buf = ev.buf
                if state_buf_lamp_data[buf] ~= nil then
                    api.nvim_buf_clear_namespace(buf, state_ns, 0, -1)
                end
            end,
        })

        api.nvim_create_autocmd("LspNotify", {
            buffer = bufnr,
            group = buf_group,
            desc = "Refresh document highlights on document changes",
            callback = function(ev)
                local method = ev.data.method --- @type string
                local buf = ev.buf
                if method == "textDocument/didClose" then
                    lamp_data_and_ns_clear(buf)
                    return
                end

                if method == "textDocument/didChange" or method == "textDocument/didOpen" then
                    local lamp = state_buf_lamp_data[buf]
                    if lamp and lamp.version == util.buf_versions[buf] then
                        return
                    end

                    req_auto(nil, buf, nil)
                end
            end,
        })

        api.nvim_create_autocmd("WinEnter", {
            group = buf_group,
            buffer = bufnr,
            desc = "Set Lampshade ns to the current window",
            callback = function()
                set_ns_win(api.nvim_get_current_win())
            end,
        })

        local win = req_win_get(bufnr)
        if not win then
            return
        end

        api.nvim__ns_set(state_ns, { wins = { win } })
        req_auto(win, bufnr, cursor_ext_get(win))
    end,
    on_buf_rm = function(buf)
        req_cancel(buf)
        local buf_group_name = get_buf_group_name(buf)
        if fn.exists("#" .. buf_group_name) == 1 then
            api.nvim_del_augroup_by_name(buf_group_name)
        end

        lamp_data_and_ns_clear(buf)
    end,
    on_client_detach = function(_, _, _) end,
    on_client_add = function(_) end,
    on_client_rm = function(_) end,
}

return M

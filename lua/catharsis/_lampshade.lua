local api = vim.api
local fn = vim.fn
local lsp = vim.lsp
local util = lsp.util

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

local state_buf_lamps = {} ---@type table<uinteger, catharsis.lampshade.LampData>
local state_buf_reqs = {} ---@type table<uinteger, catharsis.lampshade.Request>
local state_buf_timers = {} ---@type table<uinteger, uv.uv_timer_t>
local state_ns = api.nvim_create_namespace("catharsis.lampshade")

---@param buf uinteger
local function lamp_and_ns_clear(buf)
    state_buf_lamps[buf] = nil
    if api.nvim_buf_is_valid(buf) then
        api.nvim_buf_clear_namespace(buf, state_ns, 0, -1)
    end
end

---@param buf uinteger
local function timer_and_req_cancel(buf)
    local req = state_buf_reqs[buf]
    if req ~= nil then
        req.cancel_func()
        state_buf_reqs[buf] = nil
    end

    require("nvim-tools.timers").timers_stop(state_buf_timers, buf)
end

---@param buf uinteger
local function state_buf_clear(buf)
    timer_and_req_cancel(buf)
    lamp_and_ns_clear(buf)
end

----------------
-- MARK: Util --
----------------

---@param win uinteger
---@return [uinteger, uinteger]
local function cursor_ext_get(win)
    return require("nvim-tools.pos").mark_to_ext_pos(api.nvim_win_get_cursor(win))
end

----------------------
-- MARK: Decoration --
----------------------

local function on_win(_, win, buf, _, _)
    local lamp_data = state_buf_lamps[buf]
    if lamp_data == nil then
        return
    end

    -- ns_set scopes which windows extmarks are drawn to, but not which wins on_win is called for.
    -- ISSUE: This is unintuitive behavior.
    local ns_wins = api.nvim__ns_get(state_ns).wins
    if ns_wins == nil or ns_wins[1] ~= win then
        return false
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
    if api.nvim_get_current_win() ~= win then
        return false
    end

    if api.nvim_win_get_buf(win) ~= buf then
        return false
    end

    local cursor_ext = cursor_ext_get(win)
    return require("nvim-tools.table").i_equals(cursor_ext, pos_ext)
end

---@param entries table<integer, vim.lsp.CodeActionResultEntry>
---@return boolean
local function entries_have_diagnostics(entries)
    local ntt = require("nvim-tools.table")
    return require("nvim-tools.table").any(entries, function(_, entry)
        local diagnostics = ntt.get(entry, "context", "params", "context", "diagnostics")
        return diagnostics ~= nil and #diagnostics > 0
    end)
end

---@param entries table<integer, vim.lsp.CodeActionResultEntry>
---@param action_filter fun(client:vim.lsp.Client, action:lsp.Command|lsp.CodeAction): boolean
---@return boolean
local function entries_have_valid_actions(entries, action_filter)
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
local function handler(entries, buf, ca_ctx)
    local req = state_buf_reqs[buf]
    if req == nil then
        return
    end

    local req_version = req.version
    local ntt = require("nvim-tools.table")
    local entries_stale = ntt.any(entries, function(_, entry)
        local ctx = entry.context
        return ctx.bufnr ~= buf or ctx.version ~= req_version
    end)

    if entries_stale then
        return
    end

    state_buf_reqs[buf] = nil
    lamp_and_ns_clear(buf)
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

    if not entries_have_valid_actions(entries, ca_ctx.action_filter) then
        return
    end

    state_buf_lamps[buf] = {
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
    local er = diagnostic.end_lnum or sr
    if row < sr or er < row then
        return false
    end

    local sc = diagnostic.col
    local ec_ = diagnostic.end_col or sc + 1
    return not ((row == sr and col < sc) or (row == er and ec_ <= col))
end

---@param buf uinteger
---@param pos_ext [uinteger, uinteger]
---@return boolean, boolean, boolean
local function lamp_ensure(_, buf, pos_ext)
    local lamp = state_buf_lamps[buf]
    if lamp == nil then
        return true, false, false
    end

    local outdated = lamp.version ~= util.buf_versions[buf]
    local lamp_pos_ext = lamp.pos_ext
    if outdated or lamp_pos_ext[1] ~= pos_ext[1] then
        return true, true, false
    end

    if lamp_pos_ext[2] ~= pos_ext[2] then
        return true, false, false
    end

    return false, false, #api.nvim_buf_get_extmarks(buf, state_ns, 0, -1, {}) == 0
end

---@param buf uinteger
---@return uinteger?
local function req_win_get(buf)
    local win = api.nvim_get_current_win()
    if api.nvim_win_get_buf(win) ~= buf or fn.win_gettype(win) ~= "" then
        return
    end

    return win
end

---@param buf uinteger
---@param keep_fn fun(win:uinteger, buf:uinteger, pos_ext:[uinteger,uinteger]): boolean, boolean, boolean
---Returns:
---- do_req: Continue requesting?
---- clear_lamp: Clear the lamp and its display namespace?
---- do_redraw: Stage a redraw?
local function req_auto(buf, keep_fn)
    if require("nvim-tools.misc").is_insert_mode(api.nvim_get_mode().mode) then
        return
    end

    local ok, ca_ctx, err = require("catharsis")._get_merged_config(buf, nil, "lampshade")
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
        return
    end

    local win = req_win_get(buf)
    if not win then
        return
    end

    local pos_ext = cursor_ext_get(win)
    local do_req, clear_lamp, do_redraw = keep_fn(win, buf, pos_ext)
    if do_req then
        timer_and_req_cancel(buf)
    end

    if clear_lamp then
        state_buf_clear(buf)
    end

    if do_redraw then
        api.nvim__redraw({ buf = buf, valid = true, flush = false })
    end

    if not do_req then
        return
    end

    require("nvim-tools.timers").timers_do_after_debounce(
        state_buf_timers,
        buf,
        ca_ctx.debounce,
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
                handler(results, buf, ca_ctx)
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
-- Because _features should not send us invalid buffers, and because buf_request_all precludes us
-- from doing bespoke client filtering, don't bother checking.

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
            callback = vim.schedule_wrap(function(ev)
                req_auto(ev.buf, lamp_ensure)
            end),
        })

        api.nvim_create_autocmd("DiagnosticChanged", {
            group = buf_group,
            buffer = bufnr,
            desc = "Update the lamp on diagnostic changes",
            callback = vim.schedule_wrap(function(ev)
                req_auto(ev.buf, function(_, buf, pos_ext)
                    local lamp = state_buf_lamps[buf]
                    if lamp == nil then
                        return true, false, false
                    end

                    if lamp.has_diagnostics then
                        return true, true, false
                    end

                    local diagnostics = ev.data.diagnostics
                    local ntt = require("nvim-tools.table")
                    local diags_contain_pos = ntt.any(diagnostics, function(diagnostic)
                        return diagnostic_contains_pos(pos_ext[1], pos_ext[2], diagnostic)
                    end)

                    return diags_contain_pos, diags_contain_pos, false
                end)
            end),
        })

        api.nvim_create_autocmd("InsertEnter", {
            group = buf_group,
            buffer = bufnr,
            desc = "Clear lamp on insert mode",
            callback = function(ev)
                local buf = ev.buf
                if state_buf_lamps[buf] ~= nil then
                    api.nvim_buf_clear_namespace(buf, state_ns, 0, -1)
                end
            end,
        })

        api.nvim_create_autocmd("LspNotify", {
            buffer = bufnr,
            group = buf_group,
            desc = "Refresh document highlights on document changes",
            callback = vim.schedule_wrap(function(ev)
                local method = ev.data.method --- @type string
                local buf = ev.buf
                if method == "textDocument/didChange" or method == "textDocument/didOpen" then
                    req_auto(ev.buf, lamp_ensure)
                elseif method == "textDocument/didClose" then
                    state_buf_clear(buf)
                end
            end),
        })

        api.nvim_create_autocmd("WinEnter", {
            group = buf_group,
            buffer = bufnr,
            desc = "Set Lampshade ns to the current window",
            callback = vim.schedule_wrap(function()
                local win = api.nvim_get_current_win()
                if fn.win_gettype(win) == "" then
                    api.nvim__ns_set(state_ns, { wins = { win } })
                end
            end),
        })

        vim.schedule(function()
            local win = req_win_get(bufnr)
            if not win then
                return
            end

            api.nvim__ns_set(state_ns, { wins = { win } })
            req_auto(bufnr, lamp_ensure)
        end)
    end,
    on_buf_rm = function(buf)
        timer_and_req_cancel(buf)
        local buf_group_name = get_buf_group_name(buf)
        if fn.exists("#" .. buf_group_name) == 1 then
            api.nvim_del_augroup_by_name(buf_group_name)
        end

        lamp_and_ns_clear(buf)
    end,
    on_client_detach = function(_, _, _) end,
    on_client_add = function(_) end,
    on_client_rm = function(_) end,
}

return M

local api = vim.api
local lsp = vim.lsp
local util = lsp.util
local uv = vim.uv

local lamp_hl_hs = api.nvim_create_namespace("mjm/lightbulb") ---@type integer
local timer = uv.new_timer() ---@type uv.uv_timer_t|nil
assert(timer, "Action lamp timer was not initialized")

---@param buf integer
---@param lnum integer
---@param hl_group string|integer
---@param hl_ns integer
---@return nil
local function default_display(buf, lnum, hl_group, hl_ns)
    api.nvim_buf_set_extmark(buf, hl_ns, lnum, 0, {
        virt_text = { { "󰌶", hl_group } },
        priority = 1000,
        strict = false,
    })
end

---@param has_enabled boolean
---@param opts actionlamp.UpdateLamp.Opts
---@return string|integer
local function resolve_hl(has_enabled, opts)
    if has_enabled then
        local enabled_hl = opts.enabled_hl or "DiagnosticInfo"
        return enabled_hl
    else
        local disabled_hl = opts.disabled_hl or "DiagnosticHint"
        return disabled_hl
    end
end

---@param actions (lsp.Command|lsp.CodeAction)[]
---@return boolean
local function has_enabled_action(actions)
    for _, action in pairs(actions) do
        if not action.disabled then
            return true
        end
    end

    return false
end

---@param client_id integer
---@param action (lsp.Command|lsp.CodeAction)
---@param opts actionlamp.UpdateLamp.Opts
---@return boolean
local function check_filter_action(client_id, action, opts)
    if not opts.filter then
        return true
    end

    local passed = opts.filter(client_id, action)
    return passed
end

---@param buf integer
---@return nil
local function clear_buf_lamp_state(buf)
    if vim.b[buf].action_lamp_cancel then
        pcall(vim.b[buf].action_lamp_cancel)
        vim.b[buf].action_lamp_cancel = nil
    end

    api.nvim_buf_clear_namespace(buf, lamp_hl_hs, 0, -1)
end

---@param results table<integer, vim.lsp.CodeActionResultEntry>
---@param buf integer
---@param lnum integer 0-indexed
---@param opts actionlamp.UpdateLamp.Opts
---@return nil
local function on_results(results, buf, lnum, opts)
    local loaded = api.nvim_buf_is_loaded(buf)
    if not loaded then
        return
    end

    clear_buf_lamp_state(buf)
    local cur_buf = api.nvim_get_current_buf()
    if cur_buf ~= buf then
        return
    end

    local cur_lines = api.nvim_buf_line_count(buf)
    if lnum >= cur_lines then
        return
    end

    local client_actions = {} ---@type table<integer, (lsp.Command|lsp.CodeAction)[]>
    for client_id, result in pairs(results) do
        local actions = result.result
        if actions then
            client_actions[client_id] = actions
        end
    end

    if vim.tbl_isempty(client_actions) then
        return
    end

    local filtered_actions = {} ---@type (lsp.Command|lsp.CodeAction)[]
    for client_id, actions in pairs(client_actions) do
        for _, action in ipairs(actions) do
            local is_valid = check_filter_action(client_id, action, opts)
            if is_valid then
                filtered_actions[#filtered_actions + 1] = action
            end
        end
    end

    if #filtered_actions == 0 then
        return
    end

    local has_enabled = has_enabled_action(filtered_actions)
    local hl_group = resolve_hl(has_enabled, opts)
    ---@type fun(buf: integer, lnum: integer, hl_group: string|integer, hl_ns: integer)
    local display = opts.display or default_display
    display(buf, lnum, hl_group, lamp_hl_hs)
end

---@param method vim.lsp.protocol.Method.ClientToServer.Request
---@param clients vim.lsp.Client[]
---@return boolean
local function has_supporting_client(method, clients)
    for _, client in ipairs(clients) do
        local supports_method = client:supports_method(method) ---@type boolean
        if supports_method then
            return true
        end
    end

    return false
end

---@param buf integer
---@param opts actionlamp.UpdateLamp.Opts
---@return nil
local function on_timer(buf, opts)
    local loaded = api.nvim_buf_is_loaded(buf)
    if not loaded then
        return
    end

    clear_buf_lamp_state(buf)
    local cur_buf = api.nvim_get_current_buf()
    if buf ~= cur_buf then
        return
    end

    ---@type vim.lsp.protocol.Method.ClientToServer.Request
    local method = "textDocument/codeAction"
    local clients = lsp.get_clients({ bufnr = buf })
    local supporting_client = has_supporting_client(method, clients)
    if not supporting_client then
        return
    end

    local win = api.nvim_get_current_win()
    local lnum = api.nvim_win_get_cursor(win)[1] - 1

    ---@type fun(client: vim.lsp.Client, bufnr: integer): lsp.CodeActionParams
    local params = function(client, _)
        local offset_encoding = client.offset_encoding or "utf-16"
        local ret = util.make_range_params(win, offset_encoding) ---@type lsp.CodeActionParams

        local diagnostics = lsp.diagnostic.from(vim.diagnostic.get(buf, { lnum = lnum }))
        local triggerKind = opts.triggerKind or lsp.protocol.CodeActionTriggerKind.Automatic
        ret.context = {
            diagnostics = diagnostics,
            triggerKind = triggerKind,
        }

        return ret
    end

    vim.b[buf].action_lamp_cancel = lsp.buf_request_all(buf, method, params, function(results)
        on_results(results, buf, lnum, opts)
    end)
end

-- TODO: Rename this based on file structure

---@class ActionLamp
local M = {}

-- TODO: Rename this class based on final file structure
-- TODO: Add examples. Maybe even add an example of a whole Lua config

---@class actionlamp.UpdateLamp.Opts
---( Default: 200ms ) How long to hold codeAction requests before sending them
---to the server. If another local function call is made before the timer
---expires, the timer will be stopped without sending a request to the server,
---and restarted with a fresh debounce timer
---@field debounce? integer
---( Deafault: DiagnosticInfo ) Highlight group for lamps where at least one
---code action is enabled
---@field enabled_hl? string|integer
---Custom function to display the lamp. The namespace will be cleared before
---the function is called. By default, the lamp will be displayed as virtual
---text
---@field display? fun(buf: integer, lnum: integer, hl_group: string|integer, hl_ns: integer)
---Function to filter out actions that should not be considered toward showing
---the lightbulb. By default, any valid action causes the lamp to be displayed
---@field filter? fun(client_id: integer, action: lsp.Command|lsp.CodeAction):boolean
---( Default: lsp.protocol.CodeActionTriggerKind.Automatic ) When the
---triggerKind is Automatic, the server assumes the client is requesting code
---actions due to a passive behavior such as moving the cursor. The server
---should not send back disabled code actions in this case. If triggerKind is
---Invoked, the sever will send back code actions that are disabled pending
---some change in the code
---@field triggerKind? integer
---( Default: DiagnosticHint ) Highlight group for lightbulbs where all code
---actions are disabled
---@field disabled_hl? string|integer

---Update the lamp display in a buffer. This will clear any current lamps
---
---Note that this function uses buf_request_all to get code actions. If
---multiple LSP servers attach to a buffer, and this function is mapped to an
---autocmd per attach without any use of autocmd groups to check for
---duplication, this will result in redundant requests being queued
---
---By default, this is run on BufEnter, CursorMoved, InsertLeave, and
---TextChanged
---
---@param buf integer Buffer to show the lamp in
---@param opts? actionlamp.UpdateLamp.Opts See |actionlamp.UpdateLamp.Opts|
---@return nil
function M.update_lamp(buf, opts)
    vim.validate("buf", buf, "number")
    opts = opts or {}
    -- TODO: Once this evolves out, build a real validation for opts
    vim.validate("opts", opts, "table")

    local loaded = api.nvim_buf_is_loaded(buf)
    if not loaded then
        return
    end

    clear_buf_lamp_state(buf)
    local cur_buf = api.nvim_get_current_buf()
    if cur_buf ~= buf then
        return
    end

    if timer:is_active() then
        timer:stop()
    end

    local debounce = opts.debounce or 200
    timer:start(
        debounce,
        0,
        vim.schedule_wrap(function()
            on_timer(buf, opts)
        end)
    )
end

---Stop showing the lamp in a buffer. This will also cancel any pending LSP
---requests
---
---By default, this is run on BufLeave and InsertEnter
---
---@param buf integer Buffer to clear the lamp in
---@return nil
function M.clear_lamp(buf)
    vim.validate("buf", buf, "number")

    local loaded = api.nvim_buf_is_loaded(buf) ---@type boolean
    if not loaded then
        return
    end

    clear_buf_lamp_state(buf)
end

---@return integer The lamp extmark namespace
function M.get_hl_ns()
    return lamp_hl_hs
end

return M

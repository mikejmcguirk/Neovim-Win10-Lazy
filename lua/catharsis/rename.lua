local api = vim.api
local fn = vim.fn
local lsp = vim.lsp
local util = lsp.util
local uv = vim.uv

----------------------------
-- MARK: Protocol Methods --
----------------------------

local PREP = "textDocument/prepareRename"
local RENAME = "textDocument/rename"
local REFS = "textDocument/references"

-----------------
-- MARK: State --
-----------------

local state_bufs = {} ---@type table<integer, true>
local state_ranges = {} ---@type nvim-tools.range.BufRange[]
local state_req_refs_id = nil ---@type uinteger?
local state_timer = assert(uv.new_timer())

----------------------------------------
-- MARK: Hl Priorities and Namespaces --
----------------------------------------

local hl_dim_priority = vim.hl.priorities.user + 2
local hl_padding_priority = hl_dim_priority - 1
local hl_preview_priority = hl_dim_priority + 1

-- TODO-DEP: Remove this when 0.14 comes out.
api.nvim_set_hl(0, "Dimmed", { default = true, link = "Comment" })
local hl_norm = api.nvim_get_hl_id_by_name("Normal")

api.nvim_set_hl(0, "catharsisRenameDim", { default = true, link = "Dimmed" })
api.nvim_set_hl(0, "catharsisRenameNew", { default = true, link = "Search" })
local hl_dim = api.nvim_get_hl_id_by_name("catharsisRenameDim")
local hl_new = api.nvim_get_hl_id_by_name("catharsisRenameNew")

local ns_dim = api.nvim_create_namespace("catharsis.rename.dim")
local ns_dynamic = api.nvim_create_namespace("catharsis.rename.preview")

local function clear_dim_namespaces()
    for buf, _ in pairs(state_bufs) do
        api.nvim_buf_clear_namespace(buf, ns_dim, 0, -1)
    end
end

local function clear_dynamic_preview_namespaces()
    for buf, _ in pairs(state_bufs) do
        api.nvim_buf_clear_namespace(buf, ns_dynamic, 0, -1)
    end
end

local function all_preview_data_clear()
    for buf, _ in pairs(state_bufs) do
        api.nvim_buf_clear_namespace(buf, ns_dim, 0, -1)
        api.nvim_buf_clear_namespace(buf, ns_dynamic, 0, -1)
    end

    local ntl = require("nvim-tools.list")
    ntl.clear(state_ranges)
    local ntt = require("nvim-tools.table")
    ntt.clear(state_bufs)
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
    client:request(RENAME, params, function(_, result, _)
        -- TODO: Is this correct? If this is off spec, shouldn't it error? But isn't this typical?
        if result == nil then
            local msg = "Language server couldn't provide rename result"
            require("nvim-tools.lsp").log_and_echo(msg, 2, "WarningMsg", false)
            return
        end

        if result == vim.NIL then
            -- "null should be treated the same as WorkspaceEdit with no changes (no change was
            -- required)."
            local msg = "Nothing to rename."
            require("nvim-tools.lsp").log_and_echo(msg, 1, "", false)
            return
        end

        util.apply_workspace_edit(result, client.offset_encoding)
    end, buf)
end

------------------------------
-- MARK: Preview Management --
------------------------------

local function dim_marks_set_new()
    clear_dim_namespaces()
    for _, range in ipairs(state_ranges) do
        api.nvim_buf_set_extmark(range[5], ns_dim, range[1], range[2], {
            end_row = range[3],
            end_col = range[4],
            hl_group = hl_dim,
            priority = hl_dim_priority,
        })
    end
end

local function preview_marks_set_new()
    clear_dynamic_preview_namespaces()
    local new_text = fn.getcmdline()
    if #new_text < 1 or #state_ranges < 1 then
        return
    end

    for _, range in ipairs(state_ranges) do
        api.nvim_buf_set_extmark(range[5], ns_dynamic, range[1], range[2], {
            virt_text = { { new_text, hl_new } },
            virt_text_pos = "overlay",
            priority = hl_preview_priority,
        })
    end

    if #state_ranges < 1 then
        return
    end

    local range_1 = state_ranges[1]
    local range_len = range_1[4] - range_1[2]
    local padding_len = #new_text - range_len
    if padding_len <= 0 then
        return
    end

    local padding = string.rep(" ", padding_len)
    for _, range in ipairs(state_ranges) do
        api.nvim_buf_set_extmark(range[5], ns_dynamic, range[1], range[4], {
            virt_text = { { padding, hl_norm } },
            virt_text_pos = "inline",
            priority = hl_padding_priority,
        })
    end
end
-- MID: Display the preview under the cursor using a different hl color.

local function all_marks_set_new()
    dim_marks_set_new()
    preview_marks_set_new()
end

local group_name = "mjm.lsp.rename"
local group = api.nvim_create_augroup("mjm.lsp.rename", {})

local function preview_autocmd_create()
    api.nvim_create_autocmd("CmdlineChanged", {
        group = group,
        callback = function()
            preview_marks_set_new()
        end,
    })
end

--------------------------
-- MARK: Get references --
--------------------------

---@param ranges nvim-tools.range.BufRange[]
---@param visible_range [integer, integer]
---@return boolean True for valid splice range.
local function range_splice_to_visible(ranges, visible_range)
    local ranges_len = #ranges
    if ranges_len == 0 then
        return false
    end

    ---@param range nvim-tools.range.BufRange
    local function vis_range_cmp(range)
        if visible_range[2] < range[1] then
            return -1
        elseif range[3] < visible_range[1] then
            return 1
        else
            return 0
        end
    end

    local ntr = require("nvim-tools.range")
    local ntl = require("nvim-tools.list")
    local lo = ntr.bisect_lo(ranges, vis_range_cmp)
    if lo > ranges_len then
        return false
    end

    local hi = ntr.bisect_hi(ranges, vis_range_cmp)
    if hi < lo then
        return false
    end

    ntl.splice(ranges, lo, hi)
    return true
end

---@return table<integer, true> Table of visible buffers
---@return table<uinteger, [uinteger, uinteger]> Top and bottom visible lines within those visible
---     buffers (0 indexed)
local function get_visible_buf_info()
    local wins = api.nvim_tabpage_list_wins(0)
    require("nvim-tools.list").filter(wins, function(win)
        local visible = api.nvim_win_get_config(win).hide ~= true
        return visible and vim.call("win_gettype", win) == ""
    end)

    local buf_ranges = {} ---@type table<uinteger, [uinteger, uinteger]>
    for _, win in ipairs(wins) do
        local win_buf = api.nvim_win_get_buf(win)
        local range = buf_ranges[win_buf]
        if range == nil then
            range = { math.floor(math.huge), math.ceil(math.huge * -1) }
            buf_ranges[win_buf] = range
        end

        local top_0 = fn.line("w0", win) - 1
        local bot_0 = fn.line("w$", win) - 1
        if top_0 < range[1] then
            range[1] = top_0
        end

        if range[2] < bot_0 then
            range[2] = bot_0
        end
    end

    local bufs = {} ---@type table<uinteger, true>
    for buf, _ in pairs(buf_ranges) do
        bufs[buf] = true
    end

    return bufs, buf_ranges
end

---@param ctx lsp.HandlerContext
---@param req_id uinteger
---@param client_id uinteger
---@return boolean, vim.lsp.Client?, mjm.lsp.HandlerContext_Validated?
local function ref_req_handler_check_ctx(ctx, req_id, client_id)
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
local function req_refs_handler(err, result, ctx, client_id)
    local req_id = state_req_refs_id
    state_req_refs_id = nil
    if req_id == nil then
        return
    end

    local ok, client, ctx_validated = ref_req_handler_check_ctx(ctx, req_id, client_id)
    if ok == false or client == nil or ctx_validated == nil then
        return
    end

    if err ~= nil then
        -- No echo because it causes hl previews to freeze in legacy ui.
        lsp.log.error(err.code .. ": " .. err.message .. "(" .. vim.inspect(err.data) .. ")")
        return
    end

    if result == nil or result == vim.NIL or #result == 0 then
        -- No error. All valid per the spec.
        return
    end

    local nts = require("nvim-tools.lsp")
    local encoding = client.offset_encoding
    local bufs, buf_visible_ranges = get_visible_buf_info()
    local buf_ranges = nts.ranges_from_locations_by_buf(result, encoding, bufs)

    local ntl = require("nvim-tools.list")
    for buf, ranges in pairs(buf_ranges) do
        if not range_splice_to_visible(ranges, buf_visible_ranges[buf]) then
            buf_ranges[buf] = nil
        end
    end

    if require("nvim-tools.table").keys_count(buf_ranges) < 1 then
        return
    end

    ntl.clear(state_ranges)
    for _, range in pairs(buf_ranges) do
        -- TODO: Why not just store state_ranges by buf?
        ntl.chain(state_ranges, range)
    end

    all_marks_set_new()
    api.nvim__redraw({ flush = true, valid = true })
end

---https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocument_references
---@param client vim.lsp.Client
---@param buf uinteger
---@param pos_ext [uinteger, uinteger]
local function ref_req_create(client, buf, pos_ext)
    local nts = require("nvim-tools.lsp")
    local encoding = client.offset_encoding
    local params = nts.reference_params_create(buf, pos_ext, encoding, true)
    local req_success, req_id = client:request(REFS, params, function(err, results, ctx)
        req_refs_handler(err, results, ctx, client.id)
    end, buf)

    if req_success == true and req_id ~= nil then
        state_req_refs_id = req_id
    else
        lsp.log.debug("references request unsuccessful")
    end
end
-- MID: Send a partial result token and handle the streaming results.

----------------------------
-- MARK: Get Rename Input --
----------------------------

---@param client vim.lsp.Client
---@param buf uinteger
---@param cur_pos_ext [uinteger, uinteger]
---@param range nvim-tools.range.BufRange?
---@param prompt_default boolean
local function rename_get_input(client, buf, cur_pos_ext, range, prompt_default)
    state_ranges = {}
    state_bufs[buf] = true
    local prompt_opts = { prompt = "New Name: ", scope = "cursor" }
    if range ~= nil then
        state_ranges[1] = range
        dim_marks_set_new()

        if prompt_default == true then
            local ntb = require("nvim-tools.buf")
            prompt_opts.default = ntb.get_text_from_range(range, buf)
        end
    end

    preview_autocmd_create()
    local nti = require("nvim-tools.ui")
    ref_req_create(client, buf, cur_pos_ext)
    local ok, text = nti.input(prompt_opts)
    if state_req_refs_id ~= nil then
        client:cancel_request(state_req_refs_id)
    end

    state_req_refs_id = nil
    all_preview_data_clear()
    for _, autocmd in ipairs(api.nvim_get_autocmds({ group = group_name })) do
        api.nvim_del_autocmd(autocmd.id)
    end

    if text == "" then
        return
    end

    if ok == false then
        local msg = text or ""
        api.nvim_echo({ { "Input error: " .. msg, "ErrorMsg" } }, true, {})
        return
    end

    rename_do(client, buf, cur_pos_ext, text)
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

---@param message string
local function output_prep_err(message)
    local msg = "Error on prepareRename: " .. (message or "")
    require("nvim-tools.lsp").log_and_echo(msg, 4, "ErrorMsg", false)
end

local function output_noop()
    local msg = "Nothing to rename."
    require("nvim-tools.lsp").log_and_echo(msg, 2, "WarningMsg", false)
end

---@param err lsp.ResponseError?
---@param result (lsp.Range|{ range: lsp.Range, placeholder: string })?
---@return (lsp.Range|{ range: lsp.Range, placeholder: string })?
local function req_prep_rn_handler_check_err(err, result)
    if err ~= nil then
        local message = err.message
        if message ~= nil then
            output_prep_err(message)
            return
        end

        output_noop()
        return
    end

    -- Both valid per the spec.
    if result == nil or result == vim.NIL then
        output_noop()
        return
    end

    return result
end

---@param err lsp.ResponseError?
---@param result (lsp.Range|{ range: lsp.Range, placeholder: string })?
---@param ctx lsp.HandlerContext
---@param buf uinteger
---@param cur_pos_ext nvim-tools.Pos
---@param prompt_default boolean
local function req_prep_rn_handler(err, result, ctx, buf, cur_pos_ext, prompt_default)
    if uv.is_active(state_timer) then
        uv.timer_stop(state_timer)
    else
        lsp.log.info("prepareRename request arrived after timeout.")
        return
    end

    local ok, client, ctx_validated = req_prep_rn_handler_check_ctx(ctx, buf)
    if ok == false or buf == nil or client == nil or ctx_validated == nil then
        return
    end

    local res = req_prep_rn_handler_check_err(err, result)
    if res == nil then
        return
    end

    local default_range
    local encoding = client.offset_encoding
    -- MID-DEP: If I have occasion to make a single-range LSP > API function, use here.
    if res.range then
        default_range = vim.range.lsp(buf, res.range, encoding)
    elseif res.start then
        default_range = vim.range.lsp(buf, res, encoding)
    else
        -- Likely a PrepareRenameDefaultBehavior response.
        local ntb = require("nvim-tools.buf")
        default_range = ntb.match_line_under_cursor(cur_pos_ext, buf, [[\k\+]])
    end

    rename_get_input(client, buf, cur_pos_ext, default_range, prompt_default)
end

-----------------------
-- MARK: Dispatching --
-----------------------

---@param buf uinteger
---@param finder catharsis.rename.opts.Finder
---@return uinteger?, vim.lsp.Client?, boolean
---Client id, client, supports prepareRename.
local function client_find(buf, finder)
    local all_clients = lsp.get_clients({ bufnr = buf })
    local ntl = require("nvim-tools.list")
    if type(finder) == "string" then
        ntl.filter(all_clients, function(client)
            return client.name == finder
        end)
    elseif type(finder) == "function" then
        ntl.filter(all_clients, finder)
    end

    ntl.filter(all_clients, function(client)
        return client:supports_method(RENAME, buf)
    end)

    if #all_clients == 0 then
        return nil, nil, false
    end

    local prep_clients = ntl.filter_to(all_clients, function(client)
        return client:supports_method(PREP, buf)
    end)

    local nts = require("nvim-tools.lsp")
    if #prep_clients > 0 then
        local all_methods = { PREP, REFS, RENAME }
        local client_id, client = nts.clients_find_best_scoring(prep_clients, all_methods, buf)
        if client_id ~= nil and client ~= nil then
            return client_id, client, true
        end
    end

    local ref_clients = ntl.filter_to(all_clients, function(client)
        return client:supports_method(REFS, buf)
    end)

    if #ref_clients > 0 then
        local ref_methods = { REFS, RENAME }
        local client_id, client = nts.clients_find_best_scoring(prep_clients, ref_methods, buf)
        if client_id ~= nil and client ~= nil then
            return client_id, client, false
        end
    end

    local client_id, client = nts.clients_find_best_scoring(prep_clients, { RENAME }, buf)
    return client_id, client, false
end
-- MID: This function is quite long.

---@alias catharsis.rename.opts.Finder nil|string|fun(client:vim.lsp.Client): boolean

---@class catharsis.rename.Opts
---(Default: `nil`) Similar to `opts.filter` and `opts.name` in |vim.lsp.buf.rename()|. If nil,
---find the best match client. If a string, look for a client with a matching name. If a
---function, filter clients based on the predicate, then use best match if more than one return.
---@field finder? catharsis.rename.opts.Finder
---(Default: `nil`) If provided, immediately send the rename request.
---@field new_name? string
---(Default: `true`) Provide a default name in the prompt? If true, the LSP suggestion will be
---used if provided. Otherwise, the |<cword>| under the cursor.
---@field prompt_default? boolean

---@class catharsis.rename.Ctx
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
function M.dispatcher(opts)
    if uv.is_active(state_timer) then
        local nts = require("nvim-tools.lsp")
        nts.log_warn_and_echo("prepareRename request currently active.")
        return
    end

    local opts_ctx = opts_to_ctx(opts)
    local buf = api.nvim_get_current_buf()
    local client_id, client, supports_prep = client_find(buf, opts_ctx.finder)
    if not (client_id ~= nil and client ~= nil) then
        api.nvim_echo({ { "No clients supporting rename were found", "ErrorMsg" } }, true, {})
        return
    end

    local ntp = require("nvim-tools.pos")
    local cur_pos_ext = ntp.mark_to_ext_pos(api.nvim_win_get_cursor(0))
    local new_name = opts_ctx.new_name
    if new_name ~= nil then
        rename_do(client, buf, cur_pos_ext, new_name)
        return
    end

    local prompt_default = opts_ctx.prompt_default
    if not supports_prep then
        local ntb = require("nvim-tools.buf")
        local cr = ntb.match_line_under_cursor(cur_pos_ext, buf, [[\k\+]])
        rename_get_input(client, buf, cur_pos_ext, cr, opts_ctx.prompt_default)
        return
    end

    local encoding = client.offset_encoding
    local nts = require("nvim-tools.lsp")
    ---@diagnostic disable-next-line: param-type-mismatch
    local params = nts.text_doc_pos_params_create(buf, cur_pos_ext, encoding)

    -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocument_prepareRename
    local req_success, req_id = client:request(PREP, params, function(err, result, ctx)
        req_prep_rn_handler(err, result, ctx, buf, cur_pos_ext, prompt_default)
    end, buf)

    if req_success and req_id then
        uv.timer_start(
            state_timer,
            5000,
            0,
            vim.schedule_wrap(function()
                nts.log_warn_and_echo("prepareRename timed out")
            end)
        )
    end
end
-- TODO-DEP: Once this is in the actual module structure, it should be callable using
-- `require("catharsis").rename()`.

return M

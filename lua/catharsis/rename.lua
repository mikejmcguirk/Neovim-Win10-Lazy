local api = vim.api
local fn = vim.fn
local lsp = vim.lsp
local util = lsp.util
local uv = vim.uv

----------------------------
-- MARK: Protocol Methods --
----------------------------

local PREP = "textDocument/prepareRename"
local REFS = "textDocument/references"
local RENAME = "textDocument/rename"

-----------------
-- MARK: State --
-----------------

local DEFAULT_STATE_RANGES_HAS = false
local DEFAULT_STATE_SYMBOL_LEN = math.floor(math.huge)

local state_ranges = {} ---@type table<uinteger, nvim-tools.range.BufRange[]>
local state_ranges_has = DEFAULT_STATE_RANGES_HAS
local state_symbol_len = DEFAULT_STATE_SYMBOL_LEN

---@param range nvim-tools.range.BufRange
---@param buf uinteger
local function preview_state_init(range, buf)
    state_ranges[buf] = {}
    state_ranges[buf][1] = range
    state_ranges_has = true
    state_symbol_len = range[4] - range[2]
end

---@param buf_ranges table<uinteger, nvim-tools.range.BufRange[]>
local function preview_state_set_from_refs(buf_ranges)
    state_ranges = buf_ranges
    state_ranges_has = true
    for _, ranges in pairs(buf_ranges) do
        for _, range in ipairs(ranges) do
            state_symbol_len = range[4] - range[2]
            break
        end
    end
end

local function preview_state_clear_all()
    require("nvim-tools.list").clear(state_ranges)
    state_symbol_len = DEFAULT_STATE_SYMBOL_LEN
    state_ranges_has = DEFAULT_STATE_RANGES_HAS
end

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
api.nvim_set_hl(0, "catharsisRenameNew", { default = true, link = "Substitute" })
local hl_dim = api.nvim_get_hl_id_by_name("catharsisRenameDim")
local hl_new = api.nvim_get_hl_id_by_name("catharsisRenameNew")

local ns_dim = api.nvim_create_namespace("catharsis.rename.dim")
local ns_dynamic = api.nvim_create_namespace("catharsis.rename.preview")

local function clear_dim_namespaces()
    for buf, _ in pairs(state_ranges) do
        api.nvim_buf_clear_namespace(buf, ns_dim, 0, -1)
    end
end

local function clear_dynamic_preview_namespaces()
    for buf, _ in pairs(state_ranges) do
        api.nvim_buf_clear_namespace(buf, ns_dynamic, 0, -1)
    end
end

---------------------------------------
-- MARK: Preview Management Autocmds --
---------------------------------------

local function dim_marks_set_new()
    clear_dim_namespaces()
    if state_ranges_has == false then
        return
    end

    for buf, ranges in pairs(state_ranges) do
        for _, range in ipairs(ranges) do
            api.nvim_buf_set_extmark(buf, ns_dim, range[1], range[2], {
                end_row = range[3],
                end_col = range[4],
                hl_group = hl_dim,
                priority = hl_dim_priority,
            })
        end
    end
end

local function preview_marks_set_new()
    clear_dynamic_preview_namespaces()
    if state_ranges_has == false then
        return
    end

    local new_text = fn.getcmdline()
    if #new_text < 1 then
        return
    end

    for buf, ranges in pairs(state_ranges) do
        for _, range in ipairs(ranges) do
            api.nvim_buf_set_extmark(buf, ns_dynamic, range[1], range[2], {
                virt_text = { { new_text, hl_new } },
                virt_text_pos = "overlay",
                priority = hl_preview_priority,
            })
        end
    end

    local padding_len = #new_text - state_symbol_len
    if padding_len <= 0 then
        return
    end

    local padding = string.rep(" ", padding_len)
    for buf, ranges in pairs(state_ranges) do
        for _, range in ipairs(ranges) do
            api.nvim_buf_set_extmark(buf, ns_dynamic, range[1], range[4], {
                virt_text = { { padding, hl_norm } },
                virt_text_pos = "inline",
                priority = hl_padding_priority,
            })
        end
    end
end
-- MID: Display the preview under the cursor using a different hl color.

local function all_marks_set_new()
    dim_marks_set_new()
    preview_marks_set_new()
end

local group_name = "catharsis.rename"
local group = api.nvim_create_augroup(group_name, {})
local function preview_display_init()
    dim_marks_set_new()
    api.nvim_create_autocmd("CmdlineChanged", {
        group = group,
        callback = function()
            preview_marks_set_new()
        end,
    })
end

local function preview_display_stop()
    for buf, _ in pairs(state_ranges) do
        api.nvim_buf_clear_namespace(buf, ns_dim, 0, -1)
        api.nvim_buf_clear_namespace(buf, ns_dynamic, 0, -1)
    end

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
            require("nvim-tools.lsp").log_and_echo(msg, 4, "ErrorMsg", true)
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

---@param ranges nvim-tools.range.BufRange[]
---@param visible_range [integer, integer]
---@return boolean True for valid splice range.
local function range_filter_to_visible(ranges, visible_range)
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
-- MID: This method is not the best if you have a large buffer with two distinct, far apart
-- regions visible, because they will merge into one large region.
-- Given that this module should also support fold filtering, it seems like we should support the
-- same multi-namespace concept that jump uses.

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

local req_id_refs = nil ---@type uinteger?

---@param err lsp.ResponseError?
---@param result lsp.Location[]|lsp.LocationLink
---@param ctx lsp.HandlerContext
local function req_refs_handler(err, result, ctx, client_id)
    local req_id = req_id_refs
    req_id_refs = nil
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

    if result == nil or #result == 0 then
        -- Valid per the spec.
        return
    end

    local nts = require("nvim-tools.lsp")
    local encoding = client.offset_encoding
    local bufs, buf_visible_ranges = get_visible_buf_info()
    local buf_ranges = nts.ranges_from_locations_by_buf(result, encoding, bufs)
    for buf, ranges in pairs(buf_ranges) do
        if not range_filter_to_visible(ranges, buf_visible_ranges[buf]) then
            buf_ranges[buf] = nil
        end
    end

    if require("nvim-tools.table").keys_count(buf_ranges) < 1 then
        return
    end

    preview_state_set_from_refs(buf_ranges)
    all_marks_set_new()
    api.nvim__redraw({ flush = true, valid = true })
end

---@param client vim.lsp.Client
local function ref_req_checked_clear(client)
    if req_id_refs == nil then
        return
    end

    client:cancel_request(req_id_refs)
    req_id_refs = nil
end

---https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocument_references
---@param client vim.lsp.Client
---@param buf uinteger
---@param pos_ext [uinteger, uinteger]
local function ref_req_create(client, buf, pos_ext)
    if not client:supports_method(REFS) then
        return
    end

    local nts = require("nvim-tools.lsp")
    local encoding = client.offset_encoding
    local params = nts.reference_params_create(buf, pos_ext, encoding, true)
    local req_success, req_id = client:request(REFS, params, function(err, results, ctx)
        req_refs_handler(err, results, ctx, client.id)
    end, buf)

    if req_success == true and req_id ~= nil then
        req_id_refs = req_id
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
---@param buf uinteger
---@param cur_pos_ext [uinteger, uinteger]
---@param range nvim-tools.range.BufRange?
---@param prompt_default boolean
local function rename_get_input(client, buf, cur_pos_ext, range, prompt_default)
    local prompt_opts = { prompt = "New Name: ", scope = "cursor" }
    if range ~= nil then
        preview_state_init(range, buf)
        if prompt_default == true then
            local ntb = require("nvim-tools.buf")
            prompt_opts.default = ntb.get_text_from_range(range, buf)
        end
    end

    preview_display_init()
    ref_req_create(client, buf, cur_pos_ext)

    local nti = require("nvim-tools.ui")
    local ok, text = nti.input(prompt_opts)

    ref_req_checked_clear(client)
    preview_display_stop()
    preview_state_clear_all()

    if text == "" then
        return
    elseif ok == false then
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

local req_prep_rn_timer = assert(uv.new_timer())

---@param err lsp.ResponseError?
---@param result (lsp.Range|{ range: lsp.Range, placeholder: string })?
---@param ctx lsp.HandlerContext
---@param buf uinteger
---@param cur_pos_ext nvim-tools.Pos
---@param prompt_default boolean
local function req_prep_rn_handler(err, result, ctx, buf, cur_pos_ext, prompt_default)
    if uv.is_active(req_prep_rn_timer) then
        uv.timer_stop(req_prep_rn_timer)
    else
        lsp.log.info("prepareRename request arrived after timeout.")
        return
    end

    local ok, client, ctx_validated = req_prep_rn_handler_check_ctx(ctx, buf)
    if ok == false or buf == nil or client == nil or ctx_validated == nil then
        return
    end

    if err ~= nil then
        local msg = "Error on prepareRename: " .. (err.message or "")
        require("nvim-tools.lsp").log_and_echo(msg, 4, "ErrorMsg", true)
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
    local all_clients = lsp.get_clients({ bufnr = buf, method = RENAME })
    local ntl = require("nvim-tools.list")
    if type(finder) == "string" then
        ntl.filter(all_clients, function(client)
            return client.name == finder
        end)
    elseif type(finder) == "function" then
        ntl.filter(all_clients, finder)
    end

    if #all_clients == 0 then
        return nil, nil, false
    end

    local nts = require("nvim-tools.lsp")
    local featured = ntl.copy(all_clients)
    nts.clients_filter_supporting_multiple(featured, buf, { PREP, REFS })
    if #featured > 0 then
        local all_methods = { PREP, REFS, RENAME }
        local client_id, client = nts.clients_find_top_scoring(featured, all_methods, buf)
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
---(Default: `nil`) Similar to `opts.filter` and `opts.name` in |vim.lsp.buf.rename()|. If nil,
---find the best match client. If a string, look for a client with a matching name. If a
---function, filter clients based on the predicate, then use best match if more than one return.
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
function M.dispatcher(opts)
    local nts = require("nvim-tools.lsp")
    if uv.is_active(req_prep_rn_timer) then
        nts.log_and_echo("prepareRename request currently active.", 3, "WarningMsg", true)
        return
    end

    local opts_ctx = opts_to_ctx(opts)
    local buf = api.nvim_get_current_buf()
    local client_id, client, supports_prep = client_find(buf, opts_ctx.finder)
    if not (client_id ~= nil and client ~= nil) then
        local msg = "No clients supporting textDocument/rename were found"
        nts.log_and_echo(msg, 3, "WarningMsg", true)
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
    ---@diagnostic disable-next-line: param-type-mismatch
    local params = nts.text_doc_pos_params_create(buf, cur_pos_ext, encoding)
    -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocument_prepareRename
    local req_success, req_id = client:request(PREP, params, function(err, result, ctx)
        req_prep_rn_handler(err, result, ctx, buf, cur_pos_ext, prompt_default)
    end, buf)

    if req_success and req_id then
        uv.timer_start(
            req_prep_rn_timer,
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

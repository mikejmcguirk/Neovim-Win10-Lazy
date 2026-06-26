local api = vim.api
local fn = vim.fn
local lsp = vim.lsp
local util = lsp.util
local uv = vim.uv

---------------------
-- MARK: Constants --
---------------------

local PREP = "textDocument/prepareRename"
local REFS = "textDocument/references"
local RENAME = "textDocument/rename"

local DEFAULT_STATE_RANGES_HAS = false
local HUGE_INT = math.floor(math.huge)
local DEFAULT_STATE_SYMBOL_LEN = HUGE_INT

-----------------
-- MARK: State --
-----------------

---@class (exact) catharsis.rename.WinInfo
---@field bot uinteger 0-indexed
---@field buf -1|uinteger
---@field ns_dim -1|uinteger
---@field ns_preview -1|uinteger
---@field top uinteger 0-indexed

---@class catharsis.rename.BufInfo
---@field ranges nvim-tools.range.BufRange[]
---@field win_bounds table<uinteger, [uinteger, uinteger]>

local state_ranges_has = DEFAULT_STATE_RANGES_HAS
local state_symbol_len = DEFAULT_STATE_SYMBOL_LEN

local state_info_bufs = {} ---@type table<uinteger, catharsis.rename.BufInfo>>
local state_info_bufswins = {} ---@type table<uinteger, table<uinteger, true>>
local state_info_wins = {} ---@type table<uinteger, catharsis.rename.WinInfo>
local state_ns_dims = {} ---@type uinteger[]
local state_ns_previews = {} ---@type uinteger[]
---@type catharsis.rename.WinInfo
local state_info_cur_win = {
    bot = HUGE_INT,
    buf = -1,
    ns_dim = -1,
    ns_preview = -1,
    top = 1,
}

local function state_info_cur_win_reset()
    state_info_cur_win.bot = HUGE_INT
    state_info_cur_win.buf = -1
    state_info_cur_win.ns_dim = -1
    state_info_cur_win.ns_preview = -1
    state_info_cur_win.top = 1
end

local ns_basename = "catharsis.rename"
local ns_dim_basename = ns_basename .. ".dim"
local ns_preview_basename = ns_basename .. ".preview"

local function clear_dim_namespaces()
    for _, info in pairs(state_info_wins) do
        api.nvim_buf_clear_namespace(info.buf, info.ns_dim, 0, -1)
    end
end

local function clear_dynamic_preview_namespaces()
    for _, info in pairs(state_info_wins) do
        api.nvim_buf_clear_namespace(info.buf, info.ns_preview, 0, -1)
    end
end

---@param total_needed uinteger
local function ns_dims_ensure(total_needed)
    local ns_needed = total_needed - #state_ns_dims
    if ns_needed <= 0 then
        return
    end

    for _ = 1, ns_needed do
        local idx_new = #state_ns_dims + 1
        local ns_name_new = ns_dim_basename .. "." .. tostring(idx_new)
        state_ns_dims[#state_ns_dims + 1] = api.nvim_create_namespace(ns_name_new)
    end
end

---@param total_needed uinteger
local function ns_previews_ensure(total_needed)
    local ns_needed = total_needed - #state_ns_previews
    if ns_needed <= 0 then
        return
    end

    local ns_previews_len = #state_ns_previews
    for i = 1, ns_needed do
        local idx_new = ns_previews_len + i
        local ns_name_new = ns_preview_basename .. "." .. tostring(idx_new)
        state_ns_previews[idx_new] = api.nvim_create_namespace(ns_name_new)
    end
end

---@param total_needed uinteger
local function ns_ensure(total_needed)
    ns_dims_ensure(total_needed)
    ns_previews_ensure(total_needed)
end

-- TODO: needs to be a way to store buf ranges separately. this way a single buf range can
-- work without having to splice out

---@param cur_win uinteger
local function display_info_init(cur_win)
    local wins = api.nvim_tabpage_list_wins(0)
    require("nvim-tools.list").filter(wins, function(win)
        local visible = api.nvim_win_get_config(win).hide ~= true
        return win ~= cur_win and visible and vim.call("win_gettype", win) == ""
    end)

    ns_ensure(#wins + 1) -- Add one for cur_win
    for i, win in ipairs(wins) do
        state_info_wins[win] = {
            bot = vim.call("line", "w$", win) - 1,
            buf = api.nvim_win_get_buf(win),
            ns_dim = state_ns_dims[i],
            ns_preview = state_ns_previews[i],
            top = vim.call("line", "w0", win) - 1,
        }
    end

    for win, display_info in pairs(state_info_wins) do
        api.nvim__ns_set(display_info.ns_dim, { wins = { win } })
        api.nvim__ns_set(display_info.ns_preview, { wins = { win } })
    end
end

-- It might make sense to only get the cursor win first, as that saves a bunch of annoying
-- logic.
-- Also works for buf ranges because basically you just go through the wins and plug them in,
-- or something. But it's ahrd to make it tie both ways.
-- I guess *really* what you do is just add the current win check into tabpage_list_wins. It's
-- the one bit of BS we'll have to accept here. It's done early in that case.
-- and then instead of storing the intermediate bufwins thing, you can just iterate through the
-- wins, create the buf ranges, then iterate again for the visible ranges

local state_ranges = {} ---@type table<uinteger, nvim-tools.range.BufRange[]>

---@param ranges nvim-tools.range.BufRange[]
---@param top uinteger
---@param bot uinteger
---@return [uinteger, uinteger]?
local function win_bounds_get(ranges, top, bot)
    local ranges_len = #ranges
    if ranges_len == 0 then
        return
    end

    ---@param range nvim-tools.range.BufRange
    local function vis_range_cmp(range)
        if bot < range[1] then
            return -1
        elseif range[3] < top then
            return 1
        else
            return 0
        end
    end

    local ntr = require("nvim-tools.range")
    local lo = ntr.bisect_lo(ranges, vis_range_cmp)
    if lo > ranges_len then
        return
    end

    local hi = ntr.bisect_hi(ranges, vis_range_cmp)
    if hi < lo then
        return
    end

    return { lo, hi }
end
-- TODO: This needs the re-written, generic bisect function that takes two keys.
-- I would use list.bisect() as the base so try and make the logic less removed.

local function update_state_from_init(cur_win, buf, ranges)
    ns_ensure(1)
    local ns_dim = state_ns_dims[1]
    local ns_preview = state_ns_previews[1]
    api.nvim__ns_set(ns_dim, { wins = { cur_win } })
    api.nvim__ns_set(ns_preview, { wins = { cur_win } })

    local top = fn.line("w0")
    local bot = fn.line("w$")

    state_info_cur_win.bot = bot
    state_info_cur_win.buf = api.nvim_win_get_buf(cur_win)
    state_info_cur_win.ns_dim = state_ns_dims[1]
    state_info_cur_win.ns_preview = state_ns_previews[1]
    state_info_cur_win.top = top

    local win_bounds = win_bounds_get(ranges, top, bot)
    if not win_bounds then
        return
    end

    state_ranges_has = true
    state_info_bufs[buf] = { ranges = ranges, win_bounds = {} }
    state_info_bufs[buf].win_bounds[cur_win] = win_bounds
end

---@param buf_ranges table<uinteger, nvim-tools.range.BufRange[]>
---@return boolean New ranges added?
local function buf_ranges_to_state(buf_ranges)
    if not next(buf_ranges) then
        return false
    end

    local valid_buf_range_has = false
    for _, info_win in pairs(state_info_wins) do
        local win_buf = info_win.buf
        local ranges = buf_ranges[info_win.buf]
        if ranges and #ranges > 0 then
            local win_bounds = win_bounds_get(ranges, info_win.top, info_win.bot)
            if win_bounds ~= nil then
                valid_buf_range_has = true
                local info_buf = state_info_bufs[win_buf]
                if info_buf == nil then
                    info_buf = { ranges = ranges, win_bounds = {} }
                    state_info_bufs[win_buf] = info_buf
                end

                info_buf.win_bounds[win_buf] = win_bounds
            end
        end
    end

    if valid_buf_range_has == false then
        return false
    end

    -- TODO: bro this is terrible
    for _, info in pairs(state_info_bufs) do
        for _, range in ipairs(info.ranges) do
            state_symbol_len = range[4] - range[2]
            break
        end
    end

    return true
end
-- TODO: this should be the entry point, so that way you can just make the buf_info structure
-- right away and lazily create the win data

local function preview_state_clear_all()
    require("nvim-tools.list").clear(state_ranges)
    require("nvim-tools.list").clear(state_info_bufs)
    require("nvim-tools.list").clear(state_info_wins)
    require("nvim-tools.list").clear(state_info_bufswins)
    state_symbol_len = DEFAULT_STATE_SYMBOL_LEN
    state_ranges_has = DEFAULT_STATE_RANGES_HAS
end

------------------------------------
-- MARK: Hl Groups and Priorities --
------------------------------------

local hl_dim_priority = vim.hl.priorities.user + 2
local hl_padding_priority = hl_dim_priority - 1
local hl_preview_priority = hl_dim_priority + 1

-- TODO-DEP: Remove this when 0.14 comes out.
api.nvim_set_hl(0, "Dimmed", { default = true, link = "Comment" })
local hl_norm = api.nvim_get_hl_id_by_name("Normal")

do
    local normal = api.nvim_get_hl(0, { name = "Normal", link = false }) or {}
    local orig_fg = normal.fg
    local orig_bg = normal.bg

    local new_fg = orig_bg ---@type integer|string?
    local new_bg = orig_fg ---@type integer|string?

    if not orig_bg then
        if orig_fg then
            new_bg = (vim.o.background == "dark") and "#EFEFEF" or "#1E1E1E"
        else
            new_fg = (vim.o.background == "dark") and "#222222" or "#EFEFEF"
            new_bg = (vim.o.background == "dark") and "#EFEFEF" or "#1E1E1E"
        end
    end

    if not new_fg then
        new_fg = (vim.o.background == "dark") and "#222222" or "#EFEFEF"
    end

    api.nvim_set_hl(0, "catharsisRenameCursor", { fg = new_fg, bg = new_bg, default = true })
end
-- TODO: This is still very vibe coded coded.
-- TODO: nvim-tools this since we need it for farsight.

api.nvim_set_hl(0, "catharsisRenameDim", { default = true, link = "Dimmed" })
api.nvim_set_hl(0, "catharsisRenameNew", { default = true, link = "Substitute" })
local hl_cursor = api.nvim_get_hl_id_by_name("catharsisRenameCursor")
local hl_dim = api.nvim_get_hl_id_by_name("catharsisRenameDim")
local hl_new = api.nvim_get_hl_id_by_name("catharsisRenameNew")

---------------------------------------
-- MARK: Preview Management Autocmds --
---------------------------------------

local function dim_marks_set_new()
    clear_dim_namespaces()
    if state_ranges_has == false then
        return
    end

    for buf, info in pairs(state_info_bufs) do
        local ranges = info.ranges
        for win, bounds in pairs(info.win_bounds) do
            for i = bounds[1], bounds[2] do
                local range = ranges[i]
                local win_info = state_info_wins[win]
                local ns = win_info.ns_dim
                api.nvim_buf_set_extmark(buf, ns, range[1], range[2], {
                    end_row = range[3],
                    end_col = range[4],
                    hl_group = hl_dim,
                    priority = hl_dim_priority,
                })
            end
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

    -- TODO: This doesn't show the cursor when on the first char
    local cmdpos = fn.getcmdpos()
    local text_before = string.sub(new_text, 1, cmdpos - 1)
    local text_after = string.sub(new_text, cmdpos + 1, #new_text)
    local text_at = string.sub(new_text, cmdpos, cmdpos)
    if text_at == "" then
        text_at = " " -- Cursor after line. Draw a block.
    end

    for buf, info in pairs(state_info_bufs) do
        local ranges = info.ranges
        for win, bounds in pairs(info.win_bounds) do
            for i = bounds[1], bounds[2] do
                local range = ranges[i]
                local win_info = state_info_wins[win]
                local ns = win_info.ns_preview
                api.nvim_buf_set_extmark(buf, ns, range[1], range[2], {
                    virt_text = {
                        { text_before, hl_new },
                        { text_at, hl_cursor },
                        { text_after, hl_new },
                    },
                    virt_text_pos = "overlay",
                    priority = hl_preview_priority,
                })
            end
        end
    end

    local padding_len = #new_text - state_symbol_len
    if padding_len <= 0 then
        return
    end

    local padding = string.rep(" ", padding_len)
    for buf, info in pairs(state_info_bufs) do
        local ranges = info.ranges
        for win, bounds in pairs(info.win_bounds) do
            for i = bounds[1], bounds[2] do
                local range = ranges[i]
                local win_info = state_info_wins[win]
                local ns = win_info.ns_preview
                api.nvim_buf_set_extmark(buf, ns, range[1], range[4], {
                    virt_text = { { padding, hl_norm } },
                    virt_text_pos = "inline",
                    priority = hl_padding_priority,
                })
            end
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
    api.nvim_create_autocmd({ "CmdlineChanged", "CursorMovedC" }, {
        group = group,
        callback = function()
            preview_marks_set_new()
        end,
    })
end

local function preview_display_stop()
    clear_dim_namespaces()
    clear_dynamic_preview_namespaces()
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
---@param client_id uinteger
---@param cur_win uinteger
local function req_refs_handler(err, result, ctx, client_id, cur_win)
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

    display_info_init(cur_win)
    if not next(state_info_wins) then
        return
    end

    local bufs = {}
    for _, info in pairs(state_info_wins) do
        bufs[info.buf] = true
    end

    local nts = require("nvim-tools.lsp")
    local encoding = client.offset_encoding
    local buf_ranges = nts.ranges_from_locations_by_buf(result, encoding, bufs)

    if not valid_buf_range_has then
        return
    end

    buf_ranges_to_state(buf_ranges)
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
---@param cur_win uinteger
---@param pos_ext [uinteger, uinteger]
local function ref_req_create(client, buf, pos_ext)
    if not client:supports_method(REFS) then
        return
    end

    local nts = require("nvim-tools.lsp")
    local encoding = client.offset_encoding
    local params = nts.reference_params_create(buf, pos_ext, encoding, true)
    local req_success, req_id = client:request(REFS, params, function(err, results, ctx)
        req_refs_handler(err, results, ctx, client.id, cur_win)
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
local function rename_get_input(client, buf, cur_win, cur_pos_ext, range, prompt_default)
    -- TODO: cur_win needs to come up as data
    -- display_info_init(cur_win)
    local prompt_opts = { prompt = "New Name: ", scope = "cursor" }
    if range ~= nil then
        update_state_from_init(cur_win, buf, { range })
        -- preview_state_set_from_prep(range, buf)
        if prompt_default == true then
            local ntb = require("nvim-tools.buf")
            prompt_opts.default = ntb.get_text_from_range(range, buf)
        end
    end

    preview_display_init()
    ref_req_create(client, buf, cur_win, cur_pos_ext)

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
---@param cur_win uinteger
---@param cur_pos_ext nvim-tools.Pos
---@param prompt_default boolean
local function req_prep_rn_handler(err, result, ctx, buf, cur_win, cur_pos_ext, prompt_default)
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

    rename_get_input(client, buf, cur_win, cur_pos_ext, default_range, prompt_default)
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
    local cur_win = api.nvim_get_current_win()
    local cur_pos_ext = ntp.mark_to_ext_pos(api.nvim_win_get_cursor(cur_win))
    local new_name = opts_ctx.new_name
    if new_name ~= nil then
        rename_do(client, buf, cur_pos_ext, new_name)
        return
    end

    local prompt_default = opts_ctx.prompt_default
    if not supports_prep then
        local ntb = require("nvim-tools.buf")
        local cr = ntb.match_line_under_cursor(cur_pos_ext, buf, [[\k\+]])
        rename_get_input(client, buf, cur_win, cur_pos_ext, cr, opts_ctx.prompt_default)
        return
    end

    local encoding = client.offset_encoding
    ---@diagnostic disable-next-line: param-type-mismatch
    local params = nts.text_doc_pos_params_create(buf, cur_pos_ext, encoding)
    -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocument_prepareRename
    local req_success, req_id = client:request(PREP, params, function(err, result, ctx)
        req_prep_rn_handler(err, result, ctx, buf, cur_win, cur_pos_ext, prompt_default)
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

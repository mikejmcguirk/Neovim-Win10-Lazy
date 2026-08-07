local api = vim.api
local fn = vim.fn
local uv = vim.uv

local ntb = require("nvim-tools.buf")
local ntt = require("nvim-tools.table")
local ntq = require("nvim-tools.quickfix")

-----------------
-- MARK: State --
-----------------

local state_bufs = {} ---@type table<uinteger, uinteger>
local state_extmarks = {} ---@type table<uinteger, uinteger>
local state_list_win = -1
local state_pvw_win = -1
local state_queued_update = false
---@diagnostic disable-next-line: unnecessary-assert, call-non-callable
local state_timer = assert(uv.new_timer())

---@return uinteger|nil
local function pvw_win_find()
    local pvw_win, _ = ntt.i_find(api.nvim_tabpage_list_wins(0), function(win)
        return api.nvim_get_option_value("pvw", { win = win })
    end)

    return pvw_win
end

---@param buf uinteger
---@return uinteger?
local function cached_buf_get(buf)
    local cached_buf = state_bufs[buf]
    if cached_buf == nil then
        return
    end

    if not api.nvim_buf_is_valid(cached_buf) then
        state_bufs[buf] = nil
    else
        return cached_buf
    end
end

local function has_valid_pvw_win_state()
    if state_pvw_win < 100 then
        return false
    end

    local is_in_list_win = api.nvim_get_current_win() == state_list_win
    return api.nvim_win_is_valid(state_pvw_win) and is_in_list_win
end

---------------------------------
-- MARK: Namespaces and Groups --
---------------------------------

local group = api.nvim_create_augroup("qf-herder-preview", {})
local PVW_FT = "qf-herder-preview"

local hl_ns = api.nvim_create_namespace("qf-herder.preview")
local HL_GROUP_STR = "QfRancherPreviewRange"
-- Set in `/plugin`
local pvw_range_hl = api.nvim_get_hl_id_by_name(HL_GROUP_STR)

----------------------------
-- MARK: State Management --
----------------------------

local function state_clear()
    state_queued_update = false
    if uv.is_active(state_timer) then
        uv.timer_stop(state_timer)
    end

    local autocmds = api.nvim_get_autocmds({ group = group })
    for _, autocmd in ipairs(autocmds) do
        local id = autocmd.id
        if id ~= nil then
            api.nvim_del_autocmd(id)
        end
    end

    state_list_win = -1
    state_pvw_win = -1
    for _, buf in pairs(state_bufs) do
        api.nvim_buf_delete(buf, { force = true })
    end

    ntt.clear(state_bufs)
    ntt.clear(state_extmarks)
end

---@return boolean
local function has_list_wins()
    return ntt.i_any(api.nvim_list_tabpages(), function(tabpage)
        return ntt.i_any(api.nvim_tabpage_list_wins(tabpage), function(win)
            local wintype = vim.call("win_gettype", win)
            return wintype == "quickfix" or wintype == "loclist"
        end)
    end)
end

---@return nil
local function state_clear_checked()
    if not has_list_wins() then
        state_clear()
    end
end

--------------------------------
-- MARK: Preview Buf Creation --
--------------------------------

---@return uinteger
local function create_fallback_buf()
    local buf = ntb.create_temp_buf("wipe", false, "nofile", PVW_FT, true)
    api.nvim_buf_set_lines(buf, 0, 0, false, { "No valid bufnr for this list entry" })
    api.nvim_set_option_value("ma", false, { buf = buf })
    return buf
end

---@param buf uinteger
---@return string[]
local function buf_get_lines(buf)
    if not api.nvim_buf_is_valid(buf) then
        return { buf .. " is not valid" }
    end

    if api.nvim_buf_is_loaded(buf) then
        return api.nvim_buf_get_lines(buf, 0, -1, false)
    end

    local ntf = require("nvim-tools.fs")
    local ok, text = ntf.read_file(api.nvim_buf_get_name(buf))
    if ok and text ~= nil then
        return vim.split(text, "\n")
    else
        return { "Unable to read lines for buffer " .. buf }
    end
end

---@param item_buf uinteger
---@param preview_buf uinteger
local function preview_buf_set_lines_from_item_buf(item_buf, preview_buf)
    local lines = buf_get_lines(item_buf)
    api.nvim_set_option_value("modifiable", true, { buf = preview_buf })
    api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
    api.nvim_set_option_value("modifiable", false, { buf = preview_buf })
end

---@param buf uinteger
---@return uinteger
local function buf_mtime_get(buf)
    local stat = uv.fs_stat(api.nvim_buf_get_name(buf))
    return stat and stat.mtime.sec or 0
end

---@param item_buf uinteger
---@param preview_buf uinteger
---@param item_buf_version uinteger?
---@param item_buf_mtime uinteger?
local function preview_buf_set_version(item_buf, preview_buf, item_buf_version, item_buf_mtime)
    item_buf_version = item_buf_version or vim.lsp.util.buf_versions[item_buf]
    api.nvim_buf_set_var(preview_buf, "src_version", item_buf_version)
    item_buf_mtime = item_buf_mtime or buf_mtime_get(item_buf)
    api.nvim_buf_set_var(preview_buf, "src_mtime", item_buf_mtime)
end

---@param ft string
---@return string|nil
local function get_parsable_lang(ft)
    local ts_language = vim.treesitter.language
    -- Credit fzf-lua for this method
    local lang = ts_language.get_lang(ft) or ft
    return ts_language.add(lang) and lang or nil
end

---@param item_buf uinteger
---@return string
local function get_item_buf_ft(item_buf)
    local item_ft = api.nvim_get_option_value("ft", { buf = item_buf })
    return item_ft ~= "" and item_ft or vim.filetype.match({ buf = item_buf }) or ""
end

---@param item_buf uinteger
---@return uinteger
local function preview_buf_from_item_create(item_buf)
    local preview_buf = ntb.create_temp_buf(nil, false, "nofile", "qf-rancher-preview", true)
    preview_buf_set_lines_from_item_buf(item_buf, preview_buf)
    preview_buf_set_version(item_buf, preview_buf)

    local item_ft = get_item_buf_ft(item_buf)
    local lang = get_parsable_lang(item_ft)
    if lang then
        vim.treesitter.start(preview_buf, lang)
    else
        api.nvim_set_option_value("syntax", item_ft, { buf = preview_buf })
    end

    return preview_buf
end

---@param item_buf uinteger?
---@return uinteger
local function get_preview_create(item_buf)
    if item_buf == nil or not api.nvim_buf_is_valid(item_buf) then
        return create_fallback_buf()
    end

    local cached_buf = cached_buf_get(item_buf)
    if cached_buf == nil then
        local preview_buf = preview_buf_from_item_create(item_buf)
        state_bufs[item_buf] = preview_buf
        return preview_buf
    end

    local item_buf_version = vim.lsp.util.buf_versions[item_buf]
    local item_buf_mtime = buf_mtime_get(item_buf)
    local pvw_buf_version = api.nvim_buf_get_var(cached_buf, "src_version")
    local pvw_buf_mtime = api.nvim_buf_get_var(cached_buf, "src_mtime")
    if item_buf_version > pvw_buf_version or item_buf_mtime > pvw_buf_mtime then
        preview_buf_set_version(item_buf, cached_buf, item_buf_version, item_buf_mtime)
        preview_buf_set_lines_from_item_buf(item_buf, cached_buf)
    end

    return cached_buf
end

---@param preview_buf uinteger
---@param range_api [uinteger, uinteger, uinteger, uinteger] 0,0,0,0 indexed, end-exclusive
local function set_err_range_extmark(preview_buf, range_api)
    state_extmarks[preview_buf] =
        api.nvim_buf_set_extmark(preview_buf, hl_ns, range_api[1], range_api[2], {
            hl_group = pvw_range_hl,
            id = state_extmarks[preview_buf],
            end_row = range_api[3],
            end_col = range_api[4],
            priority = 200,
            strict = false,
        })
end

---@param entry vim.quickfix.entry
---@return [uinteger, uinteger, uinteger, uinteger] 0,0,0,0 indexed, end-exclusive
local function entry_range_api_get(entry)
    local ntr = require("nvim-tools.range")
    ---@diagnostic disable-next-line: param-type-mismatch
    return ntr.qf_to_api(ntr.qf_from_entry(entry))
end

---@param entry vim.quickfix.entry
---@return uinteger, [uinteger, uinteger, uinteger, uinteger]
local function preview_buf_get(entry)
    local preview_buf = get_preview_create(entry.bufnr)
    local qf_range_api = entry_range_api_get(entry)
    set_err_range_extmark(preview_buf, qf_range_api)
    return preview_buf, qf_range_api
end

-------------------------------
-- MARK: Preview Win Opening --
-------------------------------

---@param preview_win integer
local function set_preview_win_opts(preview_win)
    local preview_scope = { win = preview_win }

    api.nvim_set_option_value("cc", "", preview_scope)
    api.nvim_set_option_value("cul", true, preview_scope)

    api.nvim_set_option_value("fdc", "0", preview_scope)
    api.nvim_set_option_value("fdm", "manual", preview_scope)

    api.nvim_set_option_value("list", false, preview_scope)

    api.nvim_set_option_value("nu", true, preview_scope)
    api.nvim_set_option_value("rnu", false, preview_scope)
    api.nvim_set_option_value("scl", "no", preview_scope)
    api.nvim_set_option_value("stc", "", preview_scope)

    api.nvim_set_option_value("spell", false, preview_scope)

    api.nvim_set_option_value("so", 6, preview_scope)
    api.nvim_set_option_value("siso", 6, preview_scope)

    api.nvim_win_set_config(preview_win, { focusable = false })
end

---@param qf_range_api [uinteger, uinteger, uinteger, uinteger]
---@param cfg qf-herder.preview.Cfg
local function pvw_pos_set(qf_range_api, cfg)
    local ntw = require("nvim-tools.win")
    ntw.protected_set_cursor(state_pvw_win, { qf_range_api[1] + 1, qf_range_api[2] })
    if cfg.do_zzze then
        api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        api.nvim_cmd({ cmd = "normal", args = { "ze" }, bang = true }, {})
    end
end

---@param cfg qf-herder.preview.Cfg
local function update_preview_win_buf(cfg)
    if state_timer:get_due_in() > 0 then
        state_queued_update = true
        return
    end

    if not has_valid_pvw_win_state() then
        state_clear_checked()
        return
    end

    local wintype = fn.win_gettype(state_list_win)
    local src_win = wintype == "loclist" and state_list_win or nil
    local ok, err, entry = ntq.get_item_under_cursor(src_win)
    if not ok then
        api.nvim_echo({ { err, "WarningMsg" } }, false, {})
        return
    end

    local preview_buf, qf_range_api = preview_buf_get(entry)
    api.nvim_win_set_buf(state_pvw_win, preview_buf)
    pvw_pos_set(qf_range_api, cfg)

    uv.timer_start(state_timer, 150, 0, function()
        if state_queued_update then
            state_queued_update = false
            vim.schedule(function()
                update_preview_win_buf(cfg)
            end)
        end
    end)
end

local M = {}

---@param cfg qf-herder.preview.Cfg
local function create_autocmds(cfg)
    if #api.nvim_get_autocmds({ group = group }) > 0 then
        return
    end

    local list_win_buf = api.nvim_win_get_buf(state_list_win)

    api.nvim_create_autocmd({ "CursorMoved", "QuickFixCmdPost" }, {
        group = group,
        buffer = list_win_buf,
        callback = function()
            update_preview_win_buf(cfg)
        end,
    })

    api.nvim_create_autocmd("BufLeave", {
        group = group,
        ---TODO-DEP: When 0.14 comes out, change to `buf`
        buffer = list_win_buf,
        callback = function()
            M.pvw_win_close()
            vim.schedule(function()
                state_clear_checked()
            end)
        end,
    })

    api.nvim_create_autocmd("WinClosed", {
        group = group,
        buffer = list_win_buf,
        callback = function()
            vim.schedule(function()
                state_clear_checked()
            end)
        end,
    })

    -- Account for situations where WinLeave does not fire properly
    api.nvim_create_autocmd("WinEnter", {
        group = group,
        callback = function()
            local cur_win = api.nvim_get_current_win()
            if cur_win ~= state_list_win then
                M.pvw_win_close()
            end
        end,
    })

    api.nvim_create_autocmd("WinLeave", {
        group = group,
        callback = function()
            local cur_win = api.nvim_get_current_win()
            if cur_win == state_list_win then
                M.pvw_win_close()
            end
        end,
    })
end

---@param cfg qf-herder.preview.Cfg
local function pvw_open(cfg)
    local list_win = api.nvim_get_current_win()
    local wintype = fn.win_gettype()
    if wintype ~= "quickfix" and wintype ~= "loclist" then
        api.nvim_echo({ { "Current window is not an error list" } }, false, {})
        return
    end

    local ok, err, entry = ntq.get_item_under_cursor(wintype == "loclist" and list_win or nil)
    if not ok then
        api.nvim_echo({ { err, "WarningMsg" } }, false, {})
        return
    end

    local preview_buf, qf_range_api = preview_buf_get(entry)
    api.nvim_cmd({ cmd = "pbuf", args = { tostring(preview_buf) } }, {})
    local pvw_win = pvw_win_find()
    if pvw_win == nil or pvw_win < 1000 then
        api.nvim_echo({ { "Preview window did not open", "ErrorMsg" } }, false, {})
        return
    else
        state_pvw_win = pvw_win
    end

    state_list_win = list_win
    -- MID: Should be possible to title the preview win here as well
    set_preview_win_opts(state_pvw_win)
    pvw_pos_set(qf_range_api, cfg)
    create_autocmds(cfg)

    uv.timer_start(state_timer, 150, 0, function()
        if state_queued_update then
            state_queued_update = false
            vim.schedule(function()
                update_preview_win_buf(cfg)
            end)
        end
    end)
end

--------------------
-- MARK: External --
--------------------

---@param cfg qf-herder.preview.Cfg
function M.pvw_win_open(cfg)
    if state_pvw_win >= 1000 then
        if api.nvim_win_is_valid(state_pvw_win) then
            return
        else
            state_pvw_win = -1
            state_list_win = -1
        end
    end

    local cur_pvw_win = pvw_win_find()
    if cur_pvw_win ~= nil then
        api.nvim_win_close(cur_pvw_win, true)
    end

    return pvw_open(cfg)
end

local function pvw_close()
    if state_pvw_win >= 1000 and api.nvim_win_is_valid(state_pvw_win) then
        api.nvim_win_close(state_pvw_win, true)
    end

    state_pvw_win = -1
    state_list_win = -1
end

function M.pvw_win_close()
    if state_pvw_win >= 1000 then
        pvw_close()
    end
end

---@param cfg qf-herder.preview.Cfg
function M.pvw_win_toggle(cfg)
    if state_pvw_win >= 1000 then
        pvw_close()
    else
        pvw_open(cfg)
    end
end

return M

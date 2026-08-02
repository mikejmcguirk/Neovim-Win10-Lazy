local api = vim.api
local fn = vim.fn
local uv = vim.uv

-----------------
-- MARK: State --
-----------------

local state_pvw_win = -1
local state_list_win = -1
local state_timer = assert(uv.new_timer)

local function pvw_win_find()
    local ntt = require("nvim-tools.table")
    local pvw_win = ntt.i_find(api.nvim_tabpage_list_wins(0), function(win)
        return api.nvim_get_option_value("pvw", { win = win })
    end)

    state_pvw_win = pvw_win ~= nil and pvw_win or -1
end

---------------------
-- MARK: Old Stuff --
---------------------

local ru = Qfr_Defer_Require("qf-rancher.util") ---@type qf-rancher.Util

local set_opt = api.nvim_set_option_value

local bufs = {} ---@type table<uinteger, uinteger>
local extmarks = {}
local parsers = {}

-- TODO: change back to rancher
local GROUP_NAME = "qf-herder-preview"
local group = api.nvim_create_augroup(GROUP_NAME, {})

local hl_ns = api.nvim_create_namespace("qfr-preview-hl")
local HL_GROUP_STR = "QfRancherPreviewRange"
local cur_hl = api.nvim_get_hl(0, { name = HL_GROUP_STR })
local cur_hl_keys = vim.tbl_keys(cur_hl)
if (not cur_hl) or #cur_hl_keys == 0 then
    api.nvim_set_hl(0, HL_GROUP_STR, { link = "CurSearch" })
end

local timer = nil ---@type uv.uv_timer_t|nil
local queued_update = false

---@return nil
local function clear_session_data()
    -- MID: Could be useful to have an opt to keep caches for bufs over X integer file size
    for _, buf in pairs(bufs) do
        api.nvim_buf_delete(buf, { force = true })
    end

    bufs = {}
    extmarks = {}

    local autocmds = api.nvim_get_autocmds({ group = group })
    for _, autocmd in ipairs(autocmds) do
        local id = autocmd.id
        if id ~= nil then
            api.nvim_del_autocmd(autocmd.id)
        end
    end
end

---@return boolean
local function has_list_wins()
    local tabpages = api.nvim_list_tabpages()
    local qf_wins = ru._find_qf_wins(tabpages)
    if #qf_wins > 0 then
        return true
    end

    local ll_wins = ru._find_ll_wins({ tabpages = tabpages })
    return #ll_wins > 0
end

---@return nil
local function checked_session_clear()
    local has_lists = has_list_wins()
    if not has_lists then
        clear_session_data()
    end
end

---@return uinteger
local function create_fallback_buf()
    local ntb = require("nvim-tools.buf")
    local buf = ntb.create_temp_buf("wipe", false, "nofile", "qf-rancher-preview", true)
    local lines = { "No valid bufnr for this list entry" }
    api.nvim_buf_set_lines(buf, 0, 0, false, lines)
    set_opt("ma", false, { buf = buf })

    return buf
end

---@param buf integer
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
        return { "Unable to read lines for bufnr " .. buf }
    end
end

---@param item_buf integer
---@param preview_buf integer
local function buf_update_lines(item_buf, preview_buf)
    local lines = buf_get_lines(item_buf)
    set_opt("modifiable", true, { buf = preview_buf })
    api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
    set_opt("modifiable", false, { buf = preview_buf })
end

---@param buf uinteger
---@return uinteger
local function buf_mtime_get(buf)
    local stat = uv.fs_stat(api.nvim_buf_get_name(buf))
    return stat and stat.mtime.sec or 0
end

---@param item_buf integer
---@param preview_buf integer
---@return nil
local function update_preview_buf_version(item_buf, preview_buf)
    local src_changedtick = api.nvim_buf_get_changedtick(item_buf)
    api.nvim_buf_set_var(preview_buf, "src_changedtick", src_changedtick)
    local src_mtime = buf_mtime_get(item_buf)
    api.nvim_buf_set_var(preview_buf, "src_mtime", src_mtime)
end
-- TODO: Should use buf_version instead of changedtick

---@param ft string
---@return string|nil
local function get_parsable_lang(ft)
    local lang = vim.treesitter.language.get_lang(ft) or ft
    if parsers[lang] then
        return lang
    end

    -- Credit fzflua for this method
    local has_parser = vim.treesitter.language.add(lang)
    if has_parser then
        parsers[lang] = true
        return lang
    end
end

---@param item_buf integer
---@return string
local function get_item_buf_ft(item_buf)
    local item_ft = api.nvim_get_option_value("ft", { buf = item_buf })
    if item_ft ~= "" then
        return item_ft
    else
        return vim.filetype.match({ buf = item_buf }) or ""
    end
end

---@param item_buf integer
---@return integer
local function create_preview_buf_from_item(item_buf)
    local lines = buf_get_lines(item_buf)
    local ntb = require("nvim-tools.buf")
    local preview_buf = ntb.create_temp_buf(nil, false, "nofile", "qf-rancher-preview", true)
    api.nvim_buf_set_lines(preview_buf, 0, 0, false, lines)
    set_opt("ma", false, { buf = preview_buf })

    update_preview_buf_version(item_buf, preview_buf)

    local item_ft = get_item_buf_ft(item_buf)
    local lang = get_parsable_lang(item_ft)
    if lang then
        vim.treesitter.start(preview_buf, lang)
    else
        set_opt("syntax", item_ft, { buf = preview_buf })
    end

    return preview_buf
end

---@param preview_buf integer
---@param range_api [uinteger, uinteger, uinteger, uinteger] 0,0,0,0 indexed, end-exclusive
---@return nil
local function set_err_range_extmark(preview_buf, range_api)
    extmarks[preview_buf] =
        api.nvim_buf_set_extmark(preview_buf, hl_ns, range_api[1], range_api[2], {
            -- TODO: store an int variable in the file for this. Also use herder naming for now
            hl_group = "QfRancherPreviewRange",
            id = extmarks[preview_buf],
            end_row = range_api[3],
            end_col = range_api[4],
            priority = 200,
            strict = false,
        })
end

---@param item vim.quickfix.entry
---@return integer
local function get_preview_buf(item)
    local item_buf = item.bufnr
    if (not item_buf) or not api.nvim_buf_is_valid(item_buf) then
        return create_fallback_buf()
    end

    local cache_buf = bufs[item_buf]
    if cache_buf then
        if not api.nvim_buf_is_valid(cache_buf) then
            return create_fallback_buf()
        end

        local src_changedtick = api.nvim_buf_get_changedtick(item_buf)
        local old_changedtick = vim.b[cache_buf].src_changedtick
        local changedtick_updated = src_changedtick ~= old_changedtick
        local src_mtime = buf_mtime_get(item_buf)
        local old_mtime = vim.b[cache_buf].src_mtime
        local mtime_updated = src_mtime ~= old_mtime

        if changedtick_updated or mtime_updated then
            api.nvim_buf_set_var(cache_buf, "src_changedtick", src_changedtick)
            api.nvim_buf_set_var(cache_buf, "src_mtime", src_mtime)
            buf_update_lines(item_buf, cache_buf)
        end
    else
        cache_buf = create_preview_buf_from_item(item_buf)
        bufs[item_buf] = cache_buf
    end

    return bufs[item_buf]
end
-- TODO: This feels disorganized.

---@param entry vim.quickfix.entry
---@param preview_buf uinteger
---@return [uinteger, uinteger, uinteger, uinteger] 0,0,0,0 indexed, end-exclusive
local function entry_range_api_get(entry, preview_buf)
    local lnum = entry.lnum
    local col = entry.col
    local end_lnum = entry.end_lnum
    local end_col = entry.end_col
    local vcol = entry.vcol

    local ntr = require("nvim-tools.range")
    ---@diagnostic disable-next-line: param-type-mismatch
    return ntr.evex_to_api(ntr.qf_to_evex(lnum, col, end_lnum, end_col, vcol, preview_buf))
end

-- TODO: Make sure all calls of this get the correct cfg somehow
---@param cfg qf-herder.preview.Cfg
local function update_preview_win_buf(cfg)
    if timer and timer:get_due_in() > 0 then
        queued_update = true
        return
    end

    if state_pvw_win < 1000 then
        return
    end

    local cur_win = api.nvim_get_current_win()
    if cur_win ~= state_list_win then
        -- TODO: Should probably do teardown
        return
    end

    local wintype = fn.win_gettype(state_list_win)
    local src_win = wintype == "loclist" and state_list_win or nil
    local ok, err, entry = require("nvim-tools.quickfix").get_item_under_cursor(src_win)
    if not ok then
        api.nvim_echo({ { err, "WarningMsg" } }, false, {})
        return
    end

    local preview_buf = get_preview_buf(entry)
    local qf_range_api = entry_range_api_get(entry, preview_buf)
    set_err_range_extmark(preview_buf, qf_range_api)

    api.nvim_win_set_buf(state_pvw_win, preview_buf)

    local ntw = require("nvim-tools.win")
    ntw.protected_set_cursor(state_pvw_win, { qf_range_api[1] + 1, qf_range_api[2] })
    if cfg.do_zzze then
        api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        api.nvim_cmd({ cmd = "normal", args = { "ze" }, bang = true }, {})
    end

    uv.timer_start(state_timer, 150, 0, function()
        if queued_update then
            queued_update = false
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
        buffer = list_win_buf,
        callback = function()
            M.close_preview_win()
            vim.schedule(function()
                checked_session_clear()
            end)
        end,
    })

    api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function()
            vim.schedule(function()
                checked_session_clear()
            end)
        end,
    })

    -- Account for situations where WinLeave does not fire properly
    api.nvim_create_autocmd("WinEnter", {
        group = group,
        callback = function()
            local cur_win = api.nvim_get_current_win()
            if cur_win ~= state_list_win then
                M.close_preview_win()
            end
        end,
    })

    api.nvim_create_autocmd("WinLeave", {
        group = group,
        callback = function()
            local cur_win = api.nvim_get_current_win()
            if cur_win == state_list_win then
                M.close_preview_win()
            end
        end,
    })
end

---@param preview_win integer
local function set_preview_win_opts(preview_win)
    local preview_scope = { win = preview_win }

    set_opt("cc", "", preview_scope)
    set_opt("cul", true, preview_scope)

    set_opt("fdc", "0", preview_scope)
    set_opt("fdm", "manual", preview_scope)

    set_opt("list", false, preview_scope)

    set_opt("nu", true, preview_scope)
    set_opt("rnu", false, preview_scope)
    set_opt("scl", "no", preview_scope)
    set_opt("stc", "", preview_scope)

    set_opt("spell", false, preview_scope)

    set_opt("so", 6, preview_scope)
    set_opt("siso", 6, preview_scope)
end

---@param cfg qf-herder.preview.Cfg
local function pvw_open(cfg)
    local list_win = api.nvim_get_current_win()
    local wintype = fn.win_gettype()
    if wintype ~= "quickfix" and wintype ~= "loclist" then
        api.nvim_echo({ { "Current window is not an error list" } }, false, {})
        return
    end

    local src_win = wintype == "loclist" and list_win or nil
    local ok, err, entry = require("nvim-tools.quickfix").get_item_under_cursor(src_win)
    if not ok then
        api.nvim_echo({ { err, "WarningMsg" } }, false, {})
        return
    end

    local preview_buf = get_preview_buf(entry)
    local qf_range_api = entry_range_api_get(entry, preview_buf)
    set_err_range_extmark(preview_buf, qf_range_api)

    api.nvim_cmd({ cmd = "pbuf", args = { preview_buf } }, {})
    pvw_win_find()
    if state_pvw_win < 1000 then
        -- TODO: Should provide a useful error
        return
    end

    state_list_win = list_win
    -- MID: Should be possible to title the preview win here as well
    set_preview_win_opts(state_pvw_win)
    local ntw = require("nvim-tools.win")
    ntw.protected_set_cursor(state_pvw_win, { qf_range_api[1] + 1, qf_range_api[2] })

    if cfg.do_zzze then
        api.nvim_cmd({ cmd = "normal", args = { "zz" }, bang = true }, {})
        api.nvim_cmd({ cmd = "normal", args = { "ze" }, bang = true }, {})
    end

    create_autocmds()
    uv.timer_start(state_timer, 150, 0, function()
        if queued_update then
            queued_update = false
            vim.schedule(update_preview_win_buf)
        end
    end)
end
-- TODO: Lots of overlap with the update function.

---@param opts? qf-rancher.preview.OpenOpts
function M.open_preview_win(opts)
    if state_pvw_win < 1000 then
        return pvw_open(opts)
    end
end

local function pvw_close()
    api.nvim_win_close(state_pvw_win, true)
    state_pvw_win = -1
    state_list_win = -1
end

function M.close_preview_win()
    if state_pvw_win >= 1000 then
        pvw_close()
    end
end

---@param cfg qf-herder.preview.Cfg
function M.toggle_preview_win(cfg)
    if state_pvw_win >= 1000 then
        pvw_close()
    else
        pvw_open(cfg)
    end
end

return M

---@export Preview

-- PR: in win_config:
-- - border does not contain bold
-- - title is not correct (any instead of string|[string,string|integer?][])
-- If doing a PR for these, double check that my annotation for title is correct. Also, check and
-- see if anything else is incorrect.
-- Also see if the type annotation is written in the C code or something, rather than having to
-- submit an issue for type annotations
-- PR: Kind of a long-shot feature request, but window local autocmds.

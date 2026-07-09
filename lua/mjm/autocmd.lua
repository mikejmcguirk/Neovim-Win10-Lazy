local api = vim.api

local mjm_group = api.nvim_create_augroup("mjm-group", {})
local clear_conditions = { "BufLeave", "InsertEnter", "RecordingEnter", "TabLeave", "WinLeave" }
api.nvim_create_autocmd(clear_conditions, {
    group = mjm_group,
    pattern = "*",
    -- The highlight state is saved and restored when autocmds are triggered, so
    -- schedule_wrap is used to trigger nohlsearch aftewards
    -- See nohlsearch() help
    callback = vim.schedule_wrap(function()
        api.nvim_cmd({ cmd = "nohlsearch" }, {})
    end),
})

api.nvim_create_autocmd("BufWinEnter", {
    group = mjm_group,
    callback = function(ev)
        local win = api.nvim_get_current_win()
        local config = api.nvim_win_get_config(win)
        if config.relative and #config.relative > 0 then
            return
        end

        local bt = api.nvim_get_option_value("bt", { buf = ev.buf }) ---@type string
        if bt ~= "" then
            return
        end

        local cursor = api.nvim_win_get_cursor(win) ---@type { [1]:integer, [2]:integer }
        if not (cursor[1] == 1 and cursor[2] == 0) then
            return
        end

        local mark = api.nvim_buf_get_mark(ev.buf, '"') ---@type { [1]:integer, [2]:integer }
        if mark[1] == 1 and mark[2] == 0 then
            return
        end

        require("nvim-tools.win").protected_set_cursor(win, mark)
        api.nvim_win_call(win, function()
            api.nvim_cmd({ cmd = "norm", args = { "zz" }, bang = true }, {})
        end)
    end,
})

api.nvim_create_autocmd("TextYankPost", {
    group = mjm_group,
    callback = function()
        vim.hl.hl_op({ higroup = "IncText", timeout = 175 })
    end,
})

api.nvim_create_autocmd("TextPutPost", {
    group = mjm_group,
    callback = function()
        vim.hl.hl_op({ higroup = "Number", timeout = 175 })
    end,
})

api.nvim_create_autocmd("VimLeavePre", {
    group = mjm_group,
    callback = function()
        vim.fn.setreg("/", "")
    end,
})

local lcs_cache = {} ---@type table<uinteger, string>
local lcs_ins_cache = {} ---@type table<uinteger, string>

---@param buf uinteger
local function lcs_get_and_set(buf)
    local lcs_tbl = {}
    lcs_tbl[#lcs_tbl + 1] = "extends:»,precedes:«,nbsp:␣"
    if api.nvim_get_option_value("et", { buf = buf }) == true then
        ---@type uinteger
        local sw = api.nvim_get_option_value("sw", { buf = buf })
        local spaces = string.rep(" ", sw - 1)
        lcs_tbl[#lcs_tbl + 1] = "leadmultispace:│" .. spaces
        lcs_tbl[#lcs_tbl + 1] = "tab:<->"
    else
        lcs_tbl[#lcs_tbl + 1] = "lead:⣿"
        lcs_tbl[#lcs_tbl + 1] = "leadtab:│  "
        lcs_tbl[#lcs_tbl + 1] = "tab:   "
    end

    local lcs_ins_tbl = require("nvim-tools.table").i_copy(lcs_tbl)
    lcs_tbl[#lcs_tbl + 1] = "trail:⣿"
    local lcs = table.concat(lcs_tbl, ",")
    local lcs_ins = table.concat(lcs_ins_tbl, ",")
    local ntm = require("nvim-tools.misc")
    if ntm.is_insert_mode(api.nvim_get_mode().mode) == true then
        api.nvim_set_option_value("lcs", lcs_ins, { scope = "local" })
    else
        api.nvim_set_option_value("lcs", lcs, { scope = "local" })
    end

    lcs_cache[buf] = lcs
    lcs_ins_cache[buf] = lcs_ins
end

local group_name = "mjm.lcs"
local group = api.nvim_create_augroup(group_name, {})
api.nvim_create_autocmd("FileType", {
    group = group,
    -- Schedule wrap to let other filetype options set.
    callback = vim.schedule_wrap(function(ev)
        local buf = ev.buf
        -- In case this fired on a temporary buffer.
        if not api.nvim_buf_is_valid(buf) then
            return
        end

        if api.nvim_get_option_value("bt", { buf = buf }) ~= "" then
            return
        end

        lcs_get_and_set(buf)
    end),
})

api.nvim_create_autocmd("OptionSet", {
    group = group,
    callback = function(ev)
        local match = ev.match
        if not (match == "expandtab" or match == "shiftwidth") then
            return
        end

        local buf = ev.buf ~= 0 and ev.buf or api.nvim_get_current_buf()
        if api.nvim_get_option_value("bt", { buf = buf }) ~= "" then
            return
        end

        lcs_get_and_set(buf)
    end,
})

-- MID: This should not be a separate autocmd.
api.nvim_create_autocmd("OptionSet", {
    group = group,
    callback = function(ev)
        if ev.match ~= "buftype" then
            return
        end

        local buf = ev.buf ~= 0 and ev.buf or api.nvim_get_current_buf()
        if vim.v.option_new == "" then
            lcs_get_and_set(buf)
        else
            lcs_cache[buf] = nil
            lcs_ins_cache[buf] = nil
            api.nvim_set_option_value("lcs", "", { scope = "local" })
        end
    end,
})

-- MID: Instead of InsertEnter/InsertLeave, do it based on ModeChanged.
-- - Would prevent leading/trailing spacechars from appearing in `ni` mode.
api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function(ev)
        local ins_cached = lcs_ins_cache[ev.buf]
        if ins_cached ~= nil then
            api.nvim_set_option_value("lcs", ins_cached, { scope = "local" })
        end
    end,
})

api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function(ev)
        local cached = lcs_cache[ev.buf]
        if cached ~= nil then
            api.nvim_set_option_value("lcs", cached, { scope = "local" })
        end
    end,
})

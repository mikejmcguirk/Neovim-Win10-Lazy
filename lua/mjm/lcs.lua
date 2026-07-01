local api = vim.api

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

-- MID: Instead of InsertEnter/InsertLeave, do it based on ModeChanged.

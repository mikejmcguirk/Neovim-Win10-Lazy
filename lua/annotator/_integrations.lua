local api = vim.api

local M = {}

local function check_ft()
    return api.nvim_get_option_value("filetype", { buf = 0 }) == "lua"
end
-- TODO: Delete once proper comment string checking is added.

---@param cur_buf boolean
function M.fzf_lua_grep(cur_buf)
    if not check_ft() then
        return
    end

    local fzf_lua = require("fzf-lua")
    if not fzf_lua then
        return
    end

    local grep = cur_buf and fzf_lua.grep_curbuf or fzf_lua.grep
    grep({ regex = "^\\s*-- MARK:" })
end

---@param cur_buf boolean
function M.rancher_grep(cur_buf)
    if not check_ft() then
        return
    end

    local r_grep = require("qf-rancher.grep")
    if not r_grep then
        return
    end

    local src_win = cur_buf == true and 0 or nil
    local locs = require("qf-rancher.lib.grep-locs")
    local loc = cur_buf and locs.get_cur_buf or locs.get_cwd
    r_grep.grep(src_win, " ", {}, {
        case = "sensitive",
        locations = loc,
        name = "MARK",
        pattern = "^\\s*-- MARK:",
        regex = true,
    }, {})
end

return M

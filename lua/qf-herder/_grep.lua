local api = vim.api
local fn = vim.fn

local ntt = require("nvim-tools.table")
local _util = require("qf-herder._util")

local base_cmd = { "rg", "--vimgrep", "-uu" }

---@param pattern string
---@param case "ignore"|"smart"|""
---@return string[]
local function get_full_parts_rg(pattern, case, regex, locations)
    local cmd = ntt.i_copy(base_cmd) ---@type string[]
    if fn.has("win32") == 1 then
        cmd[#cmd + 1] = "--crlf"
    end

    if case == "smart" then
        cmd[#cmd + 1] = "--smart-case" -- or "-S"
    elseif case == "ignore" then
        cmd[#cmd + 1] = "--ignore-case" -- or "-i"
    end

    if not regex then
        cmd[#cmd + 1] = "--fixed-strings" -- or "-F"
    end

    if string.find(pattern, "\n", 1, true) ~= nil then
        cmd[#cmd + 1] = "--multiline" -- or "-U"
    end

    cmd[#cmd + 1] = "--"
    cmd[#cmd + 1] = pattern
    ntt.i_append(cmd, locations)

    return cmd
end

---@param name string
---@param regex boolean
---@return string
local function prompt_resolve(name, regex)
    return "[rg] " .. name .. " (" .. (regex and "regex" or "fixed") .. "): "
end

---@param short_mode string
---@return boolean, string
local function pattern_visual_get(short_mode)
    local region = fn.getregion(fn.getpos("."), fn.getpos("v"), { type = short_mode })
    if #region == 1 then
        local trimmed = string.gsub(region[1], "^%s*(.-)%s*$", "%1")
        if #trimmed > 0 then
            return true, trimmed
        end
    else
        for _, line in ipairs(region) do
            if line ~= "" then
                return true, table.concat(region, "\n")
            end
        end
    end

    return false, "Empty selection"
end

---@param mode string
---@param name string
---@param regex boolean
---@return boolean, string, boolean
local function pattern_get(mode, name, regex)
    if require("nvim-tools.misc").is_vmode(mode) then
        local ok, err = pattern_visual_get(string.sub(mode, 1, 1))
        return ok, err, true
    else
        local ok, err = require("nvim-tools.ui").input({ prompt = prompt_resolve(name, regex) })
        return ok, err, false
    end
end

local M = {}

---@param src_win integer|nil Location list window context. Nil for qflist
---@param locations string[]
---@param name string
---@param regex boolean
---@param item_type ""|"\1"
---@param f fun(a:vim.quickfix.entry, b:vim.quickfix.entry): boolean
---@param cfg qf-herder.grep.Cfg
function M.rg(src_win, locations, name, regex, item_type, f, cfg)
    if src_win ~= nil and fn.getloclist(src_win, { id = 0 }).id == 0 then
        api.nvim_echo({ { QFR_NO_LL, "" } }, false, {})
        return
    end

    if #locations == 0 then
        api.nvim_echo({ { "No valid grep locations found", "ErrorMsg" } }, false, {})
        return
    end

    local ok_p, pattern, is_vmode = pattern_get(api.nvim_get_mode().mode, name, regex)
    if not (ok_p and #pattern > 0) then
        api.nvim_echo({ { pattern, "WarningMsg" } }, true, {})
        return
    end

    local grep_parts = get_full_parts_rg(pattern, cfg.case, regex, locations)
    local herder = require("qf-herder")
    local _, _, ok, sys_cfg, err = herder._config_merged_from_win(src_win or 0, "system")
    if not ok then
        api.nvim_echo({ { err, "ErrorMsg" } }, true, {})
    end

    local what = {}
    what.title = name .. " " .. table.concat(base_cmd, " ") .. "  " .. pattern
    local reuse_title = cfg.reuse_title
    local action, nr_set = _util.set_nr_resolve(reuse_title, src_win, what.title)
    what.nr = nr_set

    if is_vmode then
        api.nvim_cmd({ cmd = "norm", args = { "\27" }, bang = true }, {})
    end

    require("qf-herder._system").cmd_to_list(src_win, grep_parts, cfg.sync, what, {
        action = action,
        item_type = item_type,
        sort = f,
    }, sys_cfg)
end

return M

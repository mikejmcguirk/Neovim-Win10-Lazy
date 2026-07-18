local api = vim.api
local fn = vim.fn

local bit = require("bit")

local M = {}

local did_setup_repeat_tracking = false
local is_repeating = 0 ---@type 0|1

---@return 0|1
function M.get_is_repeating()
    return is_repeating
end

local has_ffi, ffi = pcall(require, "ffi")
local function setup_repeat_tracking()
    if did_setup_repeat_tracking then
        return
    end

    if has_ffi and ffi ~= nil then
        -- Dot repeats move their text from the repeat buffer to the stuff buffer for execution.
        -- When chars are processed from that buffer, the KeyStuffed global is set to 1.
        -- searchc in search.c checks this value for redoing state.
        if pcall(ffi.cdef, "int KeyStuffed;") then
            M.get_is_repeating = function()
                return ffi.C.KeyStuffed --[[@as 0|1]]
            end

            return
        end
    end

    -- Credit folke/flash
    vim.on_key(function(key)
        -- TODO: To allow the user to remap dot-repeat, config should accept a "dot_repeat_key"
        -- variable for this module to read.
        if key == "." and fn.reg_executing() == "" and fn.reg_recording() == "" then
            is_repeating = 1
            vim.schedule(function()
                is_repeating = 0
            end)
        end
    end)

    did_setup_repeat_tracking = true
end

---@param ns uinteger
---@param win uinteger
---@param group uinteger
---@param priority uinteger
---@param range [uinteger, uinteger, uinteger, uinteger]
---@param buf uinteger
function M.dim_set_ns_and_extmarks(ns, win, group, priority, range, buf)
    api.nvim__ns_set(ns, { wins = { win } })
    ---@type vim.api.keyset.set_extmark
    local extmark_opts = {
        hl_group = group,
        priority = priority,
        strict = false,
    }

    -- We go through the trouble of setting the dim highlights by line because Neovim does not
    -- consistently draw multi-line highlight extmarks only within namespace window scope.
    local start_row = range[1]
    local end_row = range[3]
    if start_row == end_row then
        extmark_opts.end_row = end_row
        extmark_opts.end_col = range[4]
        api.nvim_buf_set_extmark(buf, ns, start_row, range[2], extmark_opts)
        return
    end

    extmark_opts.end_row = end_row
    extmark_opts.end_col = range[4]
    api.nvim_buf_set_extmark(buf, ns, end_row, 0, extmark_opts)

    extmark_opts.hl_eol = true
    extmark_opts.end_row = nil
    extmark_opts.end_col = nil
    api.nvim_buf_set_extmark(buf, ns, start_row, range[2], extmark_opts)

    for i = start_row + 1, end_row - 1 do
        extmark_opts.end_row = i + 1
        api.nvim_buf_set_extmark(buf, ns, i, 0, extmark_opts)
    end
end

setup_repeat_tracking()

---@param win uinteger Assumes `win` is current win.
---@param buf uinteger
---@param dest_row uinteger 0 indexed
---@param dest_col uinteger 0 indexed
---@return uinteger, uinteger
function M.ensure_state_for_omode(win, buf, dest_row, dest_col)
    if not require("nvim-tools.misc").is_omode(api.nvim_get_mode().mode) then
        return dest_row, dest_col
    end

    local ntp = require("nvim-tools.pos")
    local cur_pos = ntp.mark_to_ext_pos(api.nvim_win_get_cursor(win))
    local cur_row = cur_pos[1]
    local cur_col = cur_pos[2]
    local cmp_res = ntp.cmp(cur_row, cur_col, dest_row, dest_col)

    local exclusive = api.nvim_get_option_value("sel", { scope = "global" }) == "exclusive"
    if exclusive and cmp_res < 1 then
        dest_col = ntp.utf_advance_col(buf, dest_row, dest_col)
    elseif (not exclusive) and cmp_res > -1 then
        local cur_col_back = ntp.utf_decrease_col(buf, cur_row, cur_col)
        cur_col_back = math.max(cur_col_back, 0)
        -- Avoid the window state updates nvim_win_set_cursor does
        fn.cursor(cur_row, cur_col_back)
    end

    api.nvim_cmd({ cmd = "norm", args = { "v" }, bang = true }, {})
    return dest_row, dest_col
end
-- TODO: Need to roll what we learned from csearch about noV mode into here, then also use this
-- in csearch.

-- stylua: ignore
-- Copied from Nvim source
-- Note that this is a one-indexed representation of zero-indexed data.
---@type integer[]
local utf8_len_tbl = {
    -- ?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9 ?A ?B ?C ?D ?E ?F
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 0?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 1?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 2?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 3?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 4?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 5?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 6?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 7?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 8?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 9?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- A?
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- B?
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  -- C?
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  -- D?
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,  -- E?
    4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 1, 1,  -- F?
}

---@param line string
---@param idx uinteger indexed
---@return uinteger, uinteger Codepoint and character length. Length is zero if the codepoint is
---invalid or if the codepoint would go past the end of the line.
function M.get_utf8_codepoint(line, idx)
    local b1 = string.byte(line, idx)
    if not b1 then
        return 0, 0
    end

    if b1 >= 0x80 and b1 < 0xC0 then
        return b1, 0
    end

    local len = utf8_len_tbl[b1 + 1] or 1
    if len == 1 then
        return b1, 1
    end

    if len > 4 or idx + len - 1 > #line then
        return b1, 0
    end

    local b2 = string.byte(line, idx + 1)
    if bit.band(b2, 0xC0) ~= 0x80 then
        return b1, 0
    end

    if len == 2 then
        return bit.lshift(b1 - 0xC0, 6) + (b2 - 0x80), 2
    end

    local b3 = string.byte(line, idx + 2)
    if bit.band(b3, 0xC0) ~= 0x80 then
        return b1, 0
    end

    if len == 3 then
        return bit.lshift(b1 - 0xE0, 12) + bit.lshift(b2 - 0x80, 6) + (b3 - 0x80), 3
    end

    local b4 = string.byte(line, idx + 3)
    if bit.band(b4, 0xC0) ~= 0x80 then
        return b1, 0
    end

    return bit.lshift(b1 - 0xF0, 18)
        + bit.lshift(b2 - 0x80, 12)
        + bit.lshift(b3 - 0x80, 6)
        + (b4 - 0x80),
        4
end

return M

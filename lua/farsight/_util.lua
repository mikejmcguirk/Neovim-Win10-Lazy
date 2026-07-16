local api = vim.api
local fn = vim.fn

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
-- TODO: Should also be able to use for csearch
-- TODO: Unsure about the backward omode behavior. Happens in visual mode (undesired) and is not
-- useful. Would need to shift fwd exclusive selections to match.

return M

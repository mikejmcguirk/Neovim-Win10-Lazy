local api = vim.api
local fn = vim.fn

local M = {}

local has_ffi, ffi = pcall(require, "ffi")

local did_setup_repeat_tracking = false
local is_repeating = 0 ---@type 0|1

function M.get_is_repeating()
    return is_repeating
end

function M.setup_repeat_tracking()
    if did_setup_repeat_tracking then
        return
    end

    if has_ffi then
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
        if key == "." and fn.reg_executing() == "" and fn.reg_recording() == "" then
            is_repeating = 1
            vim.schedule(function()
                is_repeating = 0
            end)
        end
    end)

    did_setup_repeat_tracking = true
end

-- MAYBE: If another module uses this info, setup a var so it isn't run twice

function M.has_ffi_search_tracking()
    if not has_ffi then
        return false
    end

    local cdef_ok = pcall(
        ffi.cdef,
        [[
            extern int search_match_endcol;
            extern int search_match_lines;
        ]]
    )

    if not cdef_ok then
        return false
    end

    local access_ok = pcall(function()
        local _ = ffi.C.search_match_endcol
        local _ = ffi.C.search_match_lines
    end)

    if not access_ok then
        return false
    end

    return true
end

-- TODO: Use this in all modules

---@param win integer
---@param buf integer
---@param wS integer
---@return integer, boolean Adjusted row, redraw valid
function M.get_wrap_checked_bot_row(win, buf, wS)
    if api.nvim_get_option_value("wrap", { win = win }) then
        if wS < api.nvim_buf_line_count(buf) then
            local fill_row = wS + 1
            if fn.screenpos(win, fill_row, 1).row >= 1 then
                return fill_row, false
            end
        end
    end

    return wS, true
end

return M

-- TODO: This module can be useful for outlining pieces of logic common to csearch, search, and
-- jump. Wait though until all three modules are completed before doing such a conceptual refactor.
-- Ideas:
-- - The backward cursor correction + visual entrance for omode jumps. If/when it's outlined, put
-- a comment talking about how the use of that code assumes that we have already early-exited from
-- invalid backward jumps.

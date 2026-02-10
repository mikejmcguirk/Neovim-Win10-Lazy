local api = vim.api
local fn = vim.fn

local M = {}

---@param cur_pos { [1]: integer, [2]: integer }
---@param buf integer
local function get_backward_skip_pos(cur_pos, buf)
    local cur_row = cur_pos[1]
    local cur_col = cur_pos[2]
    local cur_line = api.nvim_buf_get_lines(buf, cur_row - 1, cur_row, false)[1]
    local cur_charidx = fn.charidx(cur_line, cur_col)
    if cur_charidx > 0 then
        local prev_byteidx = fn.byteidx(cur_line, cur_charidx - 1)
        return cur_row, prev_byteidx
    end

    local prev_row = math.max(cur_row - 1, 1)
    if prev_row == cur_row then
        return cur_row, 0
    end

    local prev_line = api.nvim_buf_get_lines(buf, prev_row - 1, prev_row, false)[1]
    -- FUTURE: https://github.com/neovim/neovim/pull/37737
    local prev_last_charidx = fn.strcharlen(prev_line) - 1 ---@type integer
    local prev_last_byteidx = fn.byteidx(prev_line, prev_last_charidx)
    return prev_row, prev_last_byteidx
end

---@class farsight._common.DoJumpOpts
---@field keepjumps boolean
---@field on_jump fun(win: integer, buf: integer, jump_pos: { [1]:integer, [2]: integer })

---@param cur_win integer
---@param jump_win integer
---@param buf integer
---@param map_mode "n"|"v"|"o"|"l"|"t"|"x"|"s"|"i"|"c"
---@param cur_pos { [1]: integer, [2]: integer }
---@param jump_pos { [1]: integer, [2]: integer }
---@param opts farsight._common.DoJumpOpts
function M._do_jump(cur_win, jump_win, buf, map_mode, cur_pos, jump_pos, opts)
    if cur_win ~= jump_win then
        api.nvim_set_current_win(jump_win)
        -- AFAIK, changing windows in non-normal modes changes the mode to normal. I'm also not
        -- sure why a window switching jump would be mapped in a non-normal mode to begin with.
        -- This seems like the simplest way to avoid selection/mode adjustments in goofy edge
        -- cases. Can update if a use case comes up
        map_mode = "n"
    end

    -- Because jumplists are scoped per window, setting the pcmark in the window being left doesn't
    -- provide anything useful. By setting the pcmark in the window where the jump is performed,
    -- the user is provided the ability to undo the jump
    if (not opts.keepjumps) and map_mode ~= "o" then
        -- FUTURE: When the updated mark API is released, see if that can be used to set the
        -- pcmark correctly
        api.nvim_cmd({ cmd = "norm", args = { "m`" }, bang = true }, {})
    end

    local is_vo_mode = map_mode == "v" or map_mode == "o"
    local is_exclusive = vim.o.selection == "exclusive"
    local jump_row = jump_pos[1]
    local jump_col = jump_pos[2]
    -- TODO: I don't love how this is handled, because then you still need to graft a fix onto
    -- the forward exclusive case
    -- Underlying issue - No clear sense of how csearch handles not finding or not being able
    -- to find a match, resulting in the cursor not moving. Do we just early exit? Or do we
    -- still run through the jump logic?
    -- Same with a visual selected full jump
    -- Perhaps a simple boolean is not the best data type? Maybe -1, 0, 1
    local is_forward = (function()
        if jump_row > cur_pos[1] then
            return true
        end

        -- If the cursor does not move, do not apply backwards cursor correction
        return jump_col >= cur_pos[2]
    end)()

    if is_vo_mode and is_exclusive and is_forward then
        local line = api.nvim_buf_get_lines(buf, jump_row - 1, jump_row, false)[1]
        -- Exclusive selection can go one past the line boundary
        jump_pos[2] = math.min(jump_col + 1, math.max(#line, 0))
    end

    if map_mode == "o" then
        if not (is_exclusive or is_forward) then
            local prev_row, prev_col = get_backward_skip_pos(cur_pos, buf)
            api.nvim_win_set_cursor(jump_win, { prev_row, prev_col })
        end

        -- Use visual mode so that all text within the selection is operated on, rather than just
        -- the text between the start and end of the cursor movement.
        api.nvim_cmd({ cmd = "norm", args = { "v" }, bang = true }, {})
    end

    api.nvim_win_set_cursor(jump_win, jump_pos)
    local on_jump = opts.on_jump
    if on_jump then
        on_jump(jump_win, buf, jump_pos)
    end
end

return M

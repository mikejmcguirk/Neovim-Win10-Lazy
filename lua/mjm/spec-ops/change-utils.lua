local set_utils = require("mjm.spec-ops.set-utils")
local op_utils = require("mjm.spec-ops.op-utils")

local M = {}

-- TODO: move this to op_state
-- - For chars, it looks like you can just do the del_chars one and use its marks
-- - But want to think more strategically before making any moves, because the insert_after
--   function in the current implementation is ghastly
-- - For lines, it looks, again, like you can just do a set
-- - The idea I think is that if you delete to the end of the line you want to go after, or else
--   you're going to be before the trailing whitespace
-- - I think the simpler way of doing this is you look and see if the mark is at the end of a line
-- - For char deletes, I think you just do marks.start.col both ways, and you check for max with
-- the line, then if you're at the end you go after. Seems simple ehough
-- For lines it's using a set, so we eliminate all the text what puts the cursor right at the
-- beginning, then the current logic (correctly) does S or cc to start properly indented
-- In both cases, I think we should start with individualized functions to control where
-- the marks are, but these should generalize out like they are now
-- For blocks, it gets weirder
-- In the change case, we can assume that we are always targeting a rectangle, which eliminates
-- some complication. We can also assume that we are using the delete method of picking cols to
-- remove. The start mark should be basically where it is on delete block, but, for specificity -
-- the start mark should end up on start row and start col. They can't "slide back" because they
-- already started on a beginning. I suppose a bad motion or manual mark edit could do that, but
-- I'm not interested in accomodating that. It would break the defaults too so, yeah
-- (though, if you wanted to be really safe, for each mark, at the beginning, you could check
-- the byte bounds and shift them to the starting bytes. Unlike finding a vcol, this doesn't
-- introduce a ton of time complexty, at least in the Lua)
-- But what I still don't have a good grasp on is how the marks handle ragged edges
-- Rather than the stepping through I'm doing right now, the simpler/more accurate way to do this
-- seems to be, you set the top mark like you would in a delete, then attempt to set the bottom
-- mark like you would in a delete. If the bottom mark can't go far enough to the right, then
-- you use that as the point to shift the top mark
-- This is a broader note for block boundaries that probably applies to zp as well, but you get
-- a top right mark when you have a block selection where it goes further out on a ragged edge
-- and that ragged edge is on top, but then you need the bottom mark to represent the block's
-- left boundary
-- This is more of a zp-point, but in terms of when curswant matters, say you have four lines.
-- Line one is the second longest, line four is the longest. If you $ to the end of line one and
-- select to line three, the topleft mark will show the left boundary, the bottom right mark
-- will be as far to the right as possible on line three, and then you'll need curswant to fill
-- in the remainder of the selection. If you gv this selection, you'll go to the botright mark and
-- be able to go to the end of line four by pressing j, because curswant wants to go there
-- Whereas if you start the block selection from the end of line one then create the same
-- selection, the topright mark will be at the end of line one and the botleft mark will be at
-- the start of the selection on line three. When you gv, you'll end up at the bottom mark
-- as before, but on the left, indicating that if you press j to go down to line four, the
-- selection will only extend as far to the right as the end of line one
-- When I start at a shorter line then introduce long ones, I don't see a different in the mark
-- pattern. Top left and bottom right, and curswant tells you if it fills out the hwole line or not
-- And then I notice that when actually doing the zp, the marks just go at the top left and then
-- the bottom right of the last line, both in normal and visual mode. tbf this removes a huge
-- coplication from the process so it's somewhat welcome
-- Something interesting to consider then is - if the right mark on a block selection = the
-- end of the line, do you need to check curswant? kinda. It can make a block selection that
-- gets the proper bounds without it, but then it relies on curswant to check behavior as you
-- grow the selection. My intuition is that it's probably better to just check it under the
-- necessary conditions, lest some edge case float by. Can be made a note to maybe, someday,
-- possibly check how the marks are made to see if their placements can be reverse deducted to see
-- if you need to check curswant
-- So then the move I think is to get the functions down without insert mode first, so we can
-- check how the marks go, then we can add the insert mode selections/checking

--- @param op_state op_state
--- @return string|nil
--- This function assumes that start_row <= fin_row is already verified
local function op_state_del_chars(op_state)
    local start_row = op_state.post.marks.start.row
    local start_col = op_state.post.marks.start.col
    local fin_row = op_state.post.marks.fin.row
    local fin_col = op_state.post.marks.fin.col

    local fin_line = vim.api.nvim_buf_get_lines(0, fin_row - 1, fin_row, false)[1]

    --- @type integer|nil, integer|nil, string|nil
    local _, fin_byte, err = blk_utils.byte_bounds_from_col(fin_line, fin_col)
    if (not fin_byte) or err then
        return "del_chars: " .. (err or "Unknown error in byte_bounds_from_col")
    end
    fin_byte = #fin_line > 0 and fin_byte + 1 or 0

    vim.api.nvim_buf_set_text(0, start_row - 1, start_col, fin_row - 1, fin_byte, {})

    start_row = math.min(start_row, vim.api.nvim_buf_line_count(0))
    vim.api.nvim_buf_set_mark(0, "[", start_row, start_col, {})
    vim.api.nvim_buf_set_mark(0, "]", start_row, start_col, {})

    op_state.post.marks_after = {
        start = { row = start_row, col = start_col },
        fin = { row = start_row, col = start_col },
    }

    return nil
end

-- TODO: A smaller and a bigger thought in here
-- The smaller thought: For any exposed functions, there simply must be validation of the
-- incoming data. It adds execution time, but we cannot make assumptions about the incoming data
-- The bigger thought relates to error handling. One change we've made that's been good is to
-- implement fallback behavior where possible. This makes errors harder to track in theory,
-- but in practice provides a smoother experience and makes the code easier to maintain. Could
-- maybe be more willing to return more errors once extui is actually live. I'm also wondering
-- about the error handling in general. On one hand, the errors I have are extremely useful
-- for debugging weird things like bad column transformations. On the other, it makes the code
-- much less ergonomic to work with. Especially in this case, where we are editing op_state
-- in place but then we have to return an error value for checking.

function M.op_state_do_change(op_state)
    if not op_state.post.marks then
        op_state.post.lines = nil
        return "do_change: No marks in op_state"
    end

    local start_row = op_state.post.marks.start.row
    local start_col = op_state.post.marks.start.col
    local fin_row = op_state.post.marks.fin.row

    if start_row > fin_row then
        local row_0 = start_row - 1
        op_state.post.lines = vim.api.nvim_buf_get_text(0, row_0, start_col, row_0, start_col, {})
        return nil
    end

    op_state.post.motion = op_state.post.motion or "char"

    if op_state.post.motion == "line" then
        return del_lines(op_state)
    elseif op_state.post.motion == "block" then
        return del_block(op_state)
    else
        return op_state_del_chars(op_state)
    end
end

--- @return op_marks|nil, string|nil
function M.do_change(opts)
    opts = opts or {}

    if not opts.marks then
        return nil, "do_get: No marks to get from"
    end

    opts.motion = opts.motion or "char"
    opts.curswant = opts.curswant or vim.fn.winsaveview().curswant
    if opts.motion == "char" then
        return op_utils.del_chars(opts.marks)
    elseif opts.motion == "line" then
        return set_utils.op_set_lines(opts.marks, { "" })
    else
        return op_utils.op_set_block(opts.marks, opts.curswant, { is_change = true })
    end
end

return M

-- autocmd to know if we have incremented
-- TODO: Do we add the ability to change motions?

local op_utils = require("mjm.spec-ops.op-utils")
local paste_utils = require("mjm.spec-ops.paste-utils")
local set_utils = require("mjm.spec-ops.set-utils")

local M = {}

local cyc_motion = nil --- @type string
local cyc_marks = nil --- @type op_marks
local cyc_vmode = false --- @type boolean
local cyc_reges = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }
local cyc_reges_orig = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }
local cyc_index = 1
-- local cyc_text = ""
local cyc_buf = 0
local cyc_win = 0
local cyc_before = false
local cyc_vcount = 1
local cyc_curswant = 0

-- TODO: WIth all the state to take in, might it be possible to tie this to the operator state?
function M.ingest_state(motion, reg, marks, vmode, buf, win, before, vcount, curswant)
    cyc_motion = motion
    cyc_marks = marks
    cyc_vmode = vmode

    cyc_reges = vim.deepcopy(cyc_reges_orig, true)
    if not vim.tbl_contains(cyc_reges, reg) then
        table.insert(cyc_reges, 1, reg)
    end
    cyc_buf = buf
    cyc_win = win
    cyc_index = 1

    -- cyc_text = text
    cyc_before = before
    cyc_vcount = vcount

    cyc_curswant = curswant
end

-- TODO: For this to work, we need the old lines so they can be manually restored
-- This means that the paste function(s) need to be able to calculate how many lines
-- will be changed and therefore how many to save
-- This means that the paste functions need to be refactored. The norm paste needs to take in
-- lines, not text
-- We also need to refactor the paste functions so they can be called from anywhere, as we
-- don't want to be duplicating logic
-- This is probably also an opportunity to get rid of the specialized paste lines function, and
-- some other junk

-- TODO: Maybe should merge this in with the main paste logic. You can have an op callback to
-- take in the motion then call a common subfunction with this one. Feels unnecessary to
-- duplicate the paste logic here
function M.cycle(forward)
    -- TODO: This might actually just be fine because I'm not sure if it's good to be able to do
    -- the cycle outside the window it was done in
    if vim.api.nvim_get_current_buf() ~= cyc_buf then
        return
    end

    if vim.api.nvim_get_current_win() ~= cyc_win then
        return
    end

    -- TODO: Handle wrap
    if not cyc_index then
        cyc_index = 1
    elseif forward then
        cyc_index = cyc_index + 1
        if cyc_index > #cyc_reges then
            vim.notify("at the end")
            cyc_index = #cyc_reges
            return
        end
    else
        cyc_index = cyc_index - 1
        if cyc_index < 1 then
            vim.notify("at the end")
            cyc_index = #cyc_reges
            return
        end
    end

    local this_reg = cyc_reges[cyc_index]

    local text = vim.fn.getreg(this_reg)
    if (not text) or text == "" then
        return vim.notify(this_reg .. " register is empty", vim.log.levels.INFO)
    end

    vim.cmd("silent norm! u")
    local regtype = vim.fn.getregtype(this_reg)
    local cur_pos = { cyc_marks.start.row, cyc_marks.start.row }
    -- vim.api.nvim_win_set_cursor(0, cur_pos)

    -- TODO: Seeing a bit of a practgical problem with pushing so much of the state transformation
    -- into the util - It makes it inflexible to use because we can't hit it from a later
    -- point in the process.
    local post_marks, err
    if cyc_vmode then
        local lines = op_utils.setup_text_lines({
            text = text,
            motion = cyc_motion,
            regtype = regtype,
            vcount = cyc_vcount,
        })

        --- @type op_marks|nil, string|nil
        post_marks, err = set_utils.do_set(lines, cyc_marks, regtype, cyc_motion, cyc_curswant)
    else
        post_marks, err = paste_utils.do_paste({
            regtype = regtype,
            cur_pos = cur_pos,
            before = cyc_before,
            text = text,
            vcount = cyc_vcount,
        })
    end

    if (not post_marks) or err then
        return "paste_norm: " .. (err or ("Unknown error in " .. regtype .. " paste"))
    end

    -- TODO: handle indenting
    -- TODO: Handle cursor adjustment
    -- TODO: How do we hwndle yanks if cycling on a visual yank/paste
end

-- vim.keymap.set("n", "[y", function()
--     M.cycle()
-- end)
--
-- vim.keymap.set("n", "]y", function()
--     M.cycle(true)
-- end)

return M

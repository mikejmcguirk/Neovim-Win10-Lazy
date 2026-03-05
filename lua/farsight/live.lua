local api = vim.api
local fn = vim.fn

local HL_LIVE_STR = "FarsightLiveJump"
local HL_LIVE_AHEAD_STR = "FarsightLiveJumpAhead"
local HL_LIVE_TARGET_STR = "FarsightLiveJumpTarget"
local HL_LIVE_DIM_STR = "FarsightLiveJumpDim"

api.nvim_set_hl(0, HL_LIVE_STR, { default = true, link = "DiffChange" })
api.nvim_set_hl(0, HL_LIVE_AHEAD_STR, { default = true, link = "DiffText" })
api.nvim_set_hl(0, HL_LIVE_TARGET_STR, { default = true, link = "DiffAdd" })
api.nvim_set_hl(0, HL_LIVE_DIM_STR, { default = true, link = "Comment" })

local nvim_get_hl_id_by_name = api.nvim_get_hl_id_by_name
local hl_next = nvim_get_hl_id_by_name(HL_LIVE_STR)
local hl_ahead = nvim_get_hl_id_by_name(HL_LIVE_AHEAD_STR)
local hl_last = nvim_get_hl_id_by_name(HL_LIVE_TARGET_STR)
local hl_dim = nvim_get_hl_id_by_name(HL_LIVE_DIM_STR)

-- Prefer home row, then top, then bottom.
-- Prefer index/middle fingers.
-- Index prefers to go down. Middle and ring prefer to go up.
-- Prefer right hand due to keyboard slope.
-- Because tokens will be filtered based on chars after, prefer ergonomics over memorizable
-- ordering.
-- To avoid over-subjectivity, group finger/row combinations. Put all shift keys after.
local tokens = vim.split("kdjflsaieowghmvtnurybpqcxzKDJFLSAIEOWGHMVTNURYBPQCXZ", "")

-- local namespaces = { api.nvim_create_namespace("") } ---@type integer[]

-- TODO: Because it should be possible to live jump over multiple windows, we will eventually need
-- the namespace list
local test_ns = api.nvim_create_namespace("test-ns")

local last_targets = nil ---@type farsight.targets.Targets|nil

local function handle_input(win, buf, cache, cursor)
    -- TODO: Check prompt as well
    local cmd_type = vim.fn.getcmdtype()
    if cmd_type ~= "@" then
        return
    end

    api.nvim_buf_clear_namespace(0, test_ns, 0, -1)
    local pattern = vim.fn.getcmdline()
    if pattern == "" then
        return
    end

    local locator = require("farsight._locator")
    local ok, targets, err_hl = locator.search(win, pattern, cursor, cache, {
        alloc_size = 64,
        allow_folds = "none",
        allow_intersect = false,
        start_row = cursor[2],
        start_col = cursor[3],
        stop_row = vim.call("line", "$"),
        stop_col = 1,
        timeout = 500,
    })

    vim.fn.confirm(vim.inspect(targets))
    if not ok or type(targets) == "string" then
        return
    end

    if targets:get_len() < 1 then
        api.nvim_buf_clear_namespace(0, test_ns, 0, -1)
        return
    end

    local labeler = require("farsight._labeler")
    local filled_labels = labeler.fill_labels({ win }, { [win] = targets }, tokens, cache, {
        allow_partial = true,
        cursor = cursor,
        filter_next = true,
        locations = "finish",
        max_tokens = 1,
        is_upward = false,
    })

    if not filled_labels then
        return
    end

    local filled_vtext = labeler.fill_virt_text(targets, 1, 1, {
        hl_next = hl_next,
        hl_ahead = hl_ahead,
        hl_last = hl_last,
        locations = "finish",
    })

    if not filled_vtext then
        return
    end

    labeler.set_target_extmarks(buf, test_ns, targets, {
        locations = "finish",
    })

    last_targets = targets
    api.nvim__redraw({ valid = true, win = win })

    -- api.nvim_feedkeys("\27", "nt", false)
    -- api.nvim_input("\27")
end
-- TODO: The various ctx tables should be generated once at the start and then kept around so
-- they don't have to be re-calculated and re-allocated each keystroke.

-- TODO: Needs to handle multi-win
local function create_input_handler(win, buf)
    local cache = {}
    cache[buf] = {}
    local cursor = fn.getcurpos(win)

    local augroup = api.nvim_create_augroup("farsight-live", {})
    api.nvim_create_autocmd({ "CmdlineChanged" }, {
        group = augroup,
        callback = function()
            handle_input(win, buf, cache, cursor)
        end,
    })

    api.nvim_create_autocmd("CmdlineLeave", {
        group = augroup,
        callback = function()
            -- TODO: See if it's possible for this to only be here.
            api.nvim_buf_clear_namespace(0, test_ns, 0, -1)
            api.nvim_del_augroup_by_id(augroup)
        end,
    })
end

local M = {}

function M.live_jump()
    -- TODO: All of this needs to be able to handle multi-window
    local cur_win = api.nvim_get_current_win()
    api.nvim__ns_set(test_ns, { wins = { cur_win } })
    local win_buf = api.nvim_win_get_buf(cur_win)
    create_input_handler(cur_win, win_buf)

    local ok, err = pcall(vim.call, "input", "YUMP: ")
    if ok then
        api.nvim_echo({ { "" } }, false, {}) -- LOW: Is there a less blunt way to handle this?
    end
end

return M

-- TODO: For any option, make sure it mirrors the underlying data as much as possible.
-- OPTIONS:
-- - Autojump if only one result
--   - Apparently in Lightspeed this is impossible in multi-win. Should be fine here because of
--   how win_targets is done.
-- - Result jump. end, beginning, cursor aware
--   - Should be beginning in normal. Maybe cursor aware in vmode and omode
-- - Show search highlighting?
--   - Default on
-- - Minimum characters before jumping/labeling. Could help to avoid business/unexpected movements.
-- Could also help with perf only slower systems
-- - Prompt
-- - dim
-- - keepjumps
-- - discard folds
-- - open folds on jump? (default fdo on jump)
-- - timeout
-- - prepend (So you can map something like "\%V")
--   - The prompt display should include the prepend
-- - on_jump
-- - dir
--   - -1, 0, 1 - 0 is whole window
--   - If dir ~= 0 and multi-window, other windows should all be 0
--   - If dir == -1 and multi-window, try to make other windows go in reverse order
--   - Win ordering is important here for multi-window, as well as dimming properly
-- - omode behavior: Always ask for a label, or use the last search to find x labels ahead in the
-- last direction. Multi-window searches go to the last result. If dir is zero, the last actual
-- direction is used.
--
-- CONCEPTUAL QUESTIONS
--
-- TODO: Do you do something similar here to f/t where, after a jump, you can use ;/, to iterate
-- between other instances of the each result? I think not.
--
-- TODO: In targets, remove the rev idxs table (handle by improved iterators) and nil out extra
-- results. Reasons:
-- - These create more opportunities for subtle errors to occur
-- - These make debugging harder
-- - It makes the underlying assumptions about the data structure more clear
-- - It makes updating the data structure simpler (though not necessarily easier) because you don't
-- have to navigate around the junk state
-- - Downside: By nilling fields this potentially triggers more garbage collection. I don't know if
-- this can be turned off.
-- - Document all of this, since I sometimes later forget my reasoning for why certain things were
-- done.
-- TODO: For folds, flash's method of adding one label at the start of a fold basically makes
-- sense. So in our fold filtering, we want to assume that, for any fold block, we are only taking
-- one candidate per fold. The question then is what are the criteria. The fold option, "all" or
-- "first_row" describes the scope of the candidates. For a downward search, we very plainly want
-- to take the first candidate in the fold. I also think this is most logical for upward searches.
-- We are assuming the default is first_row, in which case, the earlier the entry, the more likely
-- it is to be visible in the fold text.
-- Obvious but important detail - Set the column of the label to 0.
-- TODO: Enter should take you to the closest search.
-- TODO: Don't do the echo errors flag. Just print rational messages
-- TODO: The debug flag is, IMO, a complexity add. We need to be okay with internal validation.
-- It's helped us out before.
-- TODO: Should the search highlighting be settable or follow Search?
-- - It should link to Search by default, but be configurable.
-- TODO: Dim the search area, not the results. Applies to all modules. Will requires separate ns.
-- TODO: Document that smartcase/ignorecase are disallowed from searching.
-- TODO: Find a good custom prompt. Probably fine to just use a nerd font character. It's fine if
-- the fallback is nothing.
-- TODO: Should a multi-window <Plug> mapping be provided, even if it isn't configured as a
-- default?
-- TODO: The highlighting definitely needs to be generalized with static search, and should be
-- generalized as much as possible with csearch
-- TODO: Results with overlapping ends are possible and need to be filtered. Probably prefer the
-- first one
-- TODO: Labels should not work if the cursor is not in the last position of the prompt. This
-- behavior should be documented. Perhaps less confusing, just leave the prompt lash flag does
-- if the autocmd sees the cursor not in the last position. Maybe set it as an opt. Some solution
-- needs to be found because changing a character other than the last one produces incorrect
-- behavior. Though, perhaps, maybe, you could save the old pattern and compare that as well.
-- TODO: Labels should not work if the last character is an un-escaped \
-- TODO: Display an extmark at the cursor position. What is a sensible default if it's not set?
-- How do you make it emulate reverse video cursor/detect if that's set?
--
-- MID: Verify that builtin search timeout is half a second.
-- MID: When does input() return vim.NIL?
-- MID: Lightspeed has a cool feature where, for autojumping, it will highlight unique characters,
-- and update them based on the current search. Tabling though because this would require rewriting
-- the labing algorithm.
-- MID: A good optimization for search highlighting is to merge together continguous/overlapping
-- searches. While this requires an array traversal, this saves time setting and rendering
-- extmarks. Difficult though because this is a destructive operation on the targets, so the
-- necessary data for the next keystroke would need to be copied. I'm not sure what the principled
-- way to do this is, and that question doesn't need to be solved right now.
-- I would also roll this into a broader question of how to optimize search result display, and
-- include eliminating fold rows from the extmark setting. This is probably an additional
-- sub-table in targets to set the fold flag, but worth it to avoid re-querying those rows.
-- MID: Respect winhighlight
-- MID: An optimization worth exploring is putting all the targets in the same table, having a
-- sub-list with the winIDs, and having another sub-list to track the count of targets per winID.
-- When it came to performing redraws, you could then check targets to see which windows were still
-- valid. The advantage here is that, while this would use more RAM, it would centralize the data
-- and possibly make multi-window jumps more efficient. (Counterpoint - this would require
-- adding win, buf, and ns to targets, which might non-trivially eat up cache). Another
-- counterpoint is the risk of repeating the pain of the centralized valid data saga. Not a
-- showstopper for release.
--
-- NON: It would be vaguely interesting to print multi-char labels that let you jump off into a
-- static jump, but I think that would just create feature confusion.

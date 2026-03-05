vim.g.farsight_debug = true
-- TODO: Document highlight groups here
-- TODO: Document g:vars here. Check validations

-- TODO: Create checkhealth
-- - Nvim version
-- - g:var validity checks
-- - maparg success

local api = vim.api
local fn = vim.fn

local plugs = {
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-Jump)",
        function()
            require("farsight.jump").jump({})
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchF-Forward)",
        function()
            require("farsight.csearch").csearch({})
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchF-Reverse)",
        function()
            require("farsight.csearch").csearch({ forward = 0 })
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchT-Forward)",
        function()
            require("farsight.csearch").csearch({ ["until"] = 1 })
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchT-Reverse)",
        function()
            require("farsight.csearch").csearch({ forward = 0, ["until"] = 1 })
        end,
    },
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchRep-Forward)",
        function()
            require("farsight.csearch").rep({})
        end,
    },
    -- TODO: Should reverse also be used as the naming convention for the plugs?
    {
        { "n", "x", "o" },
        "<Plug>(Farsight-CsearchRep-Reverse)",
        function()
            require("farsight.csearch").rep({ forward = 0 })
        end,
    },
}

local len_plugs = #plugs
for i = 1, len_plugs do
    local plug = plugs[i]
    local modes = plug[1]
    local key = plug[2]
    local callback = plug[3]
    local len_modes = #modes
    for j = 1, len_modes do
        api.nvim_set_keymap(modes[j], key, "", { noremap = true, callback = callback })
    end
end

-- TODO: Loop up the mappings
-- TODO: I don't love the Csearch plug names
-- TODO: Need omode mappings for csearch. But need to add visual selection for it
-- Also note that the alternative actions should not be present

if vim.g.farsight_default_maps == false then
    return
end

---@type { [1]: string[], [2]: string, [3]: string }[]
local jump_maps = {
    { { "n", "x", "o" }, "<cr>", "<Plug>(Farsight-Jump)" },
}

for i = 1, #jump_maps do
    local map = jump_maps[i]
    local modes = map[1]
    local key = map[2]
    local rhs = map[3]
    for j = 1, #modes do
        local mode = modes[j]
        local maparg_res = fn.maparg(key, mode)
        -- Need to check for just <cr> because of unsimplification (:h <tab>)
        if maparg_res == "" or string.lower(maparg_res) == key then
            api.nvim_set_keymap(mode, key, rhs, { noremap = true })
        end
    end
end

---@type { [1]: string[], [2]: string, [3]: string }[]
local csearch_maps = {
    { { "n", "x", "o" }, "f", "<Plug>(Farsight-CsearchF-Forward)" },
    { { "n", "x", "o" }, "F", "<Plug>(Farsight-CsearchF-Reverse)" },
    { { "n", "x", "o" }, "t", "<Plug>(Farsight-CsearchT-Forward)" },
    { { "n", "x", "o" }, "T", "<Plug>(Farsight-CsearchT-Reverse)" },
    { { "n", "x", "o" }, ";", "<Plug>(Farsight-CsearchRep-Forward)" },
    { { "n", "x", "o" }, ",", "<Plug>(Farsight-CsearchRep-Reverse)" },
}

for i = 1, #csearch_maps do
    local map = csearch_maps[i]
    local modes = map[1]
    local key = map[2]
    local rhs = map[3]
    for j = 1, #modes do
        local mode = modes[j]
        if fn.maparg(key, mode) == "" then
            api.nvim_set_keymap(mode, key, rhs, { noremap = true })
        end
    end
end

-- Profiling code:
-- local start_time = vim.uv.hrtime()
-- local end_time = vim.uv.hrtime()
-- local duration_ms = (end_time - start_time) / 1e6
-- print(string.format("hl_forward took %.2f ms", duration_ms))

-- NOTE: Internal function locations:
-- - cursor() : f_cursor in funcs.c
-- - line() : f_line in funcs.c
-- - col() : f_col in funcs.c
-- - search() : f_search in funcs.c

-- TODO: I think "nomap_ft", "nomap_live", and "nomap_static" options are fine. We presume that
-- "nomap_all" overrides any of them.
-- TODO: I believe the manual isk checking will be completely obsoleted from this plugin. I think
-- that code, along with the various other components in here and in rancher, justify creating an
-- nvim-tools repo. Each module should have an error message at the top of it so it cannot be
-- required. We do not want to create a new plenary.
-- TODO: Note mainly for jumping and csearch:
-- - \k matches individual characters
-- - \<\k\+\> ensures word boundaries are respected
-- - \k\+ looks for runs but does not respect word boundaries
-- Feels better to use the word boundary one so that way static jump uses proper boundaries when
-- creating labels
-- TODO: Look at how stevearc/folke do their docgen. Manually keeping up the README has been a
-- major pain point with Rancher and even lampshade.
-- TODO: Config points: Overall, csearch, live search, static search
-- TODO: I *think* I want to ship a static jump as default on enter. Show all three features.
-- - That said, for posterity, do explore a live jump on multiple windows as a default. Test in
-- dense code windows. My question is if there are too many results for labels to reliably spawn
-- after a small number of keypresses.
-- - For static jump, IMO labels at beginning only is the sanest default, but test "both" as well.
-- TODO: See if dim rows in csearch and jump can be handled like in search
-- TODO: For any jumps, if doing a backwards correction for omode, use cursor() instead of the API
-- because it doesn't trigger a screen update.
-- - Or is this based on search() now? Haven't looked at that code in a while.
-- TODO: Functionalities to try putting into common
-- - Dimming. Could have a function that takes a row list, ns, and hl_group and runs through
-- setting the extmarks. Also have it take a dim opt
-- - At least some of the logic for getting the wrapped bottom row. It's all checking the opt
-- and searchpos on the first col.
-- TODO: Replace vim.fn with vim.call where possible
-- TODO: Confirm that g/b:vars can take function literals. I've seen it work, but does it break?
-- TODO: Where can we use require("table.new")?
-- TODO: Document that, in all cases, |cpo-c| is respected. Sub-note though that the default
-- jump pattern explicitly uses word boundaries to avoid overlaps
-- TODO: The various functions should have hard protections against multi-win if not in normal mode
-- TODO: Document deprecation plan:
-- - Time period: 2-3 months
-- - Opt/function removal: Mark private/package, then delete
-- - Function signature change: Use a shim that routes the old interface, then delete the shim and
-- old interface
-- - Default function behaviors: Notify which opt lets you use old behavior
-- - Plug map changes: Unsure
-- TODO_DOC: b:vars are the same as g:vars and prioritized. Can be used for ft configurations
-- TODO: Test everything with and around multibyte chars. It doesn't look like anything special
-- needs to be done, but need to be sure
-- TODO: Need to test that the gb options work
-- TODO: Jokes:
-- - "Extraterrestrial vantage point over your code"
-- - "You'll move through your code so quickly, people won't be sure your movement was real"
-- - "See through walls with jump" (Direct Farsight reference)
-- - "Even the best researchers at Area 51 won't be able to understand your speed"
-- TODO: Re-check that farsight name is available
-- TODO: README:
-- - Credits:
--   - jump2d (initial basis for jump)
--   - flash/lightspeed/leap (for the incremental jump idea)
-- - Inspirations:
--   - Quickscope
-- - Alternatives:
--   - vim-sneak
--   - hop
--   - EasyMotion
--   - { Flash lists a lot of them }
-- - TODO: Create docgen
-- - TODO: Go through the opts of the various functions and document the g:variable overrides

-- TODO_DOC: I don't know how much of this is internal vs. user-facing documentation, but - The
-- general attitude toward any Puc Lua compatibility function should be: It should handle typical
-- cases, and effort might be made to support edge cases, but the design of the overal module
-- cannot be compromised to handle it. LuaJIT support/performance takes priority.

-- LOW: Remove invisible targets. All methods I know to do this have problems:
-- - screenpos() - Non-trivially slow
-- - strcharlen() + strdisplaywidth() - Likely also slow
-- - Hand-rolling Lua functions - Non-trivially difficult to write and maintain
-- Other issues
-- - Efficiently removing characters under floats
-- - Determining string length for the wrapped fill line
-- - Removing characters under listchars, plus under "@@@" in wrapped lines
-- Hard to prioritize because it does not cause false negatives
-- LOW: Evaluate target closeness by euclidian distance rather than row/col order.
-- LOW: For folds: first_row - Display virtual text on top of the fold and label the virtual text
-- with all the options.
--
-- PR: The end_row key in nvim_buf_set_extmark appears to be exclusive when using the hl_eol
-- option, but this is not mentioned in the docs. Verify if this intuition is correct and submit
-- a PR if so

-- ISSUE: Search does not properly consider multiline boundaries for searching after.
-- Reproduction:
-- - Open nvim clean
-- - confirm cpo c is set (is default in Neovim)
-- - Have "foo" on 15 lines
-- - Search "foo\nfoo" then enter
-- - hlsearch will correctly show the current search as two lines since cpo-c is true. However,
-- when hitting n to advance searches, it will go to the next line
-- - If incsearch is true, more weird stuff happens with how the current search increments.
-- Sometimes it's properly two lines, sometimes it shows three. Need to play with this behavior
-- more.
-- Additional questions:
-- - This needs to be tested in vanilla Vim since it's a vimfn. The issue needs to be opened there
-- if it happens there
-- - Why does hlsearch display properly? (At least in Neovim). Given the issue where hlsearch
-- always displays with cpo-c behavior, it appears there is some non-trivial code difference
-- - Is an issue already open? (Check both repos)
-- Possible cause:
-- search.c line 722:
--   if (search_from_match_end) {
--     if (nmatched > 1) {
--       // end is in next line, thus no match in
--       // this line
--       match_ok = false;
--       break;
--     }
--     matchcol = endpos.col;
--     // for empty match: advance one char
--     if (matchcol == matchpos.col && ptr[matchcol] != NUL) {
--       matchcol += utfc_ptr2len(ptr + matchcol);
--     }
--     // ...
--   }
-- matchcol is advanced, but lnum is not. But simply advancing lnum could be tricky, since it's
-- the control variable for the main search loop.
-- ISSUE: Weird hlsearch behavior.
-- Reproduction (need to confirm in minimal Neovim):
-- - Open nvim clean
-- - Confirm cpo c is off (needs to be set in Neovim)
-- - "foofoofoofoofoofoofoofoofoofoofoofoofoofoofoo"
-- - /foofoo
-- - At first match, press n
-- - First three foos highlighted
-- - Have "foo" on 15 consecutive lines
-- - /foo\nfoo<cr>
-- - The last "foo" will not be highlighted as if cpo c were present
-- Additional questions:
-- - Does this happen in vanilla vim?
-- - Is an issue already open? (Check Vim and Nvim repos)

-- FUTURE: If vim vars are able to properly hold metatables, use them for var validation
-- FUTURE: Use the new mark API when it comes out for setting pcmarks

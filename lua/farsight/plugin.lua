-- TODO: Document highlight groups here
-- TODO: Document g:vars here. Check validations

-- TODO: Create checkhealth
-- - Nvim version
-- - g:var validity checks
-- - maparg success

local api = vim.api
local fn = vim.fn
local lower = string.lower
local maparg = fn.maparg
local set = api.nvim_set_keymap

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
        set(modes[j], key, "", { noremap = true, callback = callback })
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
        local maparg_res = maparg(key, mode)
        -- Need to check for just <cr> because of unsimplification (:h <tab>)
        if maparg_res == "" or lower(maparg_res) == key then
            set(mode, key, rhs, { noremap = true })
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
        if maparg(key, mode) == "" then
            set(mode, key, rhs, { noremap = true })
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

-- TODO: For any jumps, if doing a backwards correction for omode, use cursor() instead of the API
-- because it doesn't trigger a screen update.
-- TODO: Functionalities to try putting into common
-- - Dimming. Could have a function that takes a row list, ns, and hl_group and runs through
-- setting the extmarks. Also have it take a dim opt
-- - At least some of the logic for getting the wrapped bottom row. It's all checking the opt
-- and searchpos on the first col.
-- TODO: For vim.fn calls in tight loops, maybe use the function call API, since I believe that
-- requires less overhead. You could also skip the vim.fn. metatable and use the underlying one
-- it wraps, saving a layer of indirection.
-- TODO: Refactor with DoD concepts. Non-trivial gains:
-- - Can load parts of SoA into sub functions
-- - Easier to make smaller loops
-- TODO: For storing function references. Think in terms of like:
-- - For foldclosed iterations. You can usually grab the variable once before the hot loop begins.
-- Saving the cost of one hash lookup before the hot path isn't all that relevant
-- - So like, in csearch, it's fine at the function level because you can get it before the hot
-- path. Whereas in jump it is actually needed because it runs inside the hot function
-- - Lots of small sub-functions good. JIT apparently can inline them
-- - Avoid deeply nested long functions
-- TODO: Confirm that g/b:vars can take function literals. I've seen it work, but does it break
-- TODO: Where can we use require("table.new") ?
-- easily?
-- TODO: Document that for csearch and /? search that |cpo-c| is respected
-- TODO: Add types to any usages of matchstrpos
-- TODO: The various functions should have hard protections against multi-win if not in normal mode
-- TODO: Augmented /? search. Design specs:
-- - As you are typing, items are labeled like in flash
-- - If you jump to a label, the "/" register is not updated
-- - If you hit <cr>, the "/" register is updated and hlsearch is turned on based on settings
-- - No auto-jump, as (a) this can happen by accident and (b) it can prevent entering full search
-- terms for actual searches
-- Design plan:
-- - Look at the code for search and note what it actually does. There is nuance I'm sure we'll
-- need to capture
-- - Look at what happens when "incsearch" is active. How much do we want to implement that
-- behavior?
-- - For the actual search, try to use the search() function or something related, as it uses the
-- same underlying searchit function that /? search uses
-- TODO: Document deprecation plan:
-- - Time period: 2-3 months
-- - Opt/function removal: Mark private/package, then delete
-- - Function signature change: Use a shim that routes the old interface, then delete the shim and
-- old interface
-- - Default function behaviors: Notify which opt lets you use old behavior
-- - Plug map changes: Unsure
-- Document that b:vars are the same as g:vars and prioritized. Can be used for ft configurations
-- TODO: Test everything with and around multibyte chars. It doesn't look like anything special
-- needs to be done, but need to be sure
-- TODO: Since ctrl char literals are displayed, maybe allow them to be factored into csearch and
-- jump
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
--   - flash (f/t ideas)
-- - Inspirations:
--   - Quickscope
-- - Alternatives:
--   - vim-sneak
--   - hop
--   - EasyMotion
--   - { Flash lists a lot of them }
-- - TODO: Create docgen
-- - TODO: Go through the opts of the various functions and document the g:variable overrides

-- LOW: Remove invisible targets. All methods I know to do this have problems:
-- - screenpos() - Non-trivially slow
-- - strcharlen() + strdisplaywidth() - Likely also slow
-- - Hand-rolling Lua functions - Non-trivially difficult to write and maintain
-- Other issues
-- - Efficiently removing characters under floats
-- - Determining string length for the wrapped fill line
-- - Removing characters under listchars, plus under "@@@" in wrapped lines
-- Hard to prioritize because it does not cause false negatives
--
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

-- PR: Understand how matchstrpos's returns actually work and update them in eval.lua

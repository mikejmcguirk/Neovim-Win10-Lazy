-------------------------
--- GLOBAL UTILS/VARS ---
-------------------------

--- https://github.com/tjdevries/lazy-require.nvim/blob/master/lua/lazy-require.lua
--- @param require_path string
--- @return table
function _G.Qfr_Defer_Require(require_path)
    return setmetatable({}, {
        __index = function(_, key)
            return require(require_path)[key]
        end,

        __newindex = function(_, key, value)
            require(require_path)[key] = value
        end,
    })
end

-- NOTE: If you set an impossible height, Nvim will clamp it to the available area - 1
-- This value is for aesthetic/sanity purposes
_G.QFR_MAX_HEIGHT = 10

-----------------------
-- Config/Validation --
-----------------------

--- LOW: Add a g:var to handle closing behavior when lists are deleted

--- TODO: These are my personal settings. Get out of here
-- Personal setting. Default is false in line with Nvim
vim.api.nvim_set_var("qf_rancher_auto_open_changes", true)
vim.api.nvim_set_var("qf_rancher_debug_assertions", true)
vim.api.nvim_set_var("qf_rancher_preview_debounce", 50)
vim.api.nvim_set_var("qf_rancher_preview_show_title", false)
-- vim.api.nvim_set_var("qf_rancher_set_default_maps", false)

--- TODO: For stuff like winblend, use actual validator functions
--- TODO: Make sure the options actually do what they're supposed to
--- DOCUMENT: What these vars do

_G._QFR_G_VAR_MAP = {
    qf_rancher_auto_open_changes = { { "boolean" }, false },
    -- DOCUMENT:
    -- - If splitkeep is set to screen or topline, that will take precedence
    -- - If splitkeep is set for cursor, and this option is true, rancher will save and restore
    --      views where necessary
    -- - If this is off and splitkeep is set for cursor, you get Nvim default behavior
    qf_rancher_always_save_views = { { "boolean" }, true },
    qf_rancher_debug_assertions = { { "boolean" }, false },
    qf_rancher_del_all_if_empty = { { "boolean" }, true },

    qf_rancher_ftplugin_demap = { { "boolean" }, true },
    qf_rancher_ftplugin_keymap = { { "boolean" }, true },
    qf_rancher_ftplugin_set_opts = { { "boolean" }, true },

    qf_rancher_grepprg = { { "string" }, "rg" },

    qf_rancher_map_ll_prefix = { { "string" }, "l" },
    qf_rancher_map_qf_prefix = { { "string" }, "q" },

    qf_rancher_preview_border = { { "string", "table" }, "single" },
    -- DOCUMENT: Default is 100 to accomodate slower systems/HDs. 50 should be fine if you have an
    -- SSD/reasonably fast computer. Below that more risk of things getting choppy
    qf_rancher_preview_debounce = { { "number" }, 100 },
    qf_rancher_preview_show_title = { { "boolean" }, true },
    qf_rancher_preview_title_pos = { { "string" }, "left" },
    qf_rancher_preview_winblend = { { "number" }, 0 },
    qf_rancher_qfsplit = { { "string" }, "botright" },
    qf_rancher_set_default_maps = { { "boolean" }, true },
    qf_rancher_set_default_cmds = { { "boolean" }, true },
    qf_rancher_use_smartcase = { { "boolean" }, true },
} --- @type table<string, {[1]:string[], [2]: any}>

for k, v in pairs(_QFR_G_VAR_MAP) do
    local cur_g_val = vim.g[k] --- @type any
    if not vim.tbl_contains(v[1], type(cur_g_val)) then vim.api.nvim_set_var(k, v[2]) end
end

--- TODO: It seems like this file is effectively the /plugin file, so this will have to be moved
--- in here
require("mjm.error-list-maps")

----------------
--- Autocmds ---
----------------

-- MAYBE: If you want to be fancy, for each of these qf open/close commands, you could have
-- a generalized function for win_check, and pass in function handlers for different wintype
-- conditions. Would allow for customization. But for the current case, I think the layers of
-- wrappers would add complexity

-- FUTURE: View adjustments should take into account scrolloff and screenlines so that if the
-- user re-enters the window, it doesn't shift to meet scrolloff requirements
-- screenpos() ?
-- screenrow() ?

-- TODO: There should be a setting for whether or not to turn these autocmds on
--- @type integer
-- local loclist_group = vim.api.nvim_create_augroup("loclist-group", { clear = true })

-- Start each window with a fresh loclist
-- vim.api.nvim_create_autocmd("WinNew", {
--     group = loclist_group,
--     pattern = "*",
--     callback = function() vim.fn.setloclist(0, {}, "f") end,
-- })

-- TODO: This does not work when the llist is the last window. Maybe purge and bufdel
-- update - Use protected close
-- Clean up orphaned loclists
-- vim.api.nvim_create_autocmd("WinClosed", {
--     group = loclist_group,
--     callback = function(ev)
--         local win = tonumber(ev.match) --- @type number?
--         if not type(win) == "number" then return end
--
--         local config = vim.api.nvim_win_get_config(win) --- @type vim.api.keyset.win_config
--         if config.relative and config.relative ~= "" then return end
--
--         local buf = vim.api.nvim_win_get_buf(win) --- @type integer
--         local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf }) --- @type string
--         if buftype == "quickfix" then return end
--
--         local qf_id = vim.fn.getloclist(ev.match, { id = 0 }).id ---@type integer
--         if qf_id == 0 then return end
--         require("mjm.utils").close_all_loclists(qf_id)
--     end,
-- })

-- TODO: Once I have rancher setup as a plugin, create custom maps to its history cycling and
-- get rid of this
local function qf_scroll_wrapper(main, alt, end_err)
    local main_with_count = vim.tbl_extend("force", main, { count = vim.v.count1 })
    local ok, err = pcall(vim.api.nvim_cmd, main_with_count, {})

    if (not ok) and (err:match("E42") or err:match("E776")) then
        vim.notify(err:sub(#"Vim:" + 1))
        return
    end

    if (not ok) and err:match(end_err) then
        ok, err = pcall(vim.api.nvim_cmd, alt, {})
    end

    if not ok then
        err = err and err:sub(#"Vim:" + 1) or "Unknown qf_scroll error"
        vim.notify(err, vim.log.levels.WARN)
        return
    end

    vim.cmd("norm! zz")
end

local scroll_maps = {
    {
        "[<M-q>",
        { cmd = "colder" },
        { cmd = "execute", args = { "getqflist({'nr' : '$'}).nr . 'chistory'" } },
        "E380",
    },
    { "]<M-q>", { cmd = "cnewer" }, { cmd = "chistory", count = 1 }, "E381" },
    {
        "[<M-l>",
        { cmd = "lolder" },
        { cmd = "execute", args = { "getloclist(0, {'nr' : '$'}).nr . 'lhistory'" } },
        "E380",
    },
    { "]<M-l>", { cmd = "lnewer" }, { cmd = "lhistory", count = 1 }, "E381" },
}

for _, m in pairs(scroll_maps) do
    Map("n", m[1], function()
        qf_scroll_wrapper(m[2], m[3], m[4])
    end)
end

-------------
--- TODO: ---
-------------

-- lemmy cmd: lemmy-help -l "compact" names > output
-- Make sure the luarc for the project has the disabled private diag for docs. Also want to
-- not have the trailing space one
-- Unsure where to document the what opts, since they are the same for each function
-- Doc sanitation. Remove unnecessary doc strings
-- For anything with one reference, merge it in
-- Use the command mentality throughout
-- Formatting: api/fn/other long names. defer require
--- For validation and such, the g variables should be as generous as possible with user error,
---     the actual API stuff should be strict
--- For organizing the module opts, the module specific input opts should be tied specifically to
---     the command. This is your conceptual anchor. With that, I think we can consider the
---     APIs and such more baked in
--- Put a confirm statement in every project file. It should be possible to open Nvim and then
--- a list without eager requiring other modules
--- Function audit - Is the win variable a src_win, list_win, something else? Don't just pass
---     "win" as a variable, as it is not necessarily clear what the win is supposed to be
--- Go through everything and be strict on data validation, including stuff that comes from the
---     user. We should only handle bad results from exterior programs
--- Cmd prefix customization
--- Orphan loclist handling:
--- - Grouping arbitrarily with other commands produces confusing behavior
--- - The autocmd to close associated loclists should be enabled by default
--- - Any close cmd needs to check if the window type is loclist so it can run in orphans
--- - The lE purge needs to properly handle orphans
--- - The autocmd to prevent loclists from moving should be enabled by default
--- Check validations for what should and should not be behind g vars. General rule - If it's
---     a public API or right behind one, should be validated. Same with functions that can cause
---     real issues if they go wrong (list cycling is the most obvious example)

--- Audit all files except ftplugin for bad/old API usage
--- Add in the util func for opening based on outputopts. Put it behind a gvar

--- - I have filter and sort right now set to use new list as their default, in line with how
--- Cfilter works. And that should actually be the default. But I am thinking there might need
--- to be a way to not do that. Having to do qGf to sort by filename without pollutting the
--- stack seems cumbersome. And I don't want to just say "use the plug mappings" because there are
--- over 300 keymaps. It's not feasible
---
--- - For the keymaps, there has to be a way to edit how they're set from g vars. There are too
--- many maps to rely on plugs
--- - How to handle deferred maps, like for bufgrep and such
--- - Need some kind of convenience function for reading g variables that accounts for nil and
--- vim.NIL values, because I'm not sure that vim.NIL is falsy the same way
---
--- Putting list_item_type in output opts is correct because it has to do with the rendering of
--- of the list items. It also makes sense, in the main validation step, to allow nil values
--- through because individual functions might want to treat a nil list item type as something to
--- ignore. I guess the broader thing to just keep in mind is that the field can't be a gotcha
--- in contexts where you don't expect it to come up
---
--- Check the file for any vim.fn.confirm
--- Check that no eager requires happen on startup
--- DOuble check that all view saving sufficiently respects splitkeep/g:vars
--- Make sure g variables are doing what they should be
--- Audit everything for handling of 0 location lists. These are still-open loclist windows where
---     the stack has been wiped. The wintype will still be "loclist"

-----------
--- MID ---
-----------

--- Unsure how to deal with wintype annotations. Ideally they would be aliased in the core
---     codebase. Unsure if I should make my own alias here or not
--- Look into running more functionality through the default Qf commands given that they're tied
---     to the QuickFixCmd autocmds
--- Also look into what events we can use those autocmds to drive
--- Make resizing configurable
--- A problem with cdo is, say you make changes on a couple lines, then realizes you're better off
---     just using cdo to run a substitute command, you will get enter errors on the entries you
---     already changed. It would be better if cdo/cfdo ran in protected mode, perhaps showing
---     the errors afterwards. Unsure though if there's a way to properly capture context so
---     you can run each command pcalled individually, or if you have to do a nvim_cmd cdo and
---     run that whole thing in the pcall
--- Publish Qf items as diagnostics. Would make other ideas more useful
--- Commands to handle:
--- - cexpr
--- - cbuffer/cgetbuffer/caddbuffer
--- - cfile
--- - clist
--- - cabove/cbelow
---     - It's tough to make these helpful without some sort of visual feedback, implying that you
---     would need a way to push qf entries to virtual text extmarks so they could be navigated.
---     This risks tripping over LSP diagnostics. Nvim alreaddy has diagnostic navigation
---     features built in, and this would be a tough feature to implement for an uncertain
---     use case
--- How to make the list more useful with compilers. Possible starting points:
--- - https://github.com/Zeioth/compiler.nvim
--- - https://github.com/ahmedkhalf/project.nvim
--- - https://github.com/stevearc/overseer.nvim
--- - :h :make_makeprg
--- - :h compiler-select
--- The open mappings and such should work in visual mode
--- Make a way to explicitly copy/replace/merge whole lists. This can be hacked with fitler, but
---     that means guaranteeting how an empty pattern behaves, which seems like an unnecessary
---     limitation
--- Look into the idea of brdiging lists between the loclist and qflists
--- Take all Qf entries and send their ranges to a normal buffer
--- - Could also send greps to normal buffers
---     - Implies a broader idea of what greps can do outside the error lists
--- - Could also writes bufs to the qflist
--- https://github.com/gabrielpoca/replacer.nvim - For edits and bulk changes, this seems to be
---     the way, where you put the Qflist into edit mode, and then re-integrate the changes
---     in a save step
---     https://github.com/stefandtw/quickfix-reflector.vim - A similar take

-----------
--- LOW ---
-----------

--- Something awkward is that, because marks are not supported, you cannot run any cmds from
---     visual mode without manually removing the marks with <C-u>. This adds friction to running
---     greps and filters from the cmd line in visual mode. You could bandaid this by allowing the
---     cmd to accept marks but then just ignoring them, but I think that then is deceptive toward
---     the user. The vim normal mode command just falls through. But since the greps can
---     work from visual marks, that feels more deceptive
--- Operations that move loclists over to qflists and vice-versa
--- Better error format? The masking of errors in particular is annoying
--- Show ts-context info in preview wins
--- Allow customizing windows to skip when looking for open targets:
---     https://github.com/kevinhwang91/nvim-bqf/issues/78
--- Test with the old nvim-treesitter master branch
--- Incremental preview of cdo/cfdo changes
--- A better way of handling cdo/cfo so you don't get spammed with enter errors
--- General cmd parsing: https://github.com/niuiic/quickfix.nvim
--- If 1k keymaps, autogen a DoD setup. Would actually save time
--- Use a g:var to control regex case sensitivity
--- Test load behavior against mksession

----------------
--- DOCUMENT ---
----------------

--- When writing the plugin description, don't focus on overly pastoral ranching imagery, as the
--- poitn of the Quickfix list is to be quick
--- The new/add/replace behavior
--- How smartcase works by default (the "vimsmart" thing). Does it make sense?
---     Have to document this in the more general sense with "smartcase" and "insensitive" also as
---     options
--- Use of marks is not supported in cmds because they are row only
--- In the commands, a count of zero is treated as a no count
--- DOCUMENT: Buf greps use external grep
--- DOCUMENT: qf Buf Grep is all bufs, ll Buf Grep is current buf only
--- DOCUMENT: rg handles true multi-line greps. For programs that don't, or is used as a fallback
--- DOCUMENT: The following are non-goals:
--- - Creating persistent state beyond what is necessary to make the preview win work
--- - Modifying buffers within the qflist
--- - Providing additional context within the list itself. Covered by the preview win
--- - No Fuzzy finding type stuff. FzfLua does this. And as far as I know, all the major finders
---     have the ability to search the qflists
--- - No annotations. Should be able to filter down to key items
--- - Dynamic behavior. Trouble has to create a whole async runtime and data model to manage this
--- - "Modernizing" the feel of the qflist. The old school feel is part of the charm
--- Cmds don't accept ranges
--- The open functions double as resizers, as per the default cmd behavior
--- cn/cpfile does not have the same level of wrapping logic as cc
--- underline functions are not supported
--- What types of regex are used where. Grep cmds have their own regex. Regex filters use
---     vim regex
--- Note that vim regex is case sensitive by default(right?)

------------
--- PR ---
------------

--- It would be better if cmd marks produced rows and columns
--- Wintype is currently just an or enum. Should be an alias so it can be annotated
--- It should be possible to output vimgrep to a list so it can be used by internal scripting

---------------
-- RESOURCES --
---------------

-- RESOURCES
-- https://github.com/romainl/vim-qf
-- https://github.com/kevinhwang91/nvim-bqf
-- https://github.com/arsham/listish.nvim
-- https://github.com/itchyny/vim-qfedit -- Simple version of quicker
-- https://github.com/mileszs/ack.vim
-- https://github.com/stevearc/qf_helper.nvim
-- https://github.com/niuiic/quickfix.nvim
-- https://github.com/mhinz/vim-grepper

-- PREVIEWERS:
-- https://github.com/r0nsha/qfpreview.nvim
-- https://github.com/bfrg/vim-qf-preview

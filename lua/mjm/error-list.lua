-------------
--- TYPES ---
-------------

--- @alias QfRancherAction "new"|"replace"|"add"
--- @alias QfRancherInputType "insensitive"|"regex"|"sensitive"|"smart"|"vimsmart"

--- @class QfRancherInputOpts
--- @field input_type? QfRancherInputType
--- @field pattern? string
---
--- @class QfRancherOutputOpts
--- @field action? QfRancherAction
--- @field count? integer
--- @field is_loclist? boolean
--- @field loclist_source_win? integer
--- @field list_item_type? string
--- @field title? string

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

-----------------------
-- Config/Validation --
-----------------------

-- Personal setting. Default is false in line with Nvim
vim.api.nvim_set_var("qf_rancher_auto_open_changes", true)
vim.api.nvim_set_var("qf_rancher_debug_assertions", true)
-- vim.api.nvim_set_var("qf_rancher_set_default_maps", false)

-- TODO: For now, I'm not adding config for the default maps. I have a feeling like I should
-- because there are so many. But, because there are so many, that also adds complication to any
-- boilerplate options to configure them, to the point where I'm not sure it's less complicated
-- than just promoting the plug mappings
--
-- TODO: Put the options into a table and iterate through them

if type(vim.g.qf_rancher_set_default_maps) ~= "boolean" then
    vim.api.nvim_set_var("qf_rancher_set_default_maps", true)
end

if type(vim.g.qf_rancher_set_default_cmds) ~= "boolean" then
    vim.api.nvim_set_var("qf_rancher_set_default_cmds", true)
end

if type(vim.g.qf_rancher_auto_open_changes) ~= "boolean" then
    vim.api.nvim_set_var("qf_rancher_auto_open_changes", false)
end

if type(vim.g.qf_rancher_debug_assertions) ~= "boolean" then
    vim.api.nvim_set_var("qf_rancher_debug_assertions", false)
end

if type(vim.g.qf_rancher_grepprg) ~= "string" then
    vim.api.nvim_set_var("qf_rancher_grepprg", "rg")
end

if type(vim.g.qf_rancher_qfsplit) ~= "string" then
    vim.api.nvim_set_var("qf_rancher_qfsplit", "botright")
end

--- TODO: Should have some level of flexibility for defining when the list auto opens and when
--- it does not. Right now I'm doing everything based on a combination of what I remember of
--- the default behavior and personal taste, but should do deeper dive into defaults to figure out
--- what those expectations are + what are the logical deviation points

-- DOCUMENT:
-- - If splitkeep is set to screen or topline, that will take precedence
-- - If splitkeep is set for cursor, and this option is true, rancher will save and restore views
-- where necessary
-- - If this is off and splitkeep is set for cursor, you get Nvim default behavior
if type(vim.g.qf_rancher_always_save_views) ~= "boolean" then
    vim.api.nvim_set_var("qf_rancher_always_save_views", true)
end

-- Document that nil is the default state and evaluated differently. nil falls back to the vim
-- smartcase option. False overrides it
vim.validate("qf_rancher_use_smartcase", vim.g.qf_rancher_use_smartcase, { "boolean", "nil" })

require("mjm.error-list-maps")

------------------------
-- Other source notes --
------------------------

-- The vimgrep code is in quickfix.c. Functions often start with "vgr"

local M = {}

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
        -- TODO: Going left on chistory in no entries cuts off improperly
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

return M

-------------
--- TODO: ---
-------------

--- Audit all files except ftplugin for bad/old API usage
--- Add in the util func for opening based on outputopts. Put it behind a gvar

--- - I have filter and sort right now set to use new list as their default, in line with how
--- Cfilter works. And that should actually be the default. But I am thinking there might need
--- to be a way to not do that. Having to do qGf to sort by filename without pollutting the
--- stack seems cumbersome. And I don't want to just say "use the plug mappings" because there are
--- over 300 keymaps. It's not feasible
--- - Properly use the title output option everywhere
--- - Properly use the output_opts count where relevant
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

-----------
--- MID ---
-----------

--- Make resizing configurable

-------------
--- # LOW ---
-------------

--- Something awkward is that, because marks are not supported, you cannot run any cmds from
---     visual mode without manually removing the marks with <C-u>. This adds friction to running
---     greps and filters from the cmd line in visual mode. You could bandaid this by allowing the
---     cmd to accept marks but then just ignoring them, but I think that then is deceptive toward
---     the user. The vim normal mode command just falls through. But since the greps can
---     work from visual marks, that feels more deceptive
--- You could have operations that pull from one list type and write to the other, for example
---     taking the elements form the qflist, sorting, then sending to the loclist. Youl could use
---     an is_loclist value with a source window in input_opts
--- - For the cmd UI, you could do something likst Qsort toloclist or Lsort toqflist. But I'm not
---     sure how you do it as a hotkey
--- - This also introduces significant complexity in the input opts. You have to validate the
---     input opts, which should be fine, but then you have to cross-validate with output_opts,
---     which breaks a lot of current assumptions, and makes certain types of implicit logic
---     impossible
--- - This feels like something not to attempt without a strong use case

-----------------------
--- # DOCUMENTATION ---
-----------------------

--- How smartcase works by default (the "vimsmart" thing). Does it make sense?
---     Have to document this in the more general sense with "smart" and "insensitive" also as
---     options
--- Use of marks is not supported in cmds because they are row only

------------
--- # PR ---
------------

--- It would be better if cmd marks produced rows and columns
--- Wintype is currently just an or enum. Should be an alias so it can be annotated

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

-- PREVIEWERS:
-- https://github.com/r0nsha/qfpreview.nvim
-- https://github.com/bfrg/vim-qf-preview

--------------

--- FUTURE: Add the ability to publish qf items as diagnostics. It feels like a blocker to a lot of
--- other useful ideas
--- FUTURE: Create updated quickfixtextfunc
--- - The default masks error types
--- FUTURE: Commands to handle:
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
--- FUTURE: I think it would be good to enhance the ability to use the qflist to handle compiler
--- and testing errors. But I'm not experienced enough with the ecosystem to know what gaps there
--- are to fill. Some stuff I know is out there:
--- - https://github.com/Zeioth/compiler.nvim
--- - https://github.com/ahmedkhalf/project.nvim
--- - https://github.com/stevearc/overseer.nvim
--- - :h :make_makeprg
--- - :h compiler-select
--- FUTURE: Show ts-context info in preview wins
--- FUTURE: Allow customizing windows to skip when looking for open targets:
---     https://github.com/kevinhwang91/nvim-bqf/issues/78
--- FUTURE: Test with the old nvim-treesitter master branch
--- FUTURE: Incremental preview of cdo/cfdo changes
--- FUTURE: General cmd parsing: https://github.com/niuiic/quickfix.nvim - This is obviously a
---     good idea, but I'm not sure what the specific use case is so I'm not sure how to build it
--- FUTURE: I would like to do something with cdo/cfdo, but I'm not sure what that isn't just
--- syntactic sugar on top of the original cmd

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

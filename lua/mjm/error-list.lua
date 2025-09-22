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

--- TODO: Touchup/cleanup
--- - Throughout the project, change any "merge" verbiage to "add" verbiage
--- - Saw feature request for current file entries first. This does not fit in with how I
--- want things organized, but does raise point that loclist mappings should be available where
--- possible to focus current buf
--- - Allow customizing of how the qfopens. Should not have to use botright if you don't
--- want to
---
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

-----------------------
-- Config/Validation --
-----------------------

-- TODO: For now, I'm not adding config for the default maps. I have a feeling like I should
-- because there are so many. But, because there are so many, that also adds complication to any
-- boilerplate options to configure them, to the point where I'm not sure it's less complicated
-- than just promoting the plug mappings

---@diagnostic disable-next-line: undefined-field
local g_qfrancher_setdefaultmaps = vim.g.qfrancher_setdefaultmaps
if g_qfrancher_setdefaultmaps then
    vim.validate("g_qfrancher_setdefaultmaps", g_qfrancher_setdefaultmaps, "boolean")
else
    vim.api.nvim_set_var("qfrancher_setdefaultmaps", true)
end

---@diagnostic disable-next-line: undefined-field
local g_qfrancher_setdefaultcmds = vim.g.qfrancher_setdefaultcmds
if g_qfrancher_setdefaultcmds then
    vim.validate("g_qfrancher_setdefaultcmds", g_qfrancher_setdefaultcmds, "boolean")
else
    vim.api.nvim_set_var("qfrancher_setdefaultcmds", true)
end

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

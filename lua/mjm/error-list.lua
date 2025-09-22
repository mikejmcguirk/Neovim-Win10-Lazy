--- FUTURE: Create updated quickfixtextfunc
--- - The default masks error types

--- TODO: Throughout the project, change any "merge" verbiage to "add" to align with vimgrepadd
--- and caddbuffer
--- TODO: Go thorugh this file and get all old functionalities. Need wrap commands and
--- state management. Note history should adjust height
--- TODO: look at the issue/PR lists for the various qf plugins to see what people want
--- TODO: commands:
--- - is there a way to make cabove/cbelow useful? or maybe cbefore/cafter
--- - the various cfile commands
--- - caddbuffer/cgetbuffer
--- - cexpr
--- - I think we kind of have :filter covered but investigate
--- - clist?
--- - cwindow/cbottom
--- - you could do grep cmds like vimgrepadd or you could do Qgrepmerge for example
---
--- TODO: :h :make_markprg
---
--- MAYBE: <C-w><Cr> is open a new window and jump to error. Feels like useful pattern for
--- ftplugin maps. But it's not the ack pattern, so hard to say what's right here
--- TODO: :h compiler-select. But how much does this overlap with the compiler plugin?

--- MAYBE: Should open/close cmds also run wincmd =?
--- MAYBE: Incremental preview of cdo/cfdo changes
--- MAYBE: General cmd parsing: https://github.com/niuiic/quickfix.nvim
--- MAYBE: Publish qf items as diagnostics
---     Semi related, but it would be cool to run make or a test and have the diagnostics publish
---
--- MAYBE: https://github.com/Zeioth/compiler.nvim
--- MAYBE: https://github.com/ahmedkhalf/project.nvim
--- MAYBE: https://github.com/stevearc/overseer.nvim

--- DOCUMENT: Buf greps use external grep
--- DOCUMENT: qf Buf Grep is all bufs, ll Buf Grep is current buf only
--- DOCUMENT: rg handles true multi-line greps. For programs that don't, or is used as a fallback

--------------
-- STAYAWAY --
--------------

--- No attaching to buffers/creating persistent state
--- No modifying buffers within the qflist
--- No additional context type stuff. Previewer covers this
--- No Fuzzy finding type stuff. FzfLua does this
--- No annotations. Should be able to filter down to key items
--- Dynamic behavior. Trouble has to create a whole async runtime and data model to manage this
--- "Modernizing" the feel of the qflist. The old school feel is part of the charm

--------------
-- MAPPINGS --
--------------

--- GENERAL BUFFER MAPS
--- view count of lists
--- goto list number (unimpaired already does cycling)
--- something like qd and qD for cdo and cfdo
--- A way to copy lists, and maybe filtered copy
--- A merge kinda like deep table extend where duplicates are filtered
--- Or a merge that works like a XOR
--- Some of these more complex ideas feel more like commands
---
--- show current stack nr (chistory/lhistory)
--- stack nr statusline component?
---
--- QF BUFFER:
--- p to toggle preview
--- vim-qf-preview has some reasonable maps (r mainly) for previewer

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

-- TODO: I can't put alt maps in rancher
-- Probably the best idea is to put in <> as history maps into the Qf ftplugin. This is
-- patternful with other plugins. Can check those and unimpaired as well
local scroll_maps = {
    { "[q", { cmd = "cprevious" }, { cmd = "clast" }, "E553" },
    { "]q", { cmd = "cnext" }, { cmd = "crewind" }, "E553" },
    { "[l", { cmd = "lprevious" }, { cmd = "llast" }, "E553" },
    { "]l", { cmd = "lnext" }, { cmd = "lrewind" }, "E553" },
    { "[<C-q>", { cmd = "cpfile" }, { cmd = "clast" }, "E553" },
    { "]<C-q>", { cmd = "cnfile" }, { cmd = "crewind" }, "E553" },
    { "[<C-l>", { cmd = "lpfile" }, { cmd = "llast" }, "E553" },
    { "]<C-l>", { cmd = "lnfile" }, { cmd = "lrewind" }, "E553" },
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

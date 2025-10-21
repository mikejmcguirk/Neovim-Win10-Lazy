-- ===========================
-- == NVIM QUICKFIX RANCHER ==
-- ===========================

---https://github.com/tjdevries/lazy-require.nvim/blob/master/lua/lazy-require.lua
---@param require_path string
---@return table
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

local eo = Qfr_Defer_Require("mjm.error-list-open") ---@type QfrOpen

_G.QFR_MAX_HEIGHT = 10

-- TODO: These are my personal settings. Get out of here
-- TODO: Re-create my alt mappings for q/l history
vim.api.nvim_set_var("qfr_debug_assertions", true)
vim.api.nvim_set_var("qfr_preview_debounce", 50)
vim.api.nvim_set_var("qfr_preview_show_title", false)

local api = vim.api
local fn = vim.fn

---@mod NvimQfRancher Error list husbandry

-- ============
-- == G VARS ==
-- ============

-- MID: Create specific validator functions for these where appropriate

-- DOCUMENT: What these vars do

_G._QFR_G_VAR_MAP = {
    qfr_auto_open_changes = { { "boolean" }, true },
    qfr_auto_list_height = { { "boolean" }, true },
    -- DOCUMENT:
    -- - If splitkeep is set to screen or topline, that will take precedence
    -- - If splitkeep is set for cursor, and this option is true, rancher will save and restore
    --      views where necessary
    -- - If this is off and splitkeep is set for cursor, you get Nvim default behavior
    qfr_always_save_views = { { "boolean" }, true },
    qfr_debug_assertions = { { "boolean" }, false },
    qfr_close_on_stack_clear = { { "boolean" }, true },
    qfr_create_autocmds = { { "boolean" }, true },

    qfr_ftplugin_demap = { { "boolean" }, true },
    qfr_ftplugin_keymap = { { "boolean" }, true },
    qfr_ftplugin_set_opts = { { "boolean" }, true },

    qfr_grepprg = { { "string" }, "rg" },

    qfr_map_set_defaults = { { "boolean" }, true },
    qfr_map_ll_prefix = { { "string" }, "l" },
    qfr_map_qf_prefix = { { "string" }, "q" },
    qfr_map_diag_prefix = { { "string" }, "i" },
    qfr_map_keep_prefix = { { "string" }, "k" },
    qfr_map_remove_prefix = { { "string" }, "r" },
    qfr_map_grep_prefix = { { "string" }, "g" },
    qfr_map_sort_prefix = { { "string" }, "t" },

    qfr_preview_border = { { "string", "table" }, "single" },
    -- DOCUMENT: Default is 100 to accomodate slower systems/HDs. 50 should be fine if you have an
    -- SSD/reasonably fast computer. Below that more risk of things getting choppy
    qfr_preview_debounce = { { "number" }, 100 },
    qfr_preview_show_title = { { "boolean" }, true },
    qfr_preview_title_pos = { { "string" }, "left" },
    qfr_preview_winblend = { { "number" }, 0 },

    qfr_qfsplit = { { "string" }, "botright" },
    qfr_reuse_same_title = { { "boolean" }, true },
    qfr_set_default_cmds = { { "boolean" }, true },
    qfr_skip_zzze = { { "boolean" }, false },
} ---@type table<string, {[1]:string[], [2]: any}>

for k, v in pairs(_QFR_G_VAR_MAP) do
    local cur_g_val = vim.g[k] ---@type any
    if not vim.tbl_contains(v[1], type(cur_g_val)) then vim.api.nvim_set_var(k, v[2]) end
end

-- TODO: Since this is the /plugin file, integrate the maps here
require("mjm.error-list-maps")

if vim.g.qfr_create_autocmds then
    local qfr_loclist_group = vim.api.nvim_create_augroup("qfr-loclist-group", { clear = true })

    api.nvim_create_autocmd("WinNew", {
        group = qfr_loclist_group,
        callback = function()
            vim.fn.setloclist(0, {}, "f")
        end,
    })

    api.nvim_create_autocmd("WinClosed", {
        group = qfr_loclist_group,
        callback = function(ev)
            local win = tonumber(ev.match) ---@type number?
            if not win then return end

            if not api.nvim_win_is_valid(win) then return end

            local config = vim.api.nvim_win_get_config(win) ---@type vim.api.keyset.win_config
            if config.relative and config.relative ~= "" then return end

            local qf_id = fn.getloclist(win, { id = 0 }).id ---@type integer
            if qf_id < 1 then return end

            local buf = vim.api.nvim_win_get_buf(win) ---@type integer
            if api.nvim_get_option_value("buftype", { buf = buf }) == "quickfix" then return end

            vim.schedule(function()
                eo._close_loclists_by_qf_id(qf_id, { all_tabpages = true })
            end)
        end,
    })
end

---@export NvimQfRancher

-- NOTES:
-- - Any space breaks in annotation comments are intentional to make lemmy-ehlp ignore them

-- TODO: Create docgen script. 'lemmy-help -l "compact" [fnames] > output.txt'
-- TODO: The project's luarc should contain the trailing whitespace nop

-- DOCUMENT: For cmd mappings, document what cmd opts they expect to be available

-- TEST: Put a confirm statement in every file. None of them should fire on startup
-- Smarter way would be to inspect the cache of loaded modules

-- MID: Alias wintype annotations?
-- MID: Publish Qf items as diagnostics. Would make other ideas more useful
-- MID: Remaining Commands to handle:
-- - cexpr
-- - cbuffer/cgetbuffer/caddbuffer
-- - cfile
-- - clist
-- - cabove/cbelow
-- MID: How to make the list more useful with compilers. Possible starting points:
-- - https://github.com/Zeioth/compiler.nvim
-- - https://github.com/ahmedkhalf/project.nvim
-- - https://github.com/stevearc/overseer.nvim
-- - :h :make_makeprg
-- - :h compiler-select
-- MID: Add ftplugin files that use rancher, such as make commands piped to the system module
-- MID: The open mappings and such should work in visual mode
-- LOW: If we explore the idea of editing the qf buffer, the best way to do it seems to be to
-- treat "edit mode" as a distinct thing, where it can then be saved and propagate the changes
-- - https://github.com/gabrielpoca/replacer.nvim
-- - https://github.com/stefandtw/quickfix-reflector.vim

-- LOW: A way to copy/replace/merge whole lists
-- LOW: Is there a way to bridge lists between the qf and loclists?
-- LOW: View adjustments should take into account scrolloff and screenlines so that if the
-- user re-enters the window, it doesn't shift to meet scrolloff requirements
-- LOW: How to improve on cdo/cfdo? Random errors on substitution are bad
-- cfdo is fairly feasible because you can win_call or buf_call on every file behind a pcall
-- But then how to show errors
-- LOW: Smoother way to run cmds from visual mode without manually removing the marks. I don't
-- want the cmds to accept then throw away a range. Deceptive UI
-- LOW: Better error format. The default masking of certain error types hides info from the
-- user. Would also be helpful if pipe cols were more consistent
-- LOW: ts-context integration in preview wins
-- LOW: scrolling in preview wins
-- LOW: Allow customizing windows to skip when looking for open targets:
-- - https://github.com/kevinhwang91/nvim-bqf/issues/78
-- LOW: Incremental preview of cdo/cfdo changes
-- LOW: General cmd parsing: https://github.com/niuiic/quickfix.nvim
-- LOW: Somehow auto-generate the keymaps. Would help with docgen
-- LOW: Use a g:var to control regex case sensitivity

-- DOCUMENT: vim.regex currently uses case sensitive default behavior
-- DOCUMENT: cmds are not designed to be run in visual mode
-- DOCUMENT: How default counts are treated in cmds and maps
-- DOCUMENT: Buf greps use external grep
-- DOCUMENT: qf Buf Grep is all bufs, ll Buf Grep is current buf only
-- DOCUMENT: rg handles true multi-line greps. For programs that don't, or is used as a fallback
-- DOCUMENT: The following are non-goals:
-- - Creating persistent state beyond what is necessary to make the preview win work
-- - Dynamically modifying buffers within the qflist
-- - Providing additional context within the list itself. Covered by the preview win
-- - No Fuzzy finding type stuff. FzfLua does this. And as far as I know, all the major finders
--   have the ability to search the qflists
-- - No annotations. Should be able to filter down to key items
-- - Dynamic behavior. Trouble has to create a whole async runtime and data model to manage this
-- - "Modernizing" the feel of the qflist. The old school feel is part of the charm
-- DOCUMENT: Cmds don't accept ranges
-- DOCUMENT: The open functions double as resizers, as per the default cmd behavior
-- DOCUMENT: If open is run and the list is open, go to the list
-- DOCUMENT: underline functions are not supported
-- DOCUMENT: What types of regex are used where. Grep cmds have their own regex. Regex filters use
-- vim regex
-- DOCUMENT: The README should include alternatives, including quicker

-- PR: Fix wintype annotations
-- PR: It should be possible to output vimgrep to a list so it can be used by internal scripting
-- PR: It would be better if cmd marks produced rows and columns

-- RESOURCES --
-- https://github.com/romainl/vim-qf
-- https://github.com/kevinhwang91/nvim-bqf
-- https://github.com/arsham/listish.nvim
-- https://github.com/itchyny/vim-qfedit -- Simple version of quicker
-- https://github.com/mileszs/ack.vim
-- https://github.com/stevearc/qf_helper.nvim
-- https://github.com/niuiic/quickfix.nvim
-- https://github.com/mhinz/vim-grepper
-- https://github.com/ten3roberts/qf.nvim

-- PREVIEWERS --
-- https://github.com/r0nsha/qfpreview.nvim
-- https://github.com/bfrg/vim-qf-preview

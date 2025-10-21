local eo = Qfr_Defer_Require("mjm.error-list-open") --- @type QfrOpen

local api = vim.api
local bufmap = api.nvim_buf_set_keymap
local fn = vim.fn

local function bufmap_plug(mode, lhs, rhs, desc)
    vim.api.nvim_buf_set_keymap(0, mode, lhs, rhs, { noremap = true, nowait = true, desc = desc })
end

-- NOTE: To avoid requires, don't use util g_var function

-- DOCUMENT: Which options are set
if vim.g.qf_rancher_ftplugin_set_opts then
    api.nvim_set_option_value("buflisted", false, { buf = 0 })
    api.nvim_set_option_value("cc", "", { scope = "local" })
    api.nvim_set_option_value("list", false, { scope = "local" })
    api.nvim_set_option_value("spell", false, { scope = "local" })
end

-- DOCUMENT: which defaults are removed
if vim.g.qf_rancher_ftplugin_demap then
    bufmap(0, "n", "<C-w>v", "<nop>", { noremap = true, nowait = true })
    bufmap(0, "n", "<C-w><C-v>", "<nop>", { noremap = true, nowait = true })
    bufmap(0, "n", "<C-w>s", "<nop>", { noremap = true, nowait = true })
    bufmap(0, "n", "<C-w><C-s>", "<nop>", { noremap = true, nowait = true })

    bufmap(0, "n", "<C-i>", "<nop>", { noremap = true, nowait = true })
    bufmap(0, "n", "<C-o>", "<nop>", { noremap = true, nowait = true })
end

if not vim.g.qf_rancher_ftplugin_keymap then return end

local in_loclist = fn.win_gettype(0) == "loclist" --- @type boolean
local ll_prefix = vim.g.qf_rancher_map_ll_prefix or "l" --- @type string
local qf_prefix = vim.g.qf_rancher_map_qf_prefix or "q" --- @type string
ll_prefix = type(ll_prefix) == "string" and ll_prefix or "l"
qf_prefix = type(qf_prefix) == "string" and qf_prefix or "q"
local list_prefix = in_loclist and ll_prefix or qf_prefix --- @type string

for _, lhs in ipairs({ "<leader>" .. list_prefix .. list_prefix, "q" }) do
    vim.keymap.set("n", lhs, function()
        eo._close_list(in_loclist and api.nvim_get_current_win() or nil)
    end, { buffer = true, nowait = true, desc = "Close the list" })
end

bufmap_plug("n", "dd", "<Plug>(qf-rancher-list-del-one)", "Delete the current list line")
bufmap_plug("x", "d", "<Plug>(qf-rancher-list-visual-del)", "Delete a visual line selection")

bufmap_plug("n", "p", "<Plug>(qf-rancher-list-toggle-preview)", "Toggle the preview win")
bufmap_plug("n", "P", "<Plug>(qf-rancher-list-update-preview-pos)", "Open the preview win")

if in_loclist then
    bufmap_plug("n", "<", "<Plug>(qf-rancher-ll-older)", "Go to an older location list")
    bufmap_plug("n", ">", "<Plug>(qf-rancher-ll-newer)", "Go to a newer location list")
else
    bufmap_plug("n", "<", "<Plug>(qf-rancher-qf-older)", "Go to an older qflist")
    bufmap_plug("n", ">", "<Plug>(qf-rancher-qf-newer)", "Go to a newer qflist")
end

bufmap_plug("n", "{", "<Plug>(qf-rancher-list-prev)", "Go to a previous list entry")
bufmap_plug("n", "}", "<Plug>(qf-rancher-list-next)", "Go to a later list entry")

local d_focuswin_desc = "Open a list item and focus on it" --- @type string
local d_focuslist_desc = "Open a list item, keep list focus" --- @type string
local s_focuswin_desc = "Open a list item in a split and focus on it" --- @type string
local s_focuslist_desc = "Open a list item in a split, keep list focus" --- @type string
local vs_focuswin_desc = "Open a list item in a vsplit and focus on it" --- @type string
local vs_focuslist_desc = "Open a list item in a vsplit, keep list focus" --- @type string
local t_focuswin_desc = "Open a list item in a new tab and focus on it" --- @type string
local t_focuslist_desc = "Open a list item in a new tab, keep list focus" --- @type string

bufmap_plug("n", "o", "<Plug>(qf-rancher-list-open-direct-focuswin)", d_focuswin_desc)
bufmap_plug("n", "<C-o>", "<Plug>(qf-rancher-list-open-direct-focuslist)", d_focuslist_desc)
bufmap_plug("n", "s", "<Plug>(qf-rancher-list-open-split-focuswin)", s_focuswin_desc)
bufmap_plug("n", "<C-s>", "<Plug>(qf-rancher-list-open-split-focuslist)", s_focuslist_desc)
bufmap_plug("n", "v", "<Plug>(qf-rancher-list-open-vsplit-focuswin)", vs_focuswin_desc)
bufmap_plug("n", "<C-v>", "<Plug>(qf-rancher-list-open-vsplit-focuslist)", vs_focuslist_desc)
bufmap_plug("n", "x", "<Plug>(qf-rancher-list-open-tabnew-focuswin)", t_focuswin_desc)
bufmap_plug("n", "<C-x>", "<Plug>(qf-rancher-list-open-tabnew-focuslist)", t_focuslist_desc)

-- TODO: Tests
-- TODO: Docs

-- LOW: Add an undo_ftplugin script

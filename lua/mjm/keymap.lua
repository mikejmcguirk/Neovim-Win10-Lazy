local km = require("mjm.keymap_mod")

---------------------
-- Mode Management --
---------------------

-- Do not map in command mode or else <C-c> will accept commands
vim.keymap.set({ "i", "v" }, "<C-c>", "<esc>", { silent = true })
vim.keymap.set({ "i", "v" }, "<C-C>", "<esc>", { silent = true })

vim.opt.spell = false
vim.opt.spelllang = "en_us"

vim.keymap.set("n", "<leader>st", function()
    vim.opt.spell = not vim.opt.spell:get()
end, { silent = true })

vim.keymap.set("n", "<leader>sn", function()
    vim.opt.spell = true
end, { silent = true })

vim.keymap.set("n", "<leader>sf", function()
    vim.opt.spell = false
end, { silent = true })

vim.api.nvim_create_user_command("We", "w | e", {})

vim.keymap.set("n", "gh", "<nop>")
vim.keymap.set("n", "gH", "<nop>")

vim.keymap.set("n", "ZZ", "<Nop>")
vim.keymap.set("n", "ZQ", "<Nop>")

vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "gQ", "<nop>")

vim.keymap.set({ "n", "v" }, "<C-z>", "<nop>")

vim.keymap.set("n", "=", "<nop>", { silent = true })

-----------------------
-- Window Management --
-----------------------

vim.keymap.set("n", "<leader>lv", "<cmd>vsplit<cr>", { silent = true })
vim.keymap.set("n", "<leader>lh", "<cmd>split<cr>", { silent = true })

vim.keymap.set("n", "<M-j>", "<cmd>resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-k>", "<cmd>resize +2<CR>", { silent = true })
vim.keymap.set("n", "<M-h>", "<cmd>vertical resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-l>", "<cmd>vertical resize +2<CR>", { silent = true })

-- Controlled through vim-tmux-navigator
-- vim.keymap.set("n", "<C-h>", "<C-w>h", { silent = true })
-- vim.keymap.set("n", "<C-j>", "<C-w>j", { silent = true })
-- vim.keymap.set("n", "<C-k>", "<C-w>k", { silent = true })
-- vim.keymap.set("n", "<C-l>", "<C-w>l", { silent = true })

---------------------
-- Scrolling Fixes --
---------------------

vim.keymap.set({ "n", "v" }, "<C-u>", "<C-u>zz", { silent = true })
vim.keymap.set({ "n", "v" }, "<C-d>", "<C-d>zz", { silent = true })

vim.keymap.set({ "n", "v" }, "n", "nzzzv", { silent = true })
vim.keymap.set({ "n", "v" }, "N", "Nzzzv", { silent = true })

-- vim.keymap.set({ "n", "v" }, "H", "<Nop>", { silent = true }) -- Used for a custom mapping
vim.keymap.set({ "n", "v" }, "M", "<Nop>", { silent = true })
vim.keymap.set({ "n", "v" }, "L", "<Nop>", { silent = true })

vim.keymap.set({ "n", "v" }, "z+", "<Nop>")
vim.keymap.set({ "n", "v" }, "z^", "<Nop>")
vim.keymap.set({ "n", "v" }, "z<cr>", "<Nop>")
vim.keymap.set({ "n", "v" }, "z.", "<Nop>")
vim.keymap.set({ "n", "v" }, "z-", "<Nop>")

vim.keymap.set({ "n", "v" }, "{", "<Nop>")
vim.keymap.set({ "n", "v" }, "}", "<Nop>")
vim.keymap.set({ "n", "v" }, "(", "<Nop>")
vim.keymap.set({ "n", "v" }, ")", "<Nop>")
vim.keymap.set({ "n", "v" }, "[m", "<Nop>")
vim.keymap.set({ "n", "v" }, "]m", "<Nop>")
vim.keymap.set({ "n", "v" }, "[M", "<Nop>")
vim.keymap.set({ "n", "v" }, "]M", "<Nop>")

vim.keymap.set({ "n", "v" }, "[[", "<Nop>")
vim.keymap.set({ "n", "v" }, "]]", "<Nop>")
vim.keymap.set({ "n", "v" }, "[]", "<Nop>")
vim.keymap.set({ "n", "v" }, "][", "<Nop>")

vim.keymap.set({ "n", "v" }, "gm", "<Nop>")
vim.keymap.set({ "n", "v" }, "gM", "<Nop>")
vim.keymap.set({ "n", "v" }, "|", "<Nop>")

vim.keymap.set({ "n", "v" }, "-", "<Nop>")
vim.keymap.set({ "n", "v" }, "+", "<Nop>")

vim.keymap.set({ "n", "v" }, "[*", "<Nop>")
vim.keymap.set({ "n", "v" }, "]*", "<Nop>")
vim.keymap.set({ "n", "v" }, "[/", "<Nop>")
vim.keymap.set({ "n", "v" }, "]/", "<Nop>")

--------------
-- QoL Maps --
--------------

local insert_maps = { "i", "a", "A" }

for _, map in pairs(insert_maps) do
    vim.keymap.set("n", map, function()
        return km.enter_insert_fix(map)
    end, { silent = true, expr = true })
end

vim.keymap.set("i", "<backspace>", function()
    km.insert_backspace_fix()
end, { silent = true })

vim.keymap.set("i", "<C-h>", "<nop>", { silent = true })

vim.keymap.set("i", ",", ",<C-g>u", { silent = true })
vim.keymap.set("i", ".", ".<C-g>u", { silent = true })
vim.keymap.set("i", ";", ";<C-g>u", { silent = true })
vim.keymap.set("i", "?", "?<C-g>u", { silent = true })
vim.keymap.set("i", "!", "!<C-g>u", { silent = true })
vim.keymap.set("i", ":", ":<C-g>u", { silent = true })

vim.keymap.set("n", "j", function()
    return km.vertical_motion_fix("gj", "j")
end, { silent = true, expr = true })

vim.keymap.set("n", "k", function()
    return km.vertical_motion_fix("gk", "k")
end, { silent = true, expr = true })

vim.keymap.set("v", "<", "<gv", { silent = true })
vim.keymap.set("v", ">", ">gv", { silent = true })

vim.keymap.set("n", "<leader>/", function()
    vim.cmd("noh")
    vim.lsp.buf.clear_references()
end, { silent = true })

vim.keymap.set("n", "gV", "`[v`]", { silent = true })
vim.keymap.set("n", "<leader>V", "_vg_", { silent = true })

---------------------------
-- Cursor Movement Fixes --
---------------------------

vim.keymap.set("n", "J", function()
    km.rest_cursor("J", { mod_check = true, rest_view = true })
end, { silent = true })

local cap_motions_norm = {
    "~",
    "guu",
    "guiw",
    "guiW",
    "gUU",
    "gUiw",
    "gUiW",
    "g~~",
    "g~iw",
    "g~IW",
}

for _, map in pairs(cap_motions_norm) do
    vim.keymap.set("n", map, function()
        local cmd = vim.v.count1 .. map
        km.rest_cursor(cmd, { mod_check = true })
    end, { silent = true })
end

local cap_motions_visual = {
    "~",
    "g~",
    "gu",
    "gU",
}

for _, map in pairs(cap_motions_visual) do
    vim.keymap.set("v", map, function()
        km.rest_cursor(map, { mod_check = true })
    end, { silent = true })
end

------------
-- Delete --
------------

vim.keymap.set({ "n", "v" }, "x", '"_x', { silent = true })
vim.keymap.set({ "n", "v" }, "X", '"_X', { silent = true })

vim.keymap.set("n", "dd", function()
    return km.dd_fix()
end, { silent = true, expr = true })

vim.keymap.set({ "n", "v" }, "<leader>d", '"_d', { silent = true })
vim.keymap.set("n", "<leader>D", '"_D', { silent = true })
vim.keymap.set("v", "D", "<nop>", { silent = true })

vim.keymap.set("n", "d^", "^dg_", { silent = true })
vim.keymap.set("n", "<leader>d^", '^"_dg_', { silent = true })

------------
-- Change --
------------

vim.keymap.set({ "n", "v" }, "<leader>c", '"_c', { silent = true })
vim.keymap.set("n", "<leader>C", '"_C', { silent = true })
vim.keymap.set("v", "C", "<nop>", { silent = true })

vim.keymap.set("n", "c^", "^cg_", { silent = true })
vim.keymap.set("n", "<leader>c^", '^"_cg_', { silent = true })

vim.keymap.set({ "n", "v" }, "s", "<Nop>", { silent = true })
-- vim.keymap.set("n", "S", "<Nop>", { silent = true }) -- Used in visual mode by nvim-surround

----------
-- Yank --
----------

vim.keymap.set("n", "Y", "y$", { silent = true }) -- Avoid inconsistent behavior

vim.keymap.set("v", "y", function()
    km.rest_cursor("y")
end, { silent = true })

vim.keymap.set("n", "<leader>y", '"+y', { silent = true })

vim.keymap.set("v", "<leader>y", function()
    km.rest_cursor('"+y')
end, { silent = true })

vim.keymap.set("n", "<leader>Y", '"+y$', { silent = true }) -- Mapping to "+Y yanks the whole line
vim.keymap.set("v", "Y", "<nop>", { silent = true })

vim.keymap.set("n", "y^", function()
    km.rest_cursor("^vg_y")
end, { silent = true })

vim.keymap.set("n", "<leader>y^", function()
    km.rest_cursor('^vg_"+y')
end, { silent = true })

local backward_objects = { "b", "B", "ge", "gE" }
km.fix_backward_yanks(backward_objects)

------------------------
-- Delete/Change/Yank --
------------------------

local motions = { "d", "c", "y" }
local nop_objects = { "b", "B", "s" } -- S is used by nvim-surround
local ia = { "i", "a" }
km.demap_text_objects_inout(motions, nop_objects, ia)

-- vim.keymap.set("n", "<leader>y0", 'mzv0"+y`z', { silent = false })
local startline_motions = { "0", "_", "g^", "g0" }
km.fix_startline_motions(motions, startline_motions)

local text_objects = { "<", '"', "'", "`", "(", "[", "{", "p" }
km.demap_text_objects(motions, text_objects)

table.insert(text_objects, "w")
table.insert(text_objects, "W")
table.insert(text_objects, "t")
km.yank_cursor_fixes(text_objects, ia)

-----------------
-- Paste Fixes --
-----------------

vim.keymap.set("n", "p", function()
    local cmd = vim.v.count1 .. "p"
    km.rest_cursor(cmd, { mod_check = true, rest_view = true })
end, { silent = true })

vim.keymap.set("n", "P", function()
    local cmd = vim.v.count1 .. "P"
    km.rest_cursor(cmd, { mod_check = true, rest_view = true })
end, { silent = true })

vim.keymap.set("n", "<leader>p", function()
    local cmd = vim.v.count1 .. '"+p'
    km.rest_cursor(cmd, { mod_check = true, rest_view = true })
end, { silent = true })

vim.keymap.set("n", "<leader>P", function()
    local cmd = vim.v.count1 .. '"+P'
    km.rest_cursor(cmd, { mod_check = true, rest_view = true })
end, { silent = true })

vim.keymap.set("n", "<leader>gp", '"+gp', { silent = true })
vim.keymap.set("n", "<leader>gP", '"+gP', { silent = true })

vim.keymap.set("v", "p", function()
    return km.visual_paste("P")
end, { silent = true, expr = true })

vim.keymap.set("v", "P", function()
    return km.visual_paste("p")
end, { silent = true, expr = true })

vim.keymap.set("v", "<leader>p", function()
    return km.visual_paste('"+P')
end, { silent = true, expr = true })

vim.keymap.set("v", "<leader>P", function()
    return km.visual_paste('"+p')
end, { silent = true, expr = true })

-----------------------
-- Text Manipulation --
-----------------------

vim.keymap.set("n", "[ ", function()
    km.create_blank_line("put!")
end, { silent = true })

vim.keymap.set("n", "] ", function()
    km.create_blank_line("put")
end, { silent = true })

vim.keymap.set("v", "J", function()
    km.visual_move(vim.v.count1, "'>", ".", 0, "'<,'> m '>+")
end, { silent = true })

vim.keymap.set("v", "K", function()
    km.visual_move(vim.v.count1, ".", "'<", 1, "'<,'> m '<-")
end, { silent = true })

vim.keymap.set("n", "<leader>=", function()
    km.bump_up()
end, { silent = true })

-- Same as J but with the line above. Keeps the cursor in the same place
-- Does not automatically reformat comment syntax
vim.keymap.set(
    "n",
    "H",
    'mz<cmd>let @y = @"<cr>k_"zD"_dd`zA<space><esc>"zp<cmd>let@" = @y<cr>`z',
    { silent = true }
)

-- Title Case Maps
vim.keymap.set(
    "n",
    "gllw",
    "mz<cmd> s/\\v<(.)(\\w*)/\\u\\1\\L\\2/ge<cr><cmd>noh<cr>`z",
    { silent = true }
)
vim.keymap.set(
    "n",
    "gllW",
    "mz<cmd> s/\\v<(.)(\\S*)/\\u\\1\\L\\2/ge<cr><cmd>noh<cr>`z",
    { silent = true }
)

vim.keymap.set("n", "gliw", "mzguiw~`z", { silent = true })
vim.keymap.set("n", "gliW", "mzguiW~`z", { silent = true })

vim.keymap.set("n", "<M-;>", function()
    km.put_at_end(";")
end, { silent = true })

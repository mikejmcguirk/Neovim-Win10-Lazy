local km = require("mjm.keymap_mod")

---------------------
-- Mode Management --
---------------------

vim.keymap.set({ "i", "v" }, "<C-c>", "<esc>", km.opts)
vim.keymap.set({ "i", "v" }, "<C-C>", "<esc>", km.opts)

vim.opt.spell = false
vim.opt.spelllang = "en_us"

vim.keymap.set("n", "<leader>st", function()
    vim.opt.spell = not vim.opt.spell:get()
end, km.opts)

vim.keymap.set("n", "<leader>sn", function()
    vim.opt.spell = true
end, km.opts)

vim.keymap.set("n", "<leader>sf", function()
    vim.opt.spell = false
end, km.opts)

vim.keymap.set("n", "gh", "<nop>")
vim.keymap.set("n", "gH", "<nop>")

vim.keymap.set("n", "ZZ", "<Nop>")
vim.keymap.set("n", "ZQ", "<Nop>")

vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "gQ", "<nop>")
vim.keymap.set("n", "q:", "<nop>")

vim.keymap.set({ "n", "v" }, "<C-z>", "<nop>")

vim.keymap.set("n", "=", "<nop>", km.opts)

-----------------------
-- Window Management --
-----------------------

vim.keymap.set("n", "<leader>lv", "<cmd>vsplit<cr>", km.opts)
vim.keymap.set("n", "<leader>lh", "<cmd>split<cr>", km.opts)

vim.keymap.set("n", "<M-j>", "<cmd>resize -2<CR>", km.opts)
vim.keymap.set("n", "<M-k>", "<cmd>resize +2<CR>", km.opts)
vim.keymap.set("n", "<M-h>", "<cmd>vertical resize -2<CR>", km.opts)
vim.keymap.set("n", "<M-l>", "<cmd>vertical resize +2<CR>", km.opts)

-- Controlled through vim-tmux-navigator
-- vim.keymap.set("n", "<C-h>", "<C-w>h", km.opts)
-- vim.keymap.set("n", "<C-j>", "<C-w>j", km.opts)
-- vim.keymap.set("n", "<C-k>", "<C-w>k", km.opts)
-- vim.keymap.set("n", "<C-l>", "<C-w>l", km.opts)

---------------------
-- Scrolling Fixes --
---------------------

vim.keymap.set({ "n", "v" }, "<C-u>", "<C-u>zz", km.opts)
vim.keymap.set({ "n", "v" }, "<C-d>", "<C-d>zz", km.opts)

vim.keymap.set({ "n", "v" }, "n", "nzzzv", km.opts)
vim.keymap.set({ "n", "v" }, "N", "Nzzzv", km.opts)

-- vim.keymap.set({ "n", "v" }, "H", "<Nop>", km.opts) -- Used for a custom mapping
vim.keymap.set({ "n", "v" }, "M", "<Nop>", km.opts)
vim.keymap.set({ "n", "v" }, "L", "<Nop>", km.opts)

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
    end, km.expr_opts)
end

vim.keymap.set("i", "<backspace>", function()
    km.insert_backspace_fix()
end, km.opts)

vim.keymap.set("i", "<C-h>", "<nop>", km.opts)

vim.keymap.set("i", ",", ",<C-g>u", km.opts)
vim.keymap.set("i", ".", ".<C-g>u", km.opts)
vim.keymap.set("i", ";", ";<C-g>u", km.opts)
vim.keymap.set("i", "?", "?<C-g>u", km.opts)
vim.keymap.set("i", "!", "!<C-g>u", km.opts)

vim.keymap.set("n", "j", function()
    return km.vertical_motion_fix("gj", "j")
end, km.expr_opts)

vim.keymap.set("n", "k", function()
    return km.vertical_motion_fix("gk", "k")
end, km.expr_opts)

vim.keymap.set("v", "<", "<gv", km.opts)
vim.keymap.set("v", ">", ">gv", km.opts)

vim.keymap.set("n", "<leader>/", "<cmd>noh<cr>", km.opts)

vim.keymap.set("n", "gV", "`[v`]", km.opts)
vim.keymap.set("n", "<leader>V", "_vg_", km.opts)

---------------------------
-- Cursor Movement Fixes --
---------------------------

vim.keymap.set("n", "J", function()
    km.rest_cursor("J", { mod_check = true, rest_view = true })
end, km.opts)

local cap_motions_norm = {
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

local cap_motions_visual = {
    "~",
    "g~",
    "gu",
    "gU",
}

for _, map in pairs(cap_motions_norm) do
    vim.keymap.set("n", map, function()
        local cmd = vim.v.count1 .. map
        km.rest_cursor(cmd, { mod_check = true })
    end, km.opts)
end

for _, map in pairs(cap_motions_visual) do
    vim.keymap.set("v", map, function()
        km.rest_cursor(map, { mod_check = true })
    end, km.opts)
end

------------
-- Delete --
------------

vim.keymap.set({ "n", "v" }, "x", '"_x', km.opts)
vim.keymap.set({ "n", "v" }, "X", '"_X', km.opts)

vim.keymap.set("n", "dd", function()
    return km.dd_fix()
end, km.expr_opts)

vim.keymap.set({ "n", "v" }, "<leader>d", '"_d', km.opts)
vim.keymap.set("n", "<leader>D", '"_D', km.opts)
vim.keymap.set("v", "D", "<nop>", km.opts)

vim.keymap.set("n", "d^", "^dg_", km.opts)
vim.keymap.set("n", "<leader>d^", '^"_dg_', km.opts)

------------
-- Change --
------------

vim.keymap.set({ "n", "v" }, "<leader>c", '"_c', km.opts)
vim.keymap.set("n", "<leader>C", '"_C', km.opts)
vim.keymap.set("v", "C", "<nop>", km.opts)

vim.keymap.set("n", "c^", "^cg_", km.opts)
vim.keymap.set("n", "<leader>c^", '^"_cg_', km.opts)

vim.keymap.set({ "n", "v" }, "s", "<Nop>", km.opts)
-- vim.keymap.set("n", "S", "<Nop>", km.opts) -- Used in visual mode by nvim-surround

----------
-- Yank --
----------

vim.keymap.set("n", "Y", "y$", km.opts) -- Avoid inconsistent behavior

vim.keymap.set("v", "y", function()
    km.rest_cursor("y")
end, km.opts)

vim.keymap.set("n", "<leader>y", '"+y', km.opts)

vim.keymap.set("v", "<leader>y", function()
    km.rest_cursor('"+y')
end, km.opts)

vim.keymap.set("n", "<leader>Y", '"+y$', km.opts) -- Mapping to "+Y yanks the whole line
vim.keymap.set("v", "Y", "<nop>", km.opts)

vim.keymap.set("n", "y^", function()
    km.rest_cursor("^vg_y")
end, km.opts)

vim.keymap.set("n", "<leader>y^", function()
    km.rest_cursor('^vg_"+y')
end, km.opts)

local backward_objects = { "b", "B", "ge", "gE" }
km.fix_backward_yanks(backward_objects)

------------------------
-- Delete/Change/Yank --
------------------------

local motions = { "d", "c", "y" }
local nop_objects = { "b", "B", "s" } -- S is used by nvim-surround
local ia = { "i", "a" }
km.demap_text_objects_inout(motions, nop_objects, ia)

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
end, km.opts)

vim.keymap.set("n", "P", function()
    local cmd = vim.v.count1 .. "P"
    km.rest_cursor(cmd, { mod_check = true, rest_view = true })
end, km.opts)

vim.keymap.set("n", "<leader>p", function()
    local cmd = vim.v.count1 .. '"+p'
    km.rest_cursor(cmd, { mod_check = true, rest_view = true })
end, km.opts)

vim.keymap.set("n", "<leader>P", function()
    local cmd = vim.v.count1 .. '"+P'
    km.rest_cursor(cmd, { mod_check = true, rest_view = true })
end, km.opts)

vim.keymap.set("n", "<leader>gp", '"+gp', km.opts)
vim.keymap.set("n", "<leader>gP", '"+gP', km.opts)

vim.keymap.set("v", "p", function()
    return km.visual_paste("P")
end, km.expr_opts)

vim.keymap.set("v", "P", function()
    return km.visual_paste("p")
end, km.expr_opts)

vim.keymap.set("v", "<leader>p", function()
    return km.visual_paste('"+P')
end, km.expr_opts)

vim.keymap.set("v", "<leader>P", function()
    return km.visual_paste('"+p')
end, km.expr_opts)

-----------------------
-- Text Manipulation --
-----------------------

vim.keymap.set("n", "[ ", function()
    km.create_blank_line("put!")
end, km.opts)

vim.keymap.set("n", "] ", function()
    km.create_blank_line("put")
end, km.opts)

vim.keymap.set("v", "J", function()
    km.visual_move(vim.v.count1, "'>", ".", 0, "'<,'> m '>+")
end, km.opts)

vim.keymap.set("v", "K", function()
    km.visual_move(vim.v.count1, ".", "'<", 1, "'<,'> m '<-")
end, km.opts)

vim.keymap.set("n", "<leader>=", function()
    km.bump_up()
end, km.opts)

-- Same as J but with the line above. Keeps the cursor in the same place
-- Does not automatically reformat comment syntax
vim.keymap.set(
    "n",
    "H",
    'mz<cmd>let @y = @"<cr>k_"zD"_dd`zA<space><esc>"zp<cmd>let@" = @y<cr>`z',
    km.opts
)

-- Title Case Maps
vim.keymap.set("n", "gllw", "mz<cmd> s/\\v<(.)(\\w*)/\\u\\1\\L\\2/ge<cr><cmd>noh<cr>`z", km.opts)
vim.keymap.set("n", "gllW", "mz<cmd> s/\\v<(.)(\\S*)/\\u\\1\\L\\2/ge<cr><cmd>noh<cr>`z", km.opts)

vim.keymap.set("n", "gliw", "mzguiw~`z", km.opts)
vim.keymap.set("n", "gliW", "mzguiW~`z", km.opts)

vim.keymap.set("n", "<M-;>", function()
    km.put_at_end(";")
end, km.opts)

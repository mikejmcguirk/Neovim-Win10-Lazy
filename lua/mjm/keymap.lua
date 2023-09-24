local opts = { noremap = true, silent = true }

------------------------------
-- Better Window Management --
------------------------------

vim.keymap.set("n", "<leader>lv", "<cmd>vsplit<cr>", opts)
vim.keymap.set("n", "<leader>lh", "<cmd>split<cr>", opts)

vim.keymap.set("n", "<C-h>", "<C-w>h", opts)
vim.keymap.set("n", "<C-j>", "<C-w>j", opts)
vim.keymap.set("n", "<C-k>", "<C-w>k", opts)
vim.keymap.set("n", "<C-l>", "<C-w>l", opts)

vim.keymap.set("n", "<M-j>", "<cmd>resize -2<CR>", opts)
vim.keymap.set("n", "<M-k>", "<cmd>resize +2<CR>", opts)
vim.keymap.set("n", "<M-h>", "<cmd>vertical resize -2<CR>", opts)
vim.keymap.set("n", "<M-l>", "<cmd>vertical resize +2<CR>", opts)

-------------------------
-- Visual Improvements --
-------------------------

vim.keymap.set("n", "J", "mzJ`z", opts)
vim.keymap.set("n", "<C-d>", "<C-d>zz", opts)
vim.keymap.set("n", "<C-u>", "<C-u>zz", opts)
vim.keymap.set("n", "n", "nzzzv", opts)
vim.keymap.set("n", "N", "Nzzzv", opts)

-------------------------------------------------
-- Copy/Paste Fixes --
-------------------------------------------------

vim.keymap.set({ "n", "v" }, "<leader>y", "\"+y", opts)
vim.keymap.set({ "n", "v" }, "<leader>Y", "\"+Y", opts)

vim.keymap.set("n", "<leader>p", "\"+p", opts)
vim.keymap.set("n", "<leader>P", "\"+P", opts)

vim.keymap.set("v", "p", "\"_dP", opts)
vim.keymap.set("v", "P", "\"_dP", opts)

vim.keymap.set("v", "<leader>p", "\"_d\"+P", opts)
vim.keymap.set("v", "<leader>P", "\"_d\"+P", opts)

---------------------------------
-- Delete to the void register --
---------------------------------

vim.keymap.set({ "n", "v" }, "<leader>x", "\"_x", opts)
vim.keymap.set({ "n", "v" }, "<leader>X", "\"_X", opts)

vim.keymap.set({ "n", "v" }, "<leader>d", "\"_d", opts)
vim.keymap.set({ "n", "v" }, "<leader>c", "\"_c", opts)
vim.keymap.set({ "n", "v" }, "<leader>D", "\"_D", opts)
vim.keymap.set({ "n", "v" }, "<leader>C", "\"_C", opts)

-----------------------
-- Text Manipulation --
-----------------------

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", opts)
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", opts)

vim.keymap.set("v", "<", "<gv", opts)
vim.keymap.set("v", ">", ">gv", opts)

-- Take the text from the cursor to the end of the current line and move it to a new line above
vim.keymap.set("n", "<leader>=", "v$hd<cmd>s/\\s\\+$//e<cr>O<esc>0\"_Dp==", opts)

-- Same as J but with the line above. Keeps the cursor in the same place
-- Does not automatically reformat comment syntax
vim.keymap.set("n", "H",
    "mz<cmd>let @y = @\"<cr>k_\"zD\"_dd`zA<space><esc>\"zp<cmd>let@\" = @y<cr>`z", opts)

vim.keymap.set("n", "[ ", "mzO<esc>0\"_D`z", opts)
vim.keymap.set("n", "] ", "mzo<esc>0\"_D`z", opts)

vim.keymap.set("n", "<M-;>", function()
    vim.cmd([[s/\s\+$//e]])

    if vim.api.nvim_get_current_line():sub(-1) == ";" then
        vim.cmd([[silent! normal! mz$"_x`z]])
    else
        vim.cmd([[:execute "normal! mzA;" | normal! `z]])
    end
end, opts)

-----------
-- Other --
-----------

local jkOpts = { noremap = true, expr = true, silent = true }

vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", jkOpts)
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", jkOpts)

vim.keymap.set("i", "<C-l>", "<C-o>l", opts)

-- In Visual Mode, select the last changed text (includes writes)
vim.keymap.set("n", "gp", "`[v`]", opts)

-- vim.keymap.set({ "n", "i", "v", "c" }, "<C-c>", "<esc>", opts)

vim.keymap.set("n", "Q", "<nop>", opts)

vim.keymap.set("n", "<leader>/", "<cmd>noh<cr>", opts)

vim.keymap.set("n", "<leader>st", function()
    if vim.opt.spell:get() then
        vim.opt.spell = false
        vim.opt.spelllang = ""
    else
        vim.opt.spell = true
        vim.opt.spelllang = "en_us"
    end
end)

vim.keymap.set("n", "<leader>sn", function()
    vim.opt.spell = true
    vim.opt.spelllang = "en_us"
end)

vim.keymap.set("n", "<leader>sf", function()
    vim.opt.spell = false
    vim.opt.spelllang = ""
end)

----------------------------------
-- Disable Various Default Maps --
----------------------------------

vim.keymap.set("n", "{", "<Nop>", opts)
vim.keymap.set("n", "}", "<Nop>", opts)
vim.keymap.set("n", "[m", "<Nop>", opts)
vim.keymap.set("n", "]m", "<Nop>", opts)
vim.keymap.set("n", "[M", "<Nop>", opts)
vim.keymap.set("n", "]M", "<Nop>", opts)

vim.keymap.set("n", "dib", "<Nop>", opts)
vim.keymap.set("n", "diB", "<Nop>", opts)
vim.keymap.set("n", "dab", "<Nop>", opts)
vim.keymap.set("n", "daB", "<Nop>", opts)

-- vim.keymap.set("n", "H", "<Nop>", opts) -- For reference only. Used for a custom mapping
vim.keymap.set("n", "M", "<Nop>", opts)
vim.keymap.set("n", "L", "<Nop>", opts)

vim.keymap.set({ "n", "v" }, "s", "<Nop>", opts)
vim.keymap.set("n", "S", "<Nop>", opts) -- Used in visual mode by vim-surround

vim.keymap.set("n", "g;", "<Nop>", opts)
vim.keymap.set("n", "g,", "<Nop>", opts)

vim.keymap.set({ "n", "v", "i" }, "<C-e>", "<Nop>", opts) -- scroll down one line and insertion
vim.keymap.set({ "n", "v" }, "<C-y>", "<Nop>", opts)      -- scroll up one line

vim.keymap.set({ "n", "v" }, "-", "<Nop>", opts)          -- cursor up one line (non-blank lines)
vim.keymap.set({ "n", "v" }, "<C-m>", "<Nop>", opts)      -- cursor down one line (non-blank lines)

vim.keymap.set({ "n", "v" }, "<C-p>", "<Nop>", opts)      -- cursor up one line
vim.keymap.set({ "n", "v" }, "<C-n>", "<Nop>", opts)      -- cursor down one line

vim.keymap.set({ "n", "v" }, "<C-f>", "<Nop>", opts)      -- scroll down one page
vim.keymap.set({ "n", "v" }, "<C-b>", "<Nop>", opts)      -- scroll up one page

-- alternate method to enter visual block mode
vim.keymap.set("n", "<C-q>", "<Nop>", opts)

vim.keymap.set("i", "<C-j>", "<Nop>", opts) -- enter

vim.keymap.set("i", "<C-v>", "<Nop>", opts)
vim.keymap.set("i", "<C-q>", "<Nop>", opts) -- paste from terminal
vim.keymap.set("i", "<C-s>", "<Nop>", opts)

vim.keymap.set("n", "ZZ", "<Nop>", opts)
vim.keymap.set("n", "ZQ", "<Nop>", opts)
vim.keymap.set("c", "<C-j>", "<Nop>", opts)

vim.keymap.set("n", "<C-6>", "<Nop>", opts)
vim.keymap.set("n", "<C-^>", "<Nop>", opts)

--Disable Non-Home Row Based Keys
vim.keymap.set({ "n", "i", "v", "c" }, "<up>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<down>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<left>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<right>", "<Nop>", opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<PageUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<PageDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<Home>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<End>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<Insert>", "<Nop>", opts)

-------------------
-- Disable Mouse --
-------------------

vim.opt.mouse = "a"           -- Otherwise, the terminal handles mouse functionality
vim.opt.mousemodel = "extend" -- Disables terminal right-click paste

vim.keymap.set({ "n", "i", "v", "c" }, "<LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<2-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<3-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<4-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-2-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-3-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-4-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-2-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-3-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-4-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-2-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-3-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-4-LeftMouse>", "<Nop>", opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<2-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<3-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<4-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<A-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<S-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-2-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-3-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-4-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-A-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-S-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-2-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-3-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-4-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-A-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-S-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-C-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-2-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-3-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-4-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-A-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-S-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-C-RightMouse>", "<Nop>", opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<LeftDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<RightDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<LeftRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<RightRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-LeftDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-RightDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-LeftRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-RightRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-LeftDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-RightDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-LeftRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-RightRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-LeftDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-RightDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-LeftRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-RightRelease>", "<Nop>", opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<2-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<3-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<4-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-2-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-3-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-4-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-2-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-3-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-4-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-2-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-3-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-4-MiddleMouse>", "<Nop>", opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<S-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<S-ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-S-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-S-ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-S-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-S-ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-S-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-S-ScrollWheelDown>", "<Nop>", opts)

local opts = { noremap = true, silent = true }

local keymap = vim.keymap.set

keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocaleader = " "

--Better Window Management
keymap("n", "<leader>lv", "<cmd>vsplit<cr>", opts)
keymap("n", "<leader>lh", "<cmd>split<cr>", opts)

keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

keymap("n", "<M-j>", "<cmd>resize -2<CR>", opts)
keymap("n", "<M-k>", "<cmd>resize +2<CR>", opts)
keymap("n", "<M-h>", "<cmd>vertical resize -2<CR>", opts)
keymap("n", "<M-l>", "<cmd>vertical resize +2<CR>", opts)

keymap("n", "<C-w>m", "<cmd>MaximizerToggle<cr>", opts)

--Visual Improvements
keymap("n", "J", "mzJ`z", opts)
keymap("n", "<C-d>", "<C-d>zz", opts)
keymap("n", "<C-u>", "<C-u>zz", opts)
keymap("n", "n", "nzzzv", opts)
keymap("n", "N", "Nzzzv", opts)

--Copy and paste to/from the system clipboard
keymap("n", "<leader>y", "\"+y", opts)
keymap("v", "<leader>y", "\"+y", opts)
keymap("n", "<leader>Y", "\"+Y", opts)
keymap("v", "<leader>Y", "\"+Y", opts)

keymap("n", "<leader>p", "\"+p", opts)
keymap("v", "<leader>p", "\"+p", opts)
keymap("n", "<leader>P", "\"+P", opts)
keymap("v", "<leader>P", "\"+P", opts)

--Delete to the void register
keymap({ "n", "v" }, "<leader>x", "\"_x", opts)
keymap({ "n", "v" }, "<leader>X", "\"_X", opts)

keymap("x", "p", "\"_dP", opts)

keymap({ "n", "v" }, "<leader>d", "\"_d", opts)
keymap({ "n", "v" }, "<leader>c", "\"_c", opts)
keymap({ "n", "v" }, "<leader>D", "\"_D", opts)
keymap({ "n", "v" }, "<leader>C", "\"_C", opts)

-------------------------------
-- Improve Text Manipulation --
-------------------------------

keymap("v", "J", ":m '>+1<CR>gv=gv", opts)
keymap("v", "K", ":m '<-2<CR>gv=gv", opts)

keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Take the text from the cursor to the end of the current line and paste it to a new line above
keymap("n", "<leader>=", "v$hd<cmd>s/\\s\\+$//e<cr>k$a<cr><esc>p==", opts)

-- Same as J but with the line above. Keeps the cursor in the same place
keymap("n", "H",
    "mz<cmd>let @y = @\"<cr>k_\"zD\"_dd`z$a<space><esc>\"zp<cmd>let@\" = @y<cr>`z", opts)

--Other
keymap('n', 'j', "v:count == 0 ? 'gj' : 'j'", { noremap = true, expr = true, silent = true })
keymap('n', 'k', "v:count == 0 ? 'gk' : 'k'", { noremap = true, expr = true, silent = true })

-- Select last changed text in visual mode
keymap("n", "gp", "`[v`]", opts)

keymap("n", "<C-c>", "<esc>", opts)

keymap("n", "Q", "<nop>", opts)
keymap("n", "q", "<nop>", opts)
keymap("n", "<leader>q", "q", opts)

keymap("n", "<leader>/", "<cmd>noh<cr>", opts)

--Disable Various Motions
keymap("n", "{", "<Nop>", opts)
keymap("n", "}", "<Nop>", opts)
keymap("n", "[m", "<Nop>", opts)
keymap("n", "]m", "<Nop>", opts)
keymap("n", "[M", "<Nop>", opts)
keymap("n", "]M", "<Nop>", opts)

keymap("n", "dib", "<Nop>", opts)
keymap("n", "diB", "<Nop>", opts)
keymap("n", "dab", "<Nop>", opts)
keymap("n", "daB", "<Nop>", opts)

-- keymap("n", "H", "<Nop>", opts) -- Used for a custom mapping
keymap("n", "M", "<Nop>", opts)
keymap("n", "L", "<Nop>", opts)

keymap({ "n", "v" }, "s", "<Nop>", opts)
-- Originally disabled because it goes to substitute. However,
-- vim-surround remaps this, so the disabling here is... disabled!
-- keymap({ "n", "v" }, "S", "<Nop>", opts)

keymap("n", "g;", "<Nop>", opts)
keymap("n", "g,", "<Nop>", opts)

keymap({ "n", "v", "i" }, "<C-e>", "<Nop>", opts) -- scroll down one line and insertion
keymap({ "n", "v" }, "<C-y>", "<Nop>", opts)      -- scroll up one line

keymap({ "n", "v" }, "-", "<Nop>", opts)          -- cursor up one line (non-blank lines)
keymap({ "n", "v" }, "<C-m>", "<Nop>", opts)      -- cursor down one line (non-blank lines)

keymap({ "n", "v" }, "<C-p>", "<Nop>", opts)      -- cursor up one line
keymap({ "n", "v" }, "<C-n>", "<Nop>", opts)      -- cursor down one line

keymap({ "n", "v" }, "<C-f>", "<Nop>", opts)      -- scroll down one page
keymap({ "n", "v" }, "<C-b>", "<Nop>", opts)      -- scroll up one page

keymap("n", "<C-q>", "<Nop>", opts) -- alternate method to enter visual block mode

keymap("i", "<C-j>", "<Nop>", opts) -- enter

keymap("i", "<C-v>", "<Nop>", opts) -- paste from terminal
keymap("i", "<C-q>", "<Nop>", opts) -- paste from terminal
keymap("i", "<C-s>", "<Nop>", opts) -- iunno
-- Disabled this to avoid conflicts with LSP signature help
-- keymap("i", "<C-k>", "<Nop>", opts) -- iunno

-- Disable Various Commands
keymap("n", "ZZ", "<Nop>", opts)
keymap("n", "ZQ", "<Nop>", opts)

--Disable Other Non-Home Row Based Keys
keymap({ "n", "i", "v", "c" }, "<up>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<down>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<left>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<right>", "<Nop>", opts)

keymap({ "n", "i", "v", "c" }, "<PageUp>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<PageDown>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<Home>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<End>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<Insert>", "<Nop>", opts)

--Disable Mouse
vim.opt.mouse = "a"           --makes nvim handle mouse instead of terminal
vim.opt.mousemodel = "extend" --disables terminal right click paste

keymap({ "n", "i", "v", "c" }, "<LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<2-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<3-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<4-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-2-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-3-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-4-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-2-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-3-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-4-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-2-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-3-LeftMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-4-LeftMouse>", "<Nop>", opts)

keymap({ "n", "i", "v", "c" }, "<RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<2-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<3-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<4-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<A-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<S-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-2-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-3-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-4-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-A-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-S-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-2-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-3-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-4-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-A-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-S-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-C-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-2-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-3-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-4-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-A-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-S-RightMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-C-RightMouse>", "<Nop>", opts)

keymap({ "n", "i", "v", "c" }, "<LeftDrag>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<RightDrag>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<LeftRelease>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<RightRelease>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-LeftDrag>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-RightDrag>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-LeftRelease>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-RightRelease>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-LeftDrag>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-RightDrag>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-LeftRelease>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-RightRelease>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-LeftDrag>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-RightDrag>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-LeftRelease>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-RightRelease>", "<Nop>", opts)

keymap({ "n", "i", "v", "c" }, "<MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<2-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<3-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<4-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-2-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-3-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-4-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-2-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-3-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-4-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-2-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-3-MiddleMouse>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-4-MiddleMouse>", "<Nop>", opts)

keymap({ "n", "i", "v", "c" }, "<ScrollWheelUp>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<S-ScrollWheelUp>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<ScrollWheelDown>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<S-ScrollWheelDown>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-ScrollWheelUp>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-S-ScrollWheelUp>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-ScrollWheelDown>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-S-ScrollWheelDown>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-ScrollWheelUp>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-S-ScrollWheelUp>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-ScrollWheelDown>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<M-S-ScrollWheelDown>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-ScrollWheelUp>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-S-ScrollWheelUp>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-ScrollWheelDown>", "<Nop>", opts)
keymap({ "n", "i", "v", "c" }, "<C-M-S-ScrollWheelDown>", "<Nop>", opts)

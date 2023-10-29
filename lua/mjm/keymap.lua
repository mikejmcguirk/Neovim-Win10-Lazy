vim.keymap.set({ "i", "v" }, "<C-c>", "<esc>", Opts)

vim.keymap.set("n", "<C-u>", "<C-u>zz", Opts)
vim.keymap.set("n", "<C-d>", "<C-d>zz", Opts)

vim.keymap.set("n", "<leader>lv", "<cmd>vsplit<cr>", Opts)
vim.keymap.set("n", "<leader>lh", "<cmd>split<cr>", Opts)

vim.keymap.set("n", "<M-j>", "<cmd>resize -2<CR>", Opts)
vim.keymap.set("n", "<M-k>", "<cmd>resize +2<CR>", Opts)
vim.keymap.set("n", "<M-h>", "<cmd>vertical resize -2<CR>", Opts)
vim.keymap.set("n", "<M-l>", "<cmd>vertical resize +2<CR>", Opts)

-- Controlled through vim-tmux-navigator
-- vim.keymap.set("n", "<C-h>", "<C-w>h", Opts)
-- vim.keymap.set("n", "<C-j>", "<C-w>j", Opts)
-- vim.keymap.set("n", "<C-k>", "<C-w>k", Opts)
-- vim.keymap.set("n", "<C-l>", "<C-w>l", Opts)

vim.keymap.set("n", "n", "nzzzv", Opts)
vim.keymap.set("n", "N", "Nzzzv", Opts)
vim.keymap.set("n", "<leader>/", "<cmd>noh<cr>", Opts)

vim.keymap.set("n", "J", "mzJ`z", Opts)

vim.keymap.set("v", "<", "<gv", Opts)
vim.keymap.set("v", ">", ">gv", Opts)

local jkOpts = { noremap = true, expr = true, silent = true }

vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", jkOpts)
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", jkOpts)
vim.keymap.set("n", "gj", "<Nop>", Opts)
vim.keymap.set("n", "gk", "<Nop>", Opts)

vim.keymap.set({ "n", "v" }, "x", "\"_x", Opts)
vim.keymap.set({ "n", "v" }, "X", "\"_X", Opts)

vim.keymap.set({ "n", "v" }, "<leader>d", "\"_d", Opts)
vim.keymap.set({ "n", "v" }, "<leader>D", "\"_D", Opts)

vim.keymap.set({ "n", "v" }, "<leader>c", "\"_c", Opts)
vim.keymap.set({ "n", "v" }, "<leader>C", "\"_C", Opts)

vim.keymap.set("n", "Y", "y$", Opts) -- Avoid inconsistent behavior
vim.keymap.set("v", "y", "mzy`z", Opts)
vim.keymap.set("v", "Y", "<nop>", Opts)

vim.keymap.set("n", "<leader>y", "\"+y", Opts)
vim.keymap.set("n", "<leader>Y", "\"+y$", Opts) -- Mapping to "+Y yanks the whole line
vim.keymap.set("v", "<leader>y", "mz\"+y`z", Opts)
vim.keymap.set("v", "<leader>Y", "<nop>", Opts)

local inner_outer = { "i", "a" }
local text_objects = { "w", "W", "t", "<", "\"", "'", "`", "(", "[", "{", "p" }

for _, object in pairs(text_objects) do
    for _, in_out in pairs(inner_outer) do
        local main_lhs = "y" .. in_out .. object
        local main_rhs = "mzy" .. in_out .. object .. "`z"
        vim.keymap.set("n", main_lhs, main_rhs, Opts)

        local ext_lhs = "<leader>y" .. in_out .. object
        local ext_rhs = "mz\"+y" .. in_out .. object .. "`z"
        vim.keymap.set("n", ext_lhs, ext_rhs, Opts)
    end

    if object ~= "w" and object ~= "W" then
        vim.keymap.set("n", "y" .. object, "<nop>", Opts)
        vim.keymap.set("n", "<leader>y" .. object, "<nop>", Opts)
    end
end

local commands = { "d", "c", "y" }
local nop_text_objects = { "b", "B", "s" }

for _, command in pairs(commands) do
    for _, nop_text_object in pairs(nop_text_objects) do
        for _, in_out in pairs(inner_outer) do
            vim.keymap.set("n", command .. in_out .. nop_text_object, "<Nop>", Opts)
        end

        if nop_text_object ~= "s" then -- vim-surround uses cs, ds, and ys
            vim.keymap.set("n", command .. nop_text_object, "<Nop>", Opts)
        end
    end
end

vim.keymap.set("n", "<leader>p", "\"+p", Opts)
vim.keymap.set("n", "<leader>P", "\"+P", Opts)

-- Alternative for the standard '"_dP' Visual Mode Paste fix
-- Avoids non-standard behavior when pasting in Visual Line Mode and
-- when pasting yanked lines from Nvim
local visual_paste = function(paste_char)
    local cur_mode = vim.fn.mode()

    vim.cmd("let @z = @\"")
    vim.api.nvim_feedkeys(paste_char, "n", true)

    vim.defer_fn(function()
        vim.cmd("let @\" = @z")
    end, 0) -- Wait until feedkeys is complete

    -- In this case, however, user input will be held until feedkeys is complete
    if cur_mode == "V" or cur_mode == "Vs" then
        vim.api.nvim_feedkeys("=`]", "n", true)
    end
end

local internal_paste = "p"
local external_paste = "\"+p"

vim.keymap.set("v", "p", function()
    visual_paste(internal_paste)
end, Opts)

vim.keymap.set("v", "P", function()
    visual_paste(internal_paste)
end, Opts)

vim.keymap.set("v", "<leader>p", function()
    visual_paste(external_paste)
end, Opts)

vim.keymap.set("v", "<leader>P", function()
    visual_paste(external_paste)
end, Opts)

vim.keymap.set("i", ",", ",<C-g>u", Opts)
vim.keymap.set("i", ".", ".<C-g>u", Opts)
vim.keymap.set("i", ";", ";<C-g>u", Opts)
vim.keymap.set("i", "?", "?<C-g>u", Opts)
vim.keymap.set("i", "!", "!<C-g>u", Opts)

vim.keymap.set("n", "~", "mz~`z", Opts)

vim.keymap.set("n", "guu", "mzguu`z", Opts)
vim.keymap.set("n", "guiw", "mzguiw`z", Opts)
vim.keymap.set("n", "guiW", "mzguiW`z", Opts)

vim.keymap.set("n", "gUU", "mzgUU`z", Opts)
vim.keymap.set("n", "gUiw", "mzgUiw`z", Opts)
vim.keymap.set("n", "gUiW", "mzgUiW`z", Opts)

vim.keymap.set("v", "gu", "mzgu`z", Opts)
vim.keymap.set("v", "gU", "mzgU`z", Opts)

-- Title Case Maps
vim.keymap.set("n", "gllw", "mz<cmd> s/\\v<(.)(\\w*)/\\u\\1\\L\\2/ge<cr><cmd>noh<cr>`z", Opts)
vim.keymap.set("n", "gllW", "mz<cmd> s/\\v<(.)(\\S*)/\\u\\1\\L\\2/ge<cr><cmd>noh<cr>`z", Opts)
vim.keymap.set("n", "gliw", "mzguiw~`z", Opts)
vim.keymap.set("n", "gliW", "mzguiW~`z", Opts)

vim.keymap.set("n", "[ ", "mzO<esc>0\"_D`z", Opts)
vim.keymap.set("n", "] ", "mzo<esc>0\"_D`z", Opts)

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", Opts)
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", Opts)

vim.keymap.set("n", "gp", "`[v`]", Opts)
vim.keymap.set("n", "<leader>V", "_vg_", Opts)

-- Take the text from the cursor to the end of the current line and move it to a new line above
vim.keymap.set("n", "<leader>=", "v$hd<cmd>s/\\s\\+$//e<cr>O<esc>0\"_Dp==", Opts)

-- Same as J but with the line above. Keeps the cursor in the same place
-- Does not automatically reformat comment syntax
vim.keymap.set(
    "n",
    "H",
    "mz<cmd>let @y = @\"<cr>k_\"zD\"_dd`zA<space><esc>\"zp<cmd>let@\" = @y<cr>`z",
    Opts
)

vim.keymap.set("n", "<M-;>", function()
    vim.cmd([[s/\s\+$//e]])

    if vim.api.nvim_get_current_line():sub(-1) == ";" then
        vim.cmd([[silent! normal! mz$"_x`z]])
    else
        vim.cmd([[:execute "normal! mzA;" | normal! `z]])
    end
end, Opts)

vim.opt.spell = false
vim.opt.spelllang = "en_us"

vim.keymap.set("n", "<leader>st", function()
    vim.opt.spell = not vim.opt.spell:get()
end)

vim.keymap.set("n", "<leader>sn", function()
    vim.opt.spell = true
end)

vim.keymap.set("n", "<leader>sf", function()
    vim.opt.spell = false
end)

vim.keymap.set("n", "ZZ", "<Nop>", Opts)
vim.keymap.set("n", "ZQ", "<Nop>", Opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<up>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<down>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<left>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<right>", "<Nop>", Opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<PageUp>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<PageDown>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<Home>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<End>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<Insert>", "<Nop>", Opts)

vim.keymap.set("n", "gh", "<nop>", Opts)
vim.keymap.set("n", "gH", "<nop>", Opts)

vim.keymap.set({ "n", "v" }, "s", "<Nop>", Opts)
vim.keymap.set("n", "S", "<Nop>", Opts) -- Used in visual mode by vim-surround

vim.keymap.set("n", "Q", "<nop>", Opts)

-- vim.keymap.set("n", "H", "<Nop>", Opts) -- Used for a custom mapping
vim.keymap.set({ "n", "v" }, "M", "<Nop>", Opts)
vim.keymap.set({ "n", "v" }, "t", "<Nop>", Opts)

vim.keymap.set("n", "{", "<Nop>", Opts)
vim.keymap.set("n", "}", "<Nop>", Opts)
vim.keymap.set("n", "[m", "<Nop>", Opts)
vim.keymap.set("n", "]m", "<Nop>", Opts)
vim.keymap.set("n", "[M", "<Nop>", Opts)
vim.keymap.set("n", "]M", "<Nop>", Opts)

vim.opt.mouse = "a"           -- Otherwise, the terminal handles mouse functionality
vim.opt.mousemodel = "extend" -- Disables terminal right-click paste

vim.keymap.set({ "n", "i", "v", "c" }, "<LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<2-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<3-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<4-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-2-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-3-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-4-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-2-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-3-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-4-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-2-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-3-LeftMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-4-LeftMouse>", "<Nop>", Opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<2-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<3-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<4-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<A-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<S-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-2-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-3-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-4-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-A-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-S-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-2-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-3-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-4-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-A-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-S-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-C-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-2-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-3-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-4-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-A-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-S-RightMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-C-RightMouse>", "<Nop>", Opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<LeftDrag>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<RightDrag>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<LeftRelease>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<RightRelease>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-LeftDrag>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-RightDrag>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-LeftRelease>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-RightRelease>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-LeftDrag>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-RightDrag>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-LeftRelease>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-RightRelease>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-LeftDrag>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-RightDrag>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-LeftRelease>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-RightRelease>", "<Nop>", Opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<2-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<3-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<4-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-2-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-3-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-4-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-2-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-3-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-4-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-2-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-3-MiddleMouse>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-4-MiddleMouse>", "<Nop>", Opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<ScrollWheelUp>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<S-ScrollWheelUp>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<ScrollWheelDown>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<S-ScrollWheelDown>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-ScrollWheelUp>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-S-ScrollWheelUp>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-ScrollWheelDown>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-S-ScrollWheelDown>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-ScrollWheelUp>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-S-ScrollWheelUp>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-ScrollWheelDown>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-S-ScrollWheelDown>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-ScrollWheelUp>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-S-ScrollWheelUp>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-ScrollWheelDown>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-S-ScrollWheelDown>", "<Nop>", Opts)

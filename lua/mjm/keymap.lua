local km = require("mjm.keymap_mod")

-- Do not map in command mode or else <C-c> will accept commands
vim.keymap.set({ "i", "v" }, "<C-c>", "<esc>", { silent = true })
vim.keymap.set({ "i", "v" }, "<C-C>", "<esc>", { silent = true })

vim.keymap.set("n", "<leader>st", function()
    vim.opt.spell = not vim.opt.spell:get()
end, { silent = true })

vim.keymap.set("n", "<leader>sn", "<cmd>set spell<cr>", { silent = true })
vim.keymap.set("n", "<leader>sf", "<cmd>set spell!<cr>", { silent = true })

vim.api.nvim_create_user_command("We", "w | e", {})

vim.keymap.set("n", "u", function()
    local cmd_string = "silent normal! " .. vim.v.count1 .. "u"
    vim.api.nvim_exec2(cmd_string, {})
end, { silent = true })

vim.keymap.set("n", "<C-r>", function()
    local cmd_string = 'silent exec "normal! ' .. vim.v.count1 .. '\\<C-r>"'
    vim.api.nvim_exec2(cmd_string, {})
end, { silent = true })

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

vim.keymap.set({ "n", "v" }, "<C-u>", "<C-u>zz", { silent = true })
vim.keymap.set({ "n", "v" }, "<C-d>", "<C-d>zz", { silent = true })

vim.keymap.set({ "n", "v" }, "n", "nzzzv", { silent = true })
vim.keymap.set({ "n", "v" }, "N", "Nzzzv", { silent = true })

local insert_maps = { "i", "a", "A" }

for _, map in pairs(insert_maps) do
    vim.keymap.set("n", map, function()
        if string.match(vim.api.nvim_get_current_line(), "^%s*$") then
            return '"_S'
        else
            return map
        end
    end, { silent = true, expr = true })
end

vim.keymap.set("i", "<backspace>", function()
    km.insert_backspace_fix()
end, { silent = true })

vim.keymap.set("i", ",", ",<C-g>u", { silent = true })
vim.keymap.set("i", ".", ".<C-g>u", { silent = true })
vim.keymap.set("i", ";", ";<C-g>u", { silent = true })
vim.keymap.set("i", "?", "?<C-g>u", { silent = true })
vim.keymap.set("i", "!", "!<C-g>u", { silent = true })
vim.keymap.set("i", ":", ":<C-g>u", { silent = true })

vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

vim.keymap.set("v", "<", "<gv", { silent = true })
vim.keymap.set("v", ">", ">gv", { silent = true })

vim.keymap.set("n", "<leader>/", function()
    vim.api.nvim_exec2("echo ''", {})
    vim.api.nvim_exec2("noh", {})
    vim.lsp.buf.clear_references()
end, { silent = true })

vim.keymap.set("n", "gV", "`[v`]", { silent = true })
vim.keymap.set("n", "<leader>V", "_vg_", { silent = true })

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

vim.keymap.set({ "n", "v" }, "x", '"_x', { silent = true })
vim.keymap.set({ "n", "v" }, "X", '"_X', { silent = true })

vim.keymap.set("n", "dd", function()
    if vim.v.count1 <= 1 and vim.api.nvim_get_current_line() == "" then
        return '"_dd'
    else
        return "dd"
    end
end, { silent = true, expr = true })

vim.keymap.set({ "n", "v" }, "<leader>d", '"_d', { silent = true })
vim.keymap.set("n", "<leader>D", '"_D', { silent = true })
vim.keymap.set("v", "D", "<nop>", { silent = true })
vim.keymap.set("n", "d^", '^dg_"_dd', { silent = true })

vim.keymap.set({ "n", "v" }, "<leader>c", '"_c', { silent = true })
vim.keymap.set("n", "<leader>C", '"_C', { silent = true })
vim.keymap.set("v", "C", "<nop>", { silent = true })
vim.keymap.set("n", "c^", "^cg_", { silent = true })

vim.keymap.set({ "n", "v" }, "s", "<Nop>", { silent = true })
-- vim.keymap.set("n", "S", "<Nop>", { silent = true }) -- Used in visual mode by nvim-surround

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

local motions = { "d", "c", "y" }
local nop_objects = { "b", "B", "s" } -- S is used by nvim-surround
local ia = { "i", "a" }
km.demap_text_objects_inout(motions, nop_objects, ia)

local startline_motions = { "0", "_", "g^", "g0" }
km.fix_startline_motions(motions, startline_motions)

local text_objects = { "<", '"', "'", "`", "(", "[", "{", "p" }
km.demap_text_objects(motions, text_objects)

table.insert(text_objects, "w")
table.insert(text_objects, "W")
table.insert(text_objects, "t")
km.yank_cursor_fixes(text_objects, ia)

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

vim.keymap.set("n", "[ ", function()
    km.create_blank_line(true)
end, { silent = true })

vim.keymap.set("n", "] ", function()
    km.create_blank_line(false)
end, { silent = true })

vim.keymap.set("v", "J", function()
    km.visual_move(vim.v.count1, "d")
end, { silent = true })

vim.keymap.set("v", "K", function()
    km.visual_move(vim.v.count1, "u")
end, { silent = true })

vim.keymap.set("n", "<leader>=", function()
    km.bump_up()
end, { silent = true })

vim.keymap.set("n", "<M-;>", function()
    km.put_at_end(";")
end, { silent = true })

vim.keymap.set("n", "gliw", "mzguiw~`z", { silent = true })
vim.keymap.set("n", "gliW", "mzguiW~`z", { silent = true })

vim.keymap.set("n", "gllw", function()
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})

    vim.api.nvim_exec2("s/\\v<(.)(\\w*)/\\u\\1\\L\\2/ge", {})
    vim.api.nvim_exec2("noh", {})
    vim.api.nvim_exec2("normal! `z", {})
end, { silent = true })

vim.keymap.set("n", "gllW", function()
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})

    vim.api.nvim_exec2("s/\\v<(.)(\\S*)/\\u\\1\\L\\2/ge", {})
    vim.api.nvim_exec2("noh", {})
    vim.api.nvim_exec2("normal! `z", {})
end, { silent = true })

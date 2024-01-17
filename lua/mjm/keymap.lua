local km = require("mjm.keymap_mod")

vim.keymap.set("n", "<C-c>", "<nop>", { silent = true })
-- Do not map in command mode or else <C-c> will accept commands
vim.keymap.set({ "i", "v" }, "<C-c>", "<esc>", { silent = true })

vim.keymap.set("n", "<leader>st", function()
    vim.opt.spell = not vim.opt.spell:get()
end, { silent = true })

vim.keymap.set("n", "<leader>sn", "<cmd>set spell<cr>", { silent = true })
vim.keymap.set("n", "<leader>sf", "<cmd>set spell!<cr>", { silent = true })

vim.api.nvim_create_user_command("We", "w | e", {})

-- These maps stop undo history from showing in the cmd line whever an undo/redo is performed
-- Done as functions because <cmd>'s do not work with v:count1
vim.keymap.set("n", "u", function()
    local cmd_string = "silent normal! " .. vim.v.count1 .. "u"
    vim.api.nvim_exec2(cmd_string, {})
end, { silent = true })

vim.keymap.set("n", "<C-r>", function()
    local cmd_string = 'silent exec "normal! ' .. vim.v.count1 .. '\\<C-r>"'
    vim.api.nvim_exec2(cmd_string, {})
end, { silent = true })

vim.keymap.set("n", "/", function()
    km.search_with_mark("/")
end, { silent = true })

vim.keymap.set("n", "?", function()
    km.search_with_mark("?")
end, { silent = true })

vim.keymap.set("n", "<leader>lv", "<cmd>rightbelow vsplit<cr>", { silent = true })
vim.keymap.set("n", "<leader>le", "<cmd>leftabove vsplit<cr>", { silent = true })
vim.keymap.set("n", "<leader>lo", "<cmd>topleft vsplit<cr>", { silent = true })
vim.keymap.set("n", "<leader>lr", "<cmd>botright vsplit<cr>", { silent = true })

vim.keymap.set("n", "<leader>lh", "<cmd>belowright split<cr>", { silent = true })
vim.keymap.set("n", "<leader>lf", "<cmd>leftabove split<cr>", { silent = true })
vim.keymap.set("n", "<leader>lt", "<cmd>topleft split<cr>", { silent = true })
vim.keymap.set("n", "<leader>li", "<cmd>botright split<cr>", { silent = true })

vim.keymap.set("n", "<leader>lc", "<cmd>wincmd o<cr>", { silent = true })

vim.keymap.set("n", "<M-j>", "<cmd>resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-k>", "<cmd>resize +2<CR>", { silent = true })
vim.keymap.set("n", "<M-h>", "<cmd>vertical resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-l>", "<cmd>vertical resize +2<CR>", { silent = true })

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
    km.rest_view("J", { mod_check = true })
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
        return "mz" .. vim.v.count1 .. map .. "`z"
    end, { silent = true, expr = true })
end

local cap_motions_visual = {
    "~",
    "g~",
    "gu",
    "gU",
}

for _, map in pairs(cap_motions_visual) do
    vim.keymap.set("v", map, function()
        return "mz" .. vim.v.count1 .. map .. "`z"
    end, { silent = true, expr = true })
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

vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("yank_reset_cursor", { clear = true }),
    callback = function()
        if vim.v.event.operator ~= "y" then
            return
        end

        vim.api.nvim_exec2("norm! `z", {})
    end,
})

vim.keymap.set("n", "y", "mzy", { silent = true })
vim.keymap.set("n", "<leader>y", 'mz"+y', { silent = true })
vim.keymap.set("n", "Y", "y$", { silent = true }) -- Avoid inconsistent behavior
vim.keymap.set("n", "<leader>Y", '"+y$', { silent = true }) -- Mapping to "+Y yanks the whole line

vim.keymap.set("v", "y", "mzy", { silent = true })
vim.keymap.set("v", "<leader>y", 'mz"+y', { silent = true })
vim.keymap.set("v", "Y", "<nop>", { silent = true })

vim.keymap.set("n", "y^", "mz^vg_y", { silent = true })
vim.keymap.set("n", "<leader>y^", 'mz^vg_"+y', { silent = true })
-- `z included in these maps to prevent visible scrolling before the autocmd is triggered
vim.keymap.set("n", "yY", "mzggyG`z", { silent = true })
vim.keymap.set("n", "<leader>yY", 'mzgg"+yG`z', { silent = true })

local startline_objects = { "0", "_", "g^", "g0" }

for _, obj in pairs(startline_objects) do
    vim.keymap.set("n", "y" .. obj, "mzv" .. obj .. "y", { silent = true })
    vim.keymap.set("n", "<leader>y" .. obj, "mzv" .. obj .. '"+y', { silent = true })

    vim.keymap.set("n", "d" .. obj, "mzv" .. obj .. "d", { silent = true })
    vim.keymap.set("n", "<leader>d" .. obj, "mzv" .. obj .. '"_d', { silent = true })

    vim.keymap.set("n", "c" .. obj, "mzv" .. obj .. "c", { silent = true })
    vim.keymap.set("n", "<leader>c" .. obj, "mzv" .. obj .. '"_c', { silent = true })
end

vim.keymap.set("n", "p", function()
    local cmd = vim.v.count1 .. "p"
    km.rest_view(cmd, { mod_check = true })
end, { silent = true })

vim.keymap.set("n", "<leader>p", function()
    local cmd = vim.v.count1 .. '"+p'
    km.rest_view(cmd, { mod_check = true })
end, { silent = true })

vim.keymap.set("n", "P", function()
    local cmd = vim.v.count1 .. "P"
    km.rest_view(cmd, { mod_check = true })
end, { silent = true })

vim.keymap.set("n", "<leader>P", function()
    local cmd = vim.v.count1 .. '"+P'
    km.rest_view(cmd, { mod_check = true })
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

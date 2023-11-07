local e21_msg = "E21: Cannot make changes, 'modifiable' is off"

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

local exprOpts = { noremap = true, expr = true, silent = true }

---@param single string
---@param multiple string
local vertical_motion = function(single, multiple)
    if vim.v.count == 0 then
        return single
    else
        return multiple
    end
end

vim.keymap.set("n", "j", function()
    return vertical_motion("gj", "j")
end, exprOpts)

vim.keymap.set("n", "k", function()
    return vertical_motion("gk", "k")
end, exprOpts)

vim.keymap.set("n", "gj", "<Nop>", Opts)
vim.keymap.set("n", "gk", "<Nop>", Opts)

vim.keymap.set({ "n", "v" }, "x", '"_x', Opts)
vim.keymap.set({ "n", "v" }, "X", '"_X', Opts)

vim.keymap.set("n", "dd", function()
    if not vim.api.nvim_buf_get_option(0, "modifiable") then
        vim.api.nvim_err_writeln(e21_msg)
        return
    end

    if vim.api.nvim_get_current_line() == "" then
        vim.api.nvim_del_current_line()
    else
        vim.cmd("delete")
    end
end, Opts)

vim.keymap.set({ "n", "v" }, "<leader>d", '"_d', Opts)
vim.keymap.set({ "n", "v" }, "<leader>D", '"_D', Opts)

vim.keymap.set({ "n", "v" }, "<leader>c", '"_c', Opts)
vim.keymap.set({ "n", "v" }, "<leader>C", '"_C', Opts)

vim.keymap.set("n", "Y", "y$", Opts) -- Avoid inconsistent behavior
vim.keymap.set("v", "y", "mzy`z", Opts)
vim.keymap.set("v", "Y", "<nop>", Opts)

vim.keymap.set("n", "<leader>y", '"+y', Opts)
vim.keymap.set("n", "<leader>Y", '"+y$', Opts) -- Mapping to "+Y yanks the whole line
vim.keymap.set("v", "<leader>y", 'mz"+y`z', Opts)
vim.keymap.set("v", "<leader>Y", "<nop>", Opts)

local inner_outer = { "i", "a" }
local text_objects = { "w", "W", "t", "<", '"', "'", "`", "(", "[", "{", "p" }

for _, object in pairs(text_objects) do
    for _, in_out in pairs(inner_outer) do
        local main_lhs = "y" .. in_out .. object
        local main_rhs = "mzy" .. in_out .. object .. "`z"
        vim.keymap.set("n", main_lhs, main_rhs, Opts)

        local ext_lhs = "<leader>y" .. in_out .. object
        local ext_rhs = 'mz"+y' .. in_out .. object .. "`z"
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

vim.keymap.set("n", "<leader>p", '"+p', Opts)
vim.keymap.set("n", "<leader>P", '"+P', Opts)

-- Unlike the traditional '"_dP' map, this function does not alter default visual paste behavior
---@param paste_char string
local visual_paste = function(paste_char)
    if not vim.api.nvim_buf_get_option(0, "modifiable") then
        vim.api.nvim_err_writeln(e21_msg)
        return
    end

    local paste_cmd = '<esc><cmd>let @z = @"<cr>gv' .. paste_char .. '<cmd>let @" = @z<cr>'
    local cur_mode = vim.fn.mode()

    if cur_mode == "V" or cur_mode == "Vs" then
        return paste_cmd .. "=`]"
    else
        return paste_cmd
    end
end

local internal_paste = "p"
local external_paste = '"+p'

vim.keymap.set("v", "p", function()
    return visual_paste(internal_paste)
end, exprOpts)

vim.keymap.set("v", "P", function()
    return visual_paste(internal_paste)
end, exprOpts)

vim.keymap.set("v", "<leader>p", function()
    return visual_paste(external_paste)
end, exprOpts)

vim.keymap.set("v", "<leader>P", function()
    return visual_paste(external_paste)
end, exprOpts)

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

vim.keymap.set("n", "g~iw", "mzgUiw`z", Opts)
vim.keymap.set("n", "g~iW", "mzgUiW`z", Opts)

vim.keymap.set("v", "gu", "mzgu`z", Opts)
vim.keymap.set("v", "gU", "mzgU`z", Opts)

-- Title Case Maps
vim.keymap.set("n", "gllw", "mz<cmd> s/\\v<(.)(\\w*)/\\u\\1\\L\\2/ge<cr><cmd>noh<cr>`z", Opts)
vim.keymap.set("n", "gllW", "mz<cmd> s/\\v<(.)(\\S*)/\\u\\1\\L\\2/ge<cr><cmd>noh<cr>`z", Opts)
vim.keymap.set("n", "gliw", "mzguiw~`z", Opts)
vim.keymap.set("n", "gliW", "mzguiW~`z", Opts)

---@param put_cmd string
local function create_line(put_cmd)
    if not vim.api.nvim_buf_get_option(0, "modifiable") then
        vim.api.nvim_err_writeln(e21_msg)
        return
    end

    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})

    vim.cmd(put_cmd .. " =repeat(nr2char(10), v:count1)")
    vim.cmd("normal! `z")
end

vim.keymap.set("n", "[ ", function()
    create_line("put!")
end, Opts)

vim.keymap.set("n", "] ", function()
    create_line("put")
end, Opts)

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", Opts)
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", Opts)

vim.keymap.set("n", "gp", "`[v`]", Opts)
vim.keymap.set("n", "<leader>V", "_vg_", Opts)

vim.keymap.set("n", "<leader>=", function()
    local orig_line = vim.api.nvim_get_current_line()
    local orig_line_len = #orig_line
    local cursor = vim.api.nvim_win_get_cursor(0)

    local modified_line = orig_line:sub(1, cursor[2]):gsub("%s+$", "")
    local to_move = orig_line:sub(cursor[2] + 1, orig_line_len):gsub("^%s+", ""):gsub("%s+$", "")

    vim.api.nvim_set_current_line(modified_line)
    vim.cmd("put! =''")
    local row = cursor[1] - 1
    vim.api.nvim_buf_set_text(0, row, 0, row, 0, { to_move })
end, Opts)

-- Same as J but with the line above. Keeps the cursor in the same place
-- Does not automatically reformat comment syntax
vim.keymap.set(
    "n",
    "H",
    'mz<cmd>let @y = @"<cr>k_"zD"_dd`zA<space><esc>"zp<cmd>let@" = @y<cr>`z',
    Opts
)

---@param chars string
local function put_at_beginning(chars)
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local row = cursor_pos[1] - 1

    local current_line = vim.api.nvim_get_current_line()
    local chars_len = #chars
    local start_chars = current_line:sub(1, chars_len)

    if start_chars ~= chars then
        vim.api.nvim_buf_set_text(0, row, 0, row, 0, { chars })
    else
        vim.api.nvim_set_current_line(current_line:sub((chars_len + 1), current_line:len()))
    end
end

---@param chars string
local function put_at_end(chars)
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local row = cursor_pos[1] - 1
    local current_line = vim.api.nvim_get_current_line()
    local cline_cleaned = current_line:gsub("%s+$", "")
    local col = #cline_cleaned

    local chars_len = #chars
    local end_chars = cline_cleaned:sub(-chars_len)

    if end_chars ~= chars then
        vim.api.nvim_buf_set_text(0, row, col, row, col, { chars })
    else
        vim.api.nvim_set_current_line(cline_cleaned:sub(1, cline_cleaned:len() - chars_len))
    end
end

vim.keymap.set("n", "<M-;>", function()
    put_at_end(";")
end, Opts)

vim.opt.spell = false
vim.opt.spelllang = "en_us"

vim.keymap.set("n", "<leader>st", function()
    vim.opt.spell = not vim.opt.spell:get()
end, Opts)

vim.keymap.set("n", "<leader>sn", function()
    vim.opt.spell = true
end, Opts)

vim.keymap.set("n", "<leader>sf", function()
    vim.opt.spell = false
end, Opts)

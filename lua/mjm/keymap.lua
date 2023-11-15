local exprOpts = vim.tbl_extend("force", { expr = true }, Opts)

local is_modifiable = function()
    if not vim.api.nvim_buf_get_option(0, "modifiable") then
        local e21_msg = "E21: Cannot make changes, 'modifiable' is off"
        vim.api.nvim_err_writeln(e21_msg)

        return false
    end

    return true
end

local cursorfix = function(map)
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.cmd("normal! " .. map)
    vim.api.nvim_win_set_cursor(0, { cur_row, cur_col })
end

local cursorfix_writeonly = function(map)
    if is_modifiable() then
        cursorfix(map)
    end
end

local cursorfix_writeonly_restore = function(map)
    if is_modifiable() then
        local cur_view = vim.fn.winsaveview()
        cursorfix(map)
        vim.fn.winrestview(cur_view)
    end
end

---------------------
-- Mode Management --
---------------------

vim.keymap.set({ "i", "v" }, "<C-c>", "<esc>", Opts)
vim.keymap.set({ "i", "v" }, "<C-C>", "<esc>", Opts)

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

vim.keymap.set("n", "gh", "<nop>", Opts)
vim.keymap.set("n", "gH", "<nop>", Opts)

vim.keymap.set("n", "ZZ", "<Nop>", Opts)
vim.keymap.set("n", "ZQ", "<Nop>", Opts)

vim.keymap.set("n", "Q", "<nop>", Opts)
vim.keymap.set("n", "gQ", "<nop>", Opts)

vim.keymap.set({ "n", "v" }, "<C-z>", "<nop>", Opts)

-----------------------
-- Window Management --
-----------------------

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

---------------------
-- Scrolling Fixes --
---------------------

vim.keymap.set("n", "<C-u>", "<C-u>zz", Opts)
vim.keymap.set("n", "<C-d>", "<C-d>zz", Opts)

vim.keymap.set("n", "n", "nzzzv", Opts)
vim.keymap.set("n", "N", "Nzzzv", Opts)

-- vim.keymap.set({ "n", "v" }, "H", "<Nop>", Opts) -- Used for a custom mapping
vim.keymap.set({ "n", "v" }, "M", "<Nop>", Opts)
vim.keymap.set({ "n", "v" }, "L", "<Nop>", Opts)

vim.keymap.set("n", "{", "<Nop>", Opts)
vim.keymap.set("n", "}", "<Nop>", Opts)
vim.keymap.set("n", "[m", "<Nop>", Opts)
vim.keymap.set("n", "]m", "<Nop>", Opts)
vim.keymap.set("n", "[M", "<Nop>", Opts)
vim.keymap.set("n", "]M", "<Nop>", Opts)

vim.keymap.set("n", "[[", "<Nop>", Opts)
vim.keymap.set("n", "]]", "<Nop>", Opts)
vim.keymap.set("n", "[]", "<Nop>", Opts)
vim.keymap.set("n", "][", "<Nop>", Opts)

--------------
-- QoL Maps --
--------------

vim.keymap.set("i", ",", ",<C-g>u", Opts)
vim.keymap.set("i", ".", ".<C-g>u", Opts)
vim.keymap.set("i", ";", ";<C-g>u", Opts)
vim.keymap.set("i", "?", "?<C-g>u", Opts)
vim.keymap.set("i", "!", "!<C-g>u", Opts)

---@param vcount number
---@param single string
---@param multiple string
local vertical_motion = function(vcount, single, multiple)
    if vcount == 0 then
        return single
    else
        return multiple
    end
end

vim.keymap.set("n", "j", function()
    return vertical_motion(vim.v.count, "gj", "j")
end, exprOpts)

vim.keymap.set("n", "k", function()
    return vertical_motion(vim.v.count, "gk", "k")
end, exprOpts)

vim.keymap.set("v", "<", "<gv", Opts)
vim.keymap.set("v", ">", ">gv", Opts)

vim.keymap.set("n", "<leader>/", "<cmd>noh<cr>", Opts)

vim.keymap.set("n", "gV", "`[v`]", Opts)
vim.keymap.set("n", "<leader>V", "_vg_", Opts)

---------------------------
-- Cursor Movement Fixes --
---------------------------

vim.keymap.set("n", "J", function()
    cursorfix_writeonly_restore("J")
end, Opts)

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
        local cmd = vim.v.count .. map
        cursorfix_writeonly(cmd)
    end, Opts)
end

for _, map in pairs(cap_motions_visual) do
    vim.keymap.set("v", map, function()
        cursorfix_writeonly(map)
    end, Opts)
end

------------------------
-- Delete/Change/Yank --
------------------------

vim.keymap.set({ "n", "v" }, "x", '"_x', Opts)
vim.keymap.set({ "n", "v" }, "X", '"_X', Opts)

vim.keymap.set("n", "dd", function()
    local count = vim.v.count1
    local cur_line = vim.api.nvim_get_current_line()

    if count <= 1 and cur_line == "" then
        return '"_dd'
    else
        return "dd"
    end
end, exprOpts)

local change_del_fixes = function(lower, upper)
    vim.keymap.set({ "n", "v" }, "<leader>" .. lower, '"_' .. lower, Opts)
    vim.keymap.set("n", "<leader>" .. upper, '"_' .. upper, Opts)
    vim.keymap.set("v", upper, "<nop>", Opts)
end

change_del_fixes("d", "D")
change_del_fixes("c", "C")

vim.keymap.set("n", "Y", "y$", Opts) -- Avoid inconsistent behavior

vim.keymap.set("v", "y", function()
    cursorfix("y")
end, Opts)

vim.keymap.set("n", "<leader>y", '"+y', Opts)

vim.keymap.set("v", "<leader>y", function()
    cursorfix('"+y')
end, Opts)

vim.keymap.set("n", "y_", function()
    cursorfix("^vg_y")
end, Opts)

vim.keymap.set("n", "<leader>Y", '"+y$', Opts) -- Mapping to "+Y yanks the whole line
vim.keymap.set("v", "Y", "<nop>", Opts)

local backward_objects = { "b", "B", "ge", "gE" }

for _, object in pairs(backward_objects) do
    local main_map = "y" .. object

    vim.keymap.set("n", main_map, function()
        local main_cmd = vim.v.count1 .. main_map
        cursorfix(main_cmd)
    end, Opts)

    local ext_map = "<leader>y" .. object

    vim.keymap.set("n", ext_map, function()
        local ext_cmd = vim.v.count1 .. '"+' .. main_map
        cursorfix(ext_cmd)
    end, Opts)
end

local text_objects = { "<", '"', "'", "`", "(", "[", "{", "p" }

for _, object in pairs(text_objects) do
    vim.keymap.set("n", "y" .. object, "<nop>", Opts)
    vim.keymap.set("n", "<leader>y" .. object, "<nop>", Opts)
end

table.insert(text_objects, "w")
table.insert(text_objects, "W")
table.insert(text_objects, "t")

local inner_outer = { "i", "a" }

for _, object in pairs(text_objects) do
    for _, in_out in pairs(inner_outer) do
        local main_cmd = "y" .. in_out .. object

        vim.keymap.set("n", main_cmd, function()
            cursorfix(main_cmd)
        end, Opts)

        local ext_map = "<leader>y" .. in_out .. object
        local ext_cmd = '"+' .. main_cmd

        vim.keymap.set("n", ext_map, function()
            cursorfix(ext_cmd)
        end, Opts)
    end
end

local commands = { "d", "c", "y" }
local nop_text_objects = { "b", "B", "s" }

for _, command in pairs(commands) do
    for _, nop_text_object in pairs(nop_text_objects) do
        for _, in_out in pairs(inner_outer) do
            vim.keymap.set("n", command .. in_out .. nop_text_object, "<Nop>", Opts)
        end
    end
end

vim.keymap.set({ "n", "v" }, "s", "<Nop>", Opts)
vim.keymap.set("n", "S", "<Nop>", Opts) -- Used in visual mode by vim-surround

-----------------
-- Paste Fixes --
-----------------

vim.keymap.set("n", "p", function()
    local cmd = vim.v.count1 .. "p"
    cursorfix_writeonly_restore(cmd)
end, Opts)

vim.keymap.set("n", "P", function()
    local cmd = vim.v.count1 .. "P"
    cursorfix_writeonly_restore(cmd)
end, Opts)

vim.keymap.set("n", "<leader>p", function()
    local cmd = vim.v.count1 .. '"+p'
    cursorfix_writeonly_restore(cmd)
end, Opts)

vim.keymap.set("n", "<leader>P", function()
    local cmd = vim.v.count1 .. '"+P'
    cursorfix_writeonly_restore(cmd)
end, Opts)

vim.keymap.set("n", "<leader>gp", '"+gp', Opts)
vim.keymap.set("n", "<leader>gP", '"+gP', Opts)

---@param paste_char string
local visual_paste = function(paste_char)
    if not is_modifiable() then
        return ""
    end

    local cur_mode = vim.fn.mode()

    if cur_mode == "V" or cur_mode == "Vs" then
        return paste_char .. "=`]"
    else
        return "mz" .. paste_char .. "`z"
    end
end

vim.keymap.set("v", "p", function()
    return visual_paste("P")
end, exprOpts)

vim.keymap.set("v", "P", function()
    return visual_paste("p")
end, exprOpts)

vim.keymap.set("v", "<leader>p", function()
    return visual_paste('"+P')
end, exprOpts)

vim.keymap.set("v", "<leader>P", function()
    return visual_paste('"+p')
end, exprOpts)

-----------------------
-- Text Manipulation --
-----------------------

---@param put_cmd string
local function create_blank_line(put_cmd)
    if not is_modifiable() then
        return
    end

    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    -- Uses a mark so that the cursor sticks with the text the map is called from
    vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})

    vim.cmd(put_cmd .. " =repeat(nr2char(10), v:count1)")
    vim.cmd("normal! `z")
end

vim.keymap.set("n", "[ ", function()
    create_blank_line("put!")
end, Opts)

vim.keymap.set("n", "] ", function()
    create_blank_line("put")
end, Opts)

---@param count number
---@param min_count number
---@param pos_1 string
---@param pos_2 string
---@param fix_num number
---@param cmd_start string
---@return nil
local visual_move = function(count, min_count, pos_1, pos_2, fix_num, cmd_start)
    if not is_modifiable() then
        return
    end

    vim.cmd([[execute "normal! \<esc>"]])

    local get_to_move = function()
        if count <= min_count then
            return min_count
        else
            return count - (vim.fn.line(pos_1) - vim.fn.line(pos_2)) + fix_num
        end
    end

    local to_move = get_to_move()
    vim.cmd(cmd_start .. to_move)

    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))

    vim.cmd("normal! `]")
    local end_cursor_pos = vim.api.nvim_win_get_cursor(0)
    local end_row = end_cursor_pos[1]
    local end_line = vim.api.nvim_get_current_line()
    local end_col = #end_line
    vim.api.nvim_buf_set_mark(0, "z", end_row, end_col, {})

    vim.cmd("normal! `[")
    local start_cursor_pos = vim.api.nvim_win_get_cursor(0)
    local start_row = start_cursor_pos[1]
    vim.api.nvim_win_set_cursor(0, { start_row, 0 })

    vim.cmd("normal! =`z")
    vim.api.nvim_win_set_cursor(0, { cur_row, cur_col })
    vim.cmd("normal! gv")
end

vim.keymap.set("v", "J", function()
    visual_move(vim.v.count1, 1, "'>", ".", 0, "'<,'> m '>+")
end, Opts)

vim.keymap.set("v", "K", function()
    visual_move(vim.v.count1, 2, ".", "'<", 1, "'<,'> m '<-")
end, Opts)

vim.keymap.set("n", "<leader>=", function()
    if not is_modifiable() then
        return
    end

    local orig_line = vim.api.nvim_get_current_line()
    local orig_line_len = #orig_line
    local cursor = vim.api.nvim_win_get_cursor(0)

    local modified_line = orig_line:sub(1, cursor[2]):gsub("%s+$", "")
    local to_move = orig_line:sub(cursor[2] + 1, orig_line_len):gsub("^%s+", ""):gsub("%s+$", "")

    vim.api.nvim_set_current_line(modified_line)
    vim.cmd("put! =''")
    local row = cursor[1] - 1
    vim.api.nvim_buf_set_text(0, row, 0, row, 0, { to_move })
    vim.cmd("normal! ==")
end, Opts)

-- Same as J but with the line above. Keeps the cursor in the same place
-- Does not automatically reformat comment syntax
vim.keymap.set(
    "n",
    "H",
    'mz<cmd>let @y = @"<cr>k_"zD"_dd`zA<space><esc>"zp<cmd>let@" = @y<cr>`z',
    Opts
)

-- Title Case Maps
vim.keymap.set("n", "gllw", "mz<cmd> s/\\v<(.)(\\w*)/\\u\\1\\L\\2/ge<cr><cmd>noh<cr>`z", Opts)
vim.keymap.set("n", "gllW", "mz<cmd> s/\\v<(.)(\\S*)/\\u\\1\\L\\2/ge<cr><cmd>noh<cr>`z", Opts)

vim.keymap.set("n", "gliw", "mzguiw~`z", Opts)
vim.keymap.set("n", "gliW", "mzguiW~`z", Opts)

---@param chars string
local function put_at_beginning(chars)
    if not is_modifiable() then
        return
    end

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
    if not is_modifiable() then
        return
    end

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

-----------------------------------
-- Disable Non-Home Row Movement --
-----------------------------------

vim.keymap.set({ "n", "i", "v" }, "<up>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v" }, "<down>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v" }, "<left>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v" }, "<right>", "<Nop>", Opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<PageUp>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<PageDown>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<Home>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<End>", "<Nop>", Opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<Insert>", "<Nop>", Opts)

vim.opt.mouse = "a" -- Otherwise, the terminal handles mouse functionality
vim.opt.mousemodel = "extend" -- Disables terminal right-click paste

local mouse_maps = {
    "LeftMouse",
    "2-LeftMouse",
    "3-LeftMouse",
    "4-LeftMouse",
    "C-LeftMouse",
    "C-2-LeftMouse",
    "C-3-LeftMouse",
    "C-4-LeftMouse",
    "M-LeftMouse",
    "M-2-LeftMouse",
    "M-3-LeftMouse",
    "M-4-LeftMouse",
    "C-M-LeftMouse",
    "C-M-2-LeftMouse",
    "C-M-3-LeftMouse",
    "C-M-4-LeftMouse",
    "RightMouse",
    "2-RightMouse",
    "3-RightMouse",
    "4-RightMouse",
    "A-RightMouse",
    "S-RightMouse",
    "C-RightMouse",
    "C-2-RightMouse",
    "C-3-RightMouse",
    "C-4-RightMouse",
    "C-A-RightMouse",
    "C-S-RightMouse",
    "M-RightMouse",
    "M-2-RightMouse",
    "M-3-RightMouse",
    "M-4-RightMouse",
    "M-A-RightMouse",
    "M-S-RightMouse",
    "M-C-RightMouse",
    "C-M-RightMouse",
    "C-M-2-RightMouse",
    "C-M-3-RightMouse",
    "C-M-4-RightMouse",
    "C-M-A-RightMouse",
    "C-M-S-RightMouse",
    "C-M-C-RightMouse",
    "LeftDrag",
    "RightDrag",
    "LeftRelease",
    "RightRelease",
    "C-LeftDrag",
    "C-RightDrag",
    "C-LeftRelease",
    "C-RightRelease",
    "M-LeftDrag",
    "M-RightDrag",
    "M-LeftRelease",
    "M-RightRelease",
    "C-M-LeftDrag",
    "C-M-RightDrag",
    "C-M-LeftRelease",
    "C-M-RightRelease",
    "MiddleMouse",
    "2-MiddleMouse",
    "3-MiddleMouse",
    "4-MiddleMouse",
    "C-MiddleMouse",
    "C-2-MiddleMouse",
    "C-3-MiddleMouse",
    "C-4-MiddleMouse",
    "M-MiddleMouse",
    "M-2-MiddleMouse",
    "M-3-MiddleMouse",
    "M-4-MiddleMouse",
    "C-M-MiddleMouse",
    "C-M-2-MiddleMouse",
    "C-M-3-MiddleMouse",
    "C-M-4-MiddleMouse",
    "ScrollWheelUp",
    "S-ScrollWheelUp",
    "ScrollWheelDown",
    "S-ScrollWheelDown",
    "C-ScrollWheelUp",
    "C-S-ScrollWheelUp",
    "C-ScrollWheelDown",
    "C-S-ScrollWheelDown",
    "M-ScrollWheelUp",
    "M-S-ScrollWheelUp",
    "M-ScrollWheelDown",
    "M-S-ScrollWheelDown",
    "C-M-ScrollWheelUp",
    "C-M-S-ScrollWheelUp",
    "C-M-ScrollWheelDown",
    "C-M-S-ScrollWheelDown",
}

for _, map in pairs(mouse_maps) do
    vim.keymap.set({ "n", "i", "v", "c" }, "<" .. map .. ">", "<Nop>", Opts)
end

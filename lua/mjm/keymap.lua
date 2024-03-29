local km = require("mjm.keymap_mod")

-- Mapped in normal mode so that <C-c> will exit the start of commands with a count
-- (This also gets rid of a command line nag)
-- Mapping in command mode will cause <C-c> to accept commands
vim.keymap.set({ "n", "i", "v" }, "<C-c>", "<esc>", { silent = true })
vim.keymap.set("v", "q", "<Nop>", { silent = true })

vim.api.nvim_create_user_command("We", "w | e", {}) -- Quick refresh if Treesitter bugs out
vim.api.nvim_create_user_command("Wbd", "w | bd", {})

---@param cmd string
---@param error string
---@return nil
local write_boilerplate = function(cmd, error)
    local status, result = pcall(function()
        vim.api.nvim_exec2(cmd, {})
    end)

    if status then
        return
    end

    if type(result) == "string" then
        vim.api.nvim_err_writeln(result)

        return
    end

    vim.api.nvim_err_writeln(error)
end

vim.keymap.set("n", "ZV", function()
    write_boilerplate("silent w", "Unknown error saving file")
end)

vim.keymap.set("n", "ZA", function()
    write_boilerplate("silent wa", "Unknown error saving file(s)")
end)

vim.keymap.set("n", "ZX", function()
    write_boilerplate("silent w | so", "Unknown error")
end)

vim.keymap.set("n", "ZZ", "<Nop>")
vim.keymap.set("n", "ZQ", "<Nop>")

-- Stop undo history from showing in the cmd line whever an undo/redo is performed
-- Done as functions because keymap <cmd>'s do not work with v:count1
vim.keymap.set("n", "u", function()
    vim.api.nvim_exec2("silent norm! " .. vim.v.count1 .. "u", {})
end, { silent = true })

vim.keymap.set("n", "<C-r>", function()
    vim.api.nvim_exec2('silent exec "norm! ' .. vim.v.count1 .. '\\<C-r>"', {})
end, { silent = true })

---@param map string
---@return nil
local search_with_mark = function(map)
    -- These are API calls because, if done as simple maps,
    -- the "/" and "?" prompts do not show in the command line
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_mark(0, "s", cur_row, cur_col, {})

    local key = vim.api.nvim_replace_termcodes(map, true, false, true)
    vim.api.nvim_feedkeys(key, "n", true)
end

vim.keymap.set("n", "/", function()
    search_with_mark("/")
end, { silent = true })

vim.keymap.set("n", "?", function()
    search_with_mark("?")
end, { silent = true })

vim.keymap.set("n", "<leader>lrv", "<cmd>rightbelow vsplit<cr>", { silent = true })
vim.keymap.set("n", "<leader>llv", "<cmd>leftabove vsplit<cr>", { silent = true })
vim.keymap.set("n", "<leader>ltv", "<cmd>topleft vsplit<cr>", { silent = true })
vim.keymap.set("n", "<leader>lbv", "<cmd>botright vsplit<cr>", { silent = true })

vim.keymap.set("n", "<leader>lrs", "<cmd>rightbelow split<cr>", { silent = true })
vim.keymap.set("n", "<leader>lls", "<cmd>leftabove split<cr>", { silent = true })
vim.keymap.set("n", "<leader>lts", "<cmd>topleft split<cr>", { silent = true })
vim.keymap.set("n", "<leader>lbs", "<cmd>botright split<cr>", { silent = true })

vim.keymap.set("n", "<M-j>", "<cmd>resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-k>", "<cmd>resize +2<CR>", { silent = true })
vim.keymap.set("n", "<M-h>", "<cmd>vertical resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-l>", "<cmd>vertical resize +2<CR>", { silent = true })

vim.keymap.set({ "n", "v" }, "<C-u>", "<C-u>zz", { silent = true })
vim.keymap.set({ "n", "v" }, "<C-d>", "<C-d>zz", { silent = true })

vim.keymap.set({ "n", "v" }, "n", "nzzzv", { silent = true })
vim.keymap.set({ "n", "v" }, "N", "Nzzzv", { silent = true })

for _, map in pairs({ "i", "a", "A" }) do
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

vim.keymap.set({ "n", "v" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set({ "n", "v" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

vim.keymap.set("v", "<", "<gv", { silent = true })
vim.keymap.set("v", ">", ">gv", { silent = true })

vim.keymap.set("n", "<esc>", function()
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
vim.keymap.set("n", "dD", "ggdG", { silent = true })
vim.keymap.set("n", "<leader>dD", 'gg"_dG', { silent = true })

vim.keymap.set({ "n", "v" }, "<leader>c", '"_c', { silent = true })
vim.keymap.set("n", "<leader>C", '"_C', { silent = true })
vim.keymap.set("v", "C", "<nop>", { silent = true })
vim.keymap.set("n", "c^", "^cg_", { silent = true })
vim.keymap.set("n", "cC", "ggcG", { silent = true })
vim.keymap.set("n", "<leacer>cC", 'gg"_cG', { silent = true })

vim.keymap.set({ "n", "v" }, "s", "<Nop>", { silent = true })
vim.keymap.set("n", "S", "<Nop>", { silent = true }) -- Used in visual mode by nvim-surround

vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("yank_reset_cursor", { clear = true }),
    callback = function()
        if vim.v.event.operator ~= "y" then
            return
        end

        vim.api.nvim_exec2("norm! `z", {})
    end,
})

vim.keymap.set({ "n", "v" }, "y", "mzy", { silent = true })
vim.keymap.set({ "n", "v" }, "<leader>y", 'mz"+y', { silent = true })

vim.keymap.set("n", "Y", "mzy$", { silent = true }) -- Avoid inconsistent behavior
vim.keymap.set("n", "<leader>Y", 'mz"+y$', { silent = true }) -- Mapping to "+Y yanks whole line
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

    vim.keymap.set("n", "d" .. obj, "v" .. obj .. "d", { silent = true })
    vim.keymap.set("n", "<leader>d" .. obj, "v" .. obj .. '"_d', { silent = true })

    vim.keymap.set("n", "c" .. obj, "v" .. obj .. "c", { silent = true })
    vim.keymap.set("n", "<leader>c" .. obj, "v" .. obj .. '"_c', { silent = true })
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

---@param put_cmd string
---@return nil
local create_blank_line = function(put_cmd)
    if not km.check_modifiable() then
        return
    end

    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})
    vim.api.nvim_exec2(put_cmd .. " =repeat(nr2char(10), v:count1)", {})
    vim.api.nvim_exec2("norm! `z", {})
end

vim.keymap.set("n", "[ ", function()
    create_blank_line("put!")
end, { silent = true })

vim.keymap.set("n", "] ", function()
    create_blank_line("put")
end, { silent = true })

vim.keymap.set("v", "J", function()
    km.visual_move(vim.v.count1, "d")
end, { silent = true })

vim.keymap.set("v", "K", function()
    km.visual_move(vim.v.count1, "u")
end, { silent = true })

vim.keymap.set("v", "H", function()
    local cur_mode = vim.api.nvim_get_mode().mode
    local is_visual_line = cur_mode == "V" or cur_mode == "Vs"

    if km.check_modifiable() and is_visual_line then
        return "d<cmd>wincmd h<cr>P`[v`]V"
    else
        return "<Nop>"
    end
end, { silent = true, expr = true })

vim.keymap.set("v", "L", function()
    local cur_mode = vim.api.nvim_get_mode().mode
    local is_visual_line = cur_mode == "V" or cur_mode == "Vs"

    if km.check_modifiable() and is_visual_line then
        return "d<cmd>wincmd l<cr>P`[v`]V"
    else
        return "<Nop>"
    end
end, { silent = true, expr = true })

vim.keymap.set("n", "<leader>=", function()
    if not km.check_modifiable() then
        return
    end

    local orig_line = vim.api.nvim_get_current_line()
    local orig_row, orig_col = unpack(vim.api.nvim_win_get_cursor(0))
    local orig_line_len = #orig_line
    local orig_set_row = orig_row - 1
    local rem_line = orig_line:sub(1, orig_col)
    local trailing_whitespace = string.match(rem_line, "%s+$")

    if trailing_whitespace then
        local last_non_blank, _ = rem_line:find("(%S)%s*$")

        if last_non_blank == nil then
            last_non_blank = 1
        end

        local set_col = nil

        if last_non_blank >= 1 then
            set_col = last_non_blank - 1
        else
            set_col = 0
        end

        vim.api.nvim_buf_set_text(0, orig_set_row, set_col, orig_set_row, orig_line_len, {})
    else
        vim.api.nvim_buf_set_text(0, orig_set_row, orig_col, orig_set_row, orig_line_len, {})
    end

    local orig_col_lua = orig_col + 1
    local to_move = orig_line:sub(orig_col_lua, orig_line_len)
    local to_move_trim = to_move:gsub("^%s+", ""):gsub("%s+$", "")
    vim.api.nvim_exec2("put! =''", {})
    vim.api.nvim_buf_set_text(0, orig_set_row, 0, orig_set_row, 0, { to_move_trim })
    vim.api.nvim_exec2("norm! ==", {})
end, { silent = true })

---@param chars string
---@return nil
local put_at_end = function(chars)
    if not km.check_modifiable() then
        return
    end

    local orig_line = vim.api.nvim_get_current_line()
    local cur_row = vim.api.nvim_win_get_cursor(0)[1]
    local set_row = cur_row - 1

    if orig_line == "" then
        vim.api.nvim_buf_set_text(0, set_row, 0, set_row, 0, { chars })

        return
    end

    local trim_line = orig_line:gsub("%s+$", "")
    local chars_len = #chars
    local end_chars = trim_line:sub(-chars_len)

    local orig_len = #orig_line
    local trim_len = #trim_line

    if end_chars == chars then
        local set_col = trim_len - chars_len
        vim.api.nvim_buf_set_text(0, set_row, set_col, set_row, orig_len, {})
    else
        local set_col = trim_len
        vim.api.nvim_buf_set_text(0, set_row, set_col, set_row, orig_len, { chars })
    end
end

vim.keymap.set("n", "<M-;>", function()
    put_at_end(";")
end, { silent = true })

vim.keymap.set("n", "gliw", "mzguiw~`z", { silent = true })
vim.keymap.set("n", "gliW", "mzguiW~`z", { silent = true })

vim.keymap.set("n", "gllw", function()
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})

    vim.api.nvim_exec2("s/\\v<(.)(\\w*)/\\u\\1\\L\\2/ge", {})
    vim.api.nvim_exec2("noh", {})
    vim.api.nvim_exec2("norm! `z", {})
end, { silent = true })

vim.keymap.set("n", "gllW", function()
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})

    vim.api.nvim_exec2("s/\\v<(.)(\\S*)/\\u\\1\\L\\2/ge", {})
    vim.api.nvim_exec2("noh", {})
    vim.api.nvim_exec2("norm! `z", {})
end, { silent = true })

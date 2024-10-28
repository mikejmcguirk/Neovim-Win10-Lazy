---@return boolean
local check_modifiable = function()
    if vim.api.nvim_get_option_value("modifiable", { buf = 0 }) then
        return true
    else
        vim.api.nvim_err_writeln("E21: Cannot make changes, 'modifiable' is off")
        return false
    end
end

-- Mapping in command mode will cause <C-c> to accept commands
vim.keymap.set({ "i", "x" }, "<C-c>", "<esc>", { silent = true })
vim.keymap.set("n", "<C-c>", function()
    vim.api.nvim_exec2("echo ''", {})
    vim.api.nvim_exec2("noh", {})
    vim.lsp.buf.clear_references()
    -- Allows <C-c> to exit the start of commands with a count
    -- By default <C-c> in normal mode produces a command line nag, which this map eliminates
    return "<esc>"
end, { expr = true, silent = true })

vim.keymap.set("n", "zg", "<cmd>silent norm! zg<cr>", { silent = true }) -- Stop cmd line nag

vim.api.nvim_create_user_command("We", "silent w | e", {}) -- Quick refresh if Treesitter bugs out

---@param cmd string
---@param error string
---@return nil
local cmd_boilerplate = function(cmd, error)
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
    cmd_boilerplate("silent w", "Unknown error saving file")
end)
vim.keymap.set("n", "ZA", function()
    cmd_boilerplate("silent wa", "Unknown error saving file(s)")
end)
vim.keymap.set("n", "ZX", function()
    cmd_boilerplate("silent w | so", "Unknown error")
end)

vim.keymap.set("n", "ZB", function()
    local current_buf = vim.api.nvim_get_current_buf()
    local total_win_count = 0
    local buf_win_count = 0

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        total_win_count = total_win_count + 1
        if vim.api.nvim_win_get_buf(win) == current_buf then
            buf_win_count = buf_win_count + 1
        end
    end

    if total_win_count < 2 then
        return
    end

    if buf_win_count < 2 then
        cmd_boilerplate("bd", "Unknown error deleting buffer")
    else
        cmd_boilerplate("q", "Unknown error quitting window")
    end
end)

vim.keymap.set("n", "ZZ", "<Nop>")
vim.keymap.set("n", "ZQ", "<Nop>")

-- Stop undo history from showing in the cmd line whever an undo/redo is performed
-- Done as functions because keymap <cmd>'s do not work with v:count1
vim.keymap.set("n", "u", function()
    if not check_modifiable() then
        return
    end
    vim.api.nvim_exec2("silent norm! " .. vim.v.count1 .. "u", {})
end, { silent = true })
vim.keymap.set("n", "<C-r>", function()
    if not check_modifiable() then
        return
    end
    vim.api.nvim_exec2('silent exec "norm! ' .. vim.v.count1 .. '\\<C-r>"', {})
end, { silent = true })

vim.keymap.set("n", "<M-j>", "<cmd>resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-k>", "<cmd>resize +2<CR>", { silent = true })
vim.keymap.set("n", "<M-h>", "<cmd>vertical resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-l>", "<cmd>vertical resize +2<CR>", { silent = true })

-- Running these as execs instead of standard mappings reduces visible screen shake
vim.keymap.set("n", "<C-u>", function()
    vim.api.nvim_exec2('silent exec "norm! \\<C-u>zz"', {})
end, { silent = true })
vim.keymap.set("n", "<C-d>", function()
    vim.api.nvim_exec2('silent exec "norm! \\<C-d>zz"', {})
end, { silent = true })
vim.keymap.set("x", "<C-u>", "<C-u>zz", { silent = true })
vim.keymap.set("x", "<C-d>", "<C-d>zz", { silent = true })

-- Not silent so that the search prompting displays properly
vim.keymap.set("n", "/", "ms/")
vim.keymap.set("n", "?", "ms?")

vim.keymap.set({ "n", "x" }, "n", function()
    if not (vim.v.hlsearch == 1) then
        local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_set_mark(0, "s", cur_row, cur_col, {})
        return "Nnzzzv"
    end

    return "nzzzv"
end, { expr = true })
vim.keymap.set({ "n", "x" }, "N", function()
    if not (vim.v.hlsearch == 1) then
        local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_set_mark(0, "s", cur_row, cur_col, {})
        return "nNzzzv"
    end

    return "Nzzzv"
end, { expr = true })

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
    require("mjm.backplacer").insert_backspace_fix()
end, { silent = true })

vim.keymap.set("i", ",", ",<C-g>u", { silent = true })
vim.keymap.set("i", ".", ".<C-g>u", { silent = true })
vim.keymap.set("i", ";", ";<C-g>u", { silent = true })
vim.keymap.set("i", "?", "?<C-g>u", { silent = true })
vim.keymap.set("i", "!", "!<C-g>u", { silent = true })
vim.keymap.set("i", ":", ":<C-g>u", { silent = true })
vim.keymap.set("i", "-", "-<C-g>u", { silent = true })

vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

---@param direction string
---@return nil
local visual_indent = function(direction)
    local count = vim.v.count1
    vim.opt_local.cursorline = false
    vim.api.nvim_exec2('exec "silent norm! \\<esc>"', {})
    vim.api.nvim_exec2("silent '<,'> " .. string.rep(direction, count), {})
    vim.api.nvim_exec2("silent norm! gv", {})
    vim.opt_local.cursorline = true
end

vim.keymap.set("x", "<", function()
    visual_indent("<")
end, { silent = true })
vim.keymap.set("x", ">", function()
    visual_indent(">")
end, { silent = true })

vim.keymap.set("n", "gV", "_vg_", { silent = true })

vim.keymap.set("n", "J", function()
    if not check_modifiable() then
        return
    end
    -- Done using a view instead of a mark to prevent visible screen shake
    local view = vim.fn.winsaveview()
    vim.api.nvim_exec2("norm! J", {})
    vim.fn.winrestview(view)
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
}
for _, map in pairs(cap_motions_norm) do
    vim.keymap.set("n", map, function()
        -- For this and any other maps starting with mz, the v count must be manually inserted
        return "mz" .. vim.v.count1 .. map .. "`z"
    end, { silent = true, expr = true })
end

local cap_motions_vis = {
    "~",
    "g~",
    "gu",
    "gU",
}
for _, map in pairs(cap_motions_vis) do
    vim.keymap.set("x", map, function()
        return "mz" .. vim.v.count1 .. map .. "`z"
    end, { silent = true, expr = true })
end

vim.keymap.set({ "n", "x" }, "x", '"_x', { silent = true })
vim.keymap.set({ "n", "x" }, "X", '"_X', { silent = true })

vim.keymap.set("n", "dd", function()
    local has_chars = string.match(vim.api.nvim_get_current_line(), "%S")
    if vim.v.count1 <= 1 and not has_chars then
        return '"_dd'
    else
        return "dd"
    end
end, { silent = true, expr = true })

vim.keymap.set({ "n", "x" }, "<leader>d", '"_d', { silent = true })
vim.keymap.set("n", "<leader>D", '"_D', { silent = true })
vim.keymap.set("x", "D", "<nop>", { silent = true })
vim.keymap.set("n", "d^", '^dg_"_dd', { silent = true }) -- Does not yank newline character
vim.keymap.set("n", "dD", function()
    if not check_modifiable() then
        return
    end
    vim.api.nvim_exec2("silent norm! ggdG", {})
end, { silent = true })
vim.keymap.set("n", "<leader>dD", function()
    if not check_modifiable() then
        return
    end
    vim.api.nvim_exec2('silent norm! gg"_dG', {})
end, { silent = true })

vim.keymap.set({ "n", "x" }, "<leader>c", '"_c', { silent = true })
vim.keymap.set("n", "<leader>C", '"_C', { silent = true })
vim.keymap.set("x", "C", "<nop>", { silent = true })
vim.keymap.set("n", "c^", "^cg_", { silent = true }) -- Does not yank newline character
vim.keymap.set("n", "cC", "ggcG", { silent = true })
vim.keymap.set("n", "<leacer>cC", 'gg"_cG', { silent = true })

vim.keymap.set({ "n", "x" }, "s", "<Nop>", { silent = true })
vim.keymap.set("n", "S", "<Nop>", { silent = true }) -- Used in visual mode by nvim-surround

vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("yank_reset_cursor", { clear = true }),
    callback = function()
        if vim.v.event.operator == "y" then
            vim.api.nvim_exec2("norm! `z", {})
        end
    end,
})

vim.keymap.set({ "n", "x" }, "y", "mzy", { silent = true })
vim.keymap.set({ "n", "x" }, "<leader>y", 'mz"+y', { silent = true })

vim.keymap.set("n", "Y", "mzy$", { silent = true }) -- Avoid inconsistent behavior
vim.keymap.set("n", "<leader>Y", 'mz"+y$', { silent = true }) -- Mapping to "+Y yanks whole line
vim.keymap.set("x", "Y", "<nop>", { silent = true })

vim.keymap.set("n", "y^", "mz^vg_y", { silent = true })
vim.keymap.set("n", "<leader>y^", 'mz^vg_"+y', { silent = true })
-- `z included in these maps to prevent visible scrolling before the autocmd is triggered
vim.keymap.set("n", "yY", "mzggyG`z", { silent = true })
vim.keymap.set("n", "<leader>yY", 'mzgg"+yG`z', { silent = true })

local startline_objects = { "0", "_", "g^", "g0" }
for _, obj in pairs(startline_objects) do
    vim.keymap.set("n", "y" .. obj, "mzv" .. obj .. "y", { silent = true })
    vim.keymap.set("n", "<leader>y" .. obj, "mzv" .. obj .. '"+y', { silent = true })

    vim.keymap.set("n", "d" .. obj, "x" .. obj .. "d", { silent = true })
    vim.keymap.set("n", "<leader>d" .. obj, "x" .. obj .. '"_d', { silent = true })

    vim.keymap.set("n", "c" .. obj, "x" .. obj .. "c", { silent = true })
    vim.keymap.set("n", "<leader>c" .. obj, "x" .. obj .. '"_c', { silent = true })
end

local norm_pastes = {
    { "p", "p", '"' },
    { "<leader>p", '"+p', "+" },
    { "P", "P", '"' },
    { "<leader>P", '"+P', "+" },
}
-- Done as exec commands to reduce visible text shake when fixing indentation
for _, map in pairs(norm_pastes) do
    vim.keymap.set("n", map[1], function()
        if not check_modifiable() then
            return
        end

        local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})

        local status, result = pcall(function()
            vim.api.nvim_exec2("silent norm! " .. vim.v.count1 .. map[2], {})
        end)

        if not status then
            if type(result) == "string" then
                vim.api.nvim_err_writeln(result)
            else
                vim.api.nvim_err_writeln("Unknown error pasting")
            end

            return
        end

        if vim.fn.getregtype(map[3]) == "x" then
            vim.api.nvim_exec2("silent norm! `[=`]", {})
        end
        vim.api.nvim_exec2("silent norm! `z", {})
    end, { silent = true })
end

-- TODO: Change this to remove the "X lines indented" command line nag
local visual_pastes = {
    { "p", "P", '"' },
    { "<leader>p", '"+P', "+" },
    { "P", "p", '"' },
    { "<leader>P", '"+p', "+" },
}
for _, map in pairs(visual_pastes) do
    vim.keymap.set("x", map[1], function()
        if not check_modifiable() then
            return "<Nop>"
        end

        local cur_mode = vim.api.nvim_get_mode().mode
        if cur_mode == "x" or cur_mode == "Vs" then
            return vim.v.count1 .. map[2] .. "=`]"
        elseif vim.fn.getregtype(map[3]) == "x" then
            return "mz" .. vim.v.count1 .. map[2] .. "`[=`]`z"
        else
            return "mz" .. vim.v.count1 .. map[2] .. "`z"
        end
    end, { silent = true, expr = true })
end

---@param put_cmd string
---@return nil
local create_blank_line = function(put_cmd)
    if not check_modifiable() then
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

---@param vcount1 number
---@param direction string
---@return nil
local visual_move = function(vcount1, direction)
    if not check_modifiable() then
        return
    end

    local pos_1 = nil
    local pos_2 = nil
    local fix_num = nil
    local cmd_start = nil
    if direction == "d" then
        pos_1 = "'>"
        pos_2 = "."
        fix_num = 0
        cmd_start = "'<,'> m '>+"
    elseif direction == "u" then
        pos_1 = "."
        pos_2 = "'<"
        fix_num = 1
        cmd_start = "'<,'> m '<-"
    else
        vim.api.nvim_err_writeln("Invalid direction")
        return
    end

    -- Leave visual mode to update '< and '>
    -- vim.v.count1 is updated when we do this, which is why it was passed as a parameter
    vim.api.nvim_exec2('exec "silent norm! \\<esc>"', {})
    local min_count = 1
    local to_move = nil
    if vcount1 <= min_count then
        to_move = min_count + fix_num
    else
        -- Offset calculated so that jumps based on rnu are correct
        local offset = vim.fn.line(pos_1) - vim.fn.line(pos_2)
        to_move = vcount1 - offset + fix_num
    end
    local move_cmd = "silent " .. cmd_start .. to_move

    local status, result = pcall(function()
        vim.api.nvim_exec2(move_cmd, {})
    end)

    if status then
        local end_row = vim.api.nvim_buf_get_mark(0, "]")[1]
        local end_col = #vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)[1]
        vim.api.nvim_buf_set_mark(0, "z", end_row, end_col, {})
        vim.api.nvim_exec2("silent norm! `[", {})
        vim.api.nvim_exec2("silent norm! =`z", {})
        vim.api.nvim_exec2("silent norm! gv", {})
        return
    end

    if type(result) == "string" and string.find(result, "E16") and vcount1 <= 1 then
        do
        end
    elseif result then
        vim.api.nvim_err_writeln(result)
    else
        vim.api.nvim_err_writeln("Unknown error in visual_move")
    end
    vim.api.nvim_exec2("norm! gv", {})
end

vim.keymap.set("x", "J", function()
    visual_move(vim.v.count1, "d")
end, { silent = true })
vim.keymap.set("x", "K", function()
    visual_move(vim.v.count1, "u")
end, { silent = true })

vim.keymap.set("n", "<leader>=", function()
    if not check_modifiable() then
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

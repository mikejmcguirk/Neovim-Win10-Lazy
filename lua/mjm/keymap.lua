---@return boolean
local check_modifiable = function()
    if vim.api.nvim_get_option_value("modifiable", { buf = 0 }) then
        return true
    else
        vim.api.nvim_err_writeln("E21: Cannot make changes, 'modifiable' is off")
        return false
    end
end

-- Mapped in normal mode so that <C-c> will exit the start of commands with a count
-- (This also gets rid of a command line nag)
-- Mapping in command mode will cause <C-c> to accept commands
vim.keymap.set({ "n", "i", "v" }, "<C-c>", "<esc>", { silent = true })

vim.keymap.set("v", "u", "<Nop>")
vim.keymap.set("v", "q", "<Nop>", { silent = true })
vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "gQ", "<nop>")
vim.keymap.set({ "n", "v" }, "<C-z>", "<nop>")

vim.keymap.set("n", "<esc>", function()
    vim.api.nvim_exec2("echo ''", {})
    vim.api.nvim_exec2("noh", {})
    vim.lsp.buf.clear_references()
end, { silent = true })

vim.api.nvim_create_user_command("We", "silent w | e", {}) -- Quick refresh if Treesitter bugs out

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

-- Running these as execs reduces screen shake vs standard mappings
vim.keymap.set("n", "<C-u>", function()
    vim.api.nvim_exec2('silent exec "norm! \\<C-u>zz"', {})
end, { silent = true })
vim.keymap.set("n", "<C-d>", function()
    vim.api.nvim_exec2('silent exec "norm! \\<C-d>zz"', {})
end, { silent = true })
vim.keymap.set("v", "<C-u>", "<C-u>zz", { silent = true })
vim.keymap.set("v", "<C-d>", "<C-d>zz", { silent = true })
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
    require("mjm.backplacer").insert_backspace_fix()
end, { silent = true })

vim.keymap.set("i", ",", ",<C-g>u", { silent = true })
vim.keymap.set("i", ".", ".<C-g>u", { silent = true })
vim.keymap.set("i", ";", ";<C-g>u", { silent = true })
vim.keymap.set("i", "?", "?<C-g>u", { silent = true })
vim.keymap.set("i", "!", "!<C-g>u", { silent = true })
vim.keymap.set("i", ":", ":<C-g>u", { silent = true })
vim.keymap.set("i", "-", "-<C-g>u", { silent = true })

vim.keymap.set({ "n", "v" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set({ "n", "v" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

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

vim.keymap.set("v", "<", function()
    visual_indent("<")
end, { silent = true })
vim.keymap.set("v", ">", function()
    visual_indent(">")
end, { silent = true })

vim.keymap.set("n", "gV", "_vg_", { silent = true })

vim.keymap.set("n", "J", function()
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
    vim.keymap.set("v", map, function()
        return "mz" .. vim.v.count1 .. map .. "`z"
    end, { silent = true, expr = true })
end

vim.keymap.set({ "n", "v" }, "x", '"_x', { silent = true })
vim.keymap.set({ "n", "v" }, "X", '"_X', { silent = true })

vim.keymap.set("n", "dd", function()
    local has_non_blank = string.match(vim.api.nvim_get_current_line(), "%S")
    if vim.v.count1 <= 1 and not has_non_blank then
        return '"_dd'
    else
        return "dd"
    end
end, { silent = true, expr = true })

vim.keymap.set({ "n", "v" }, "<leader>d", '"_d', { silent = true })
vim.keymap.set("n", "<leader>D", '"_D', { silent = true })
vim.keymap.set("v", "D", "<nop>", { silent = true })
vim.keymap.set("n", "d^", '^dg_"_dd', { silent = true }) -- Does not yank newline character
vim.keymap.set("n", "dD", function()
    vim.api.nvim_exec2("silent norm! ggdG", {})
end, { silent = true })
vim.keymap.set("n", "<leader>dD", function()
    vim.api.nvim_exec2('silent norm! gg"_dG', {})
end, { silent = true })

vim.keymap.set({ "n", "v" }, "<leader>c", '"_c', { silent = true })
vim.keymap.set("n", "<leader>C", '"_C', { silent = true })
vim.keymap.set("v", "C", "<nop>", { silent = true })
vim.keymap.set("n", "c^", "^cg_", { silent = true }) -- Does not yank newline character
vim.keymap.set("n", "cC", "ggcG", { silent = true })
vim.keymap.set("n", "<leacer>cC", 'gg"_cG', { silent = true })

vim.keymap.set({ "n", "v" }, "s", "<Nop>", { silent = true })
vim.keymap.set("n", "S", "<Nop>", { silent = true }) -- Used in visual mode by nvim-surround

vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("yank_reset_cursor", { clear = true }),
    callback = function()
        if vim.v.event.operator == "y" then
            vim.api.nvim_exec2("norm! `z", {})
        end
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

vim.keymap.set({ "n", "v" }, "<leader>yd", '"+d', { silent = true })

local startline_objects = { "0", "_", "g^", "g0" }
for _, obj in pairs(startline_objects) do
    vim.keymap.set("n", "y" .. obj, "mzv" .. obj .. "y", { silent = true })
    vim.keymap.set("n", "<leader>y" .. obj, "mzv" .. obj .. '"+y', { silent = true })

    vim.keymap.set("n", "d" .. obj, "v" .. obj .. "d", { silent = true })
    vim.keymap.set("n", "<leader>d" .. obj, "v" .. obj .. '"_d', { silent = true })

    vim.keymap.set("n", "c" .. obj, "v" .. obj .. "c", { silent = true })
    vim.keymap.set("n", "<leader>c" .. obj, "v" .. obj .. '"_c', { silent = true })
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

        vim.api.nvim_exec2("silent norm! " .. vim.v.count1 .. map[2], {})
        if vim.fn.getregtype(map[3]) == "V" then
            vim.api.nvim_exec2("silent norm! `[=`]", {})
        end
        vim.api.nvim_exec2("silent norm! `z", {})
    end, { silent = true })
end

vim.keymap.set("n", "<leader>gp", '"+gp', { silent = true })
vim.keymap.set("n", "<leader>gP", '"+gP', { silent = true })

local visual_pastes = {
    { "p", "P", '"' },
    { "<leader>p", '"+P', "+" },
    { "P", "p", '"' },
    { "<leader>P", '"+p', "+" },
}
for _, map in pairs(visual_pastes) do
    vim.keymap.set("n", map[1], function()
        if not check_modifiable() then
            return "<Nop>"
        end

        local cur_mode = vim.api.nvim_get_mode().mode
        if cur_mode == "V" or cur_mode == "Vs" then
            return vim.v.count1 .. map[2] .. "=`]"
        elseif vim.fn.getregtype(map[3]) == "V" then
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

vim.keymap.set({ "n", "v" }, "[[", "<Nop>")
vim.keymap.set({ "n", "v" }, "]]", "<Nop>")
vim.keymap.set({ "n", "v" }, "[]", "<Nop>")
vim.keymap.set({ "n", "v" }, "][", "<Nop>")
vim.keymap.set({ "n", "v" }, "[/", "<Nop>")
vim.keymap.set({ "n", "v" }, "]/", "<Nop>")

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

vim.keymap.set("v", "J", function()
    visual_move(vim.v.count1, "d")
end, { silent = true })
vim.keymap.set("v", "K", function()
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
    vim.keymap.set({ "n", "i", "v", "c" }, "<" .. map .. ">", "<Nop>")
end

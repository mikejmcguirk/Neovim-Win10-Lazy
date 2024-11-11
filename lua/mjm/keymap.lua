local ut = require("mjm.utils")

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

vim.keymap.set("n", "'", "`", { silent = true })

vim.api.nvim_create_user_command("We", "silent w | e", {}) -- Quick refresh if Treesitter bugs out

-- TODO: Do we add check modifiable to these?
-- TODO: This should incorporate saving the last modified marks
-- TODO: We could also look at using the update command here instead of write
-- TODO: Add some sort of logic so this doesn't work in runtime or plugin files
vim.keymap.set("n", "ZV", "<cmd>silent w<cr>")
vim.keymap.set("n", "ZA", "<cmd>silent wa<cr>")
vim.keymap.set("n", "ZX", function()
    local status, result = pcall(function()
        vim.api.nvim_exec2("silent w | so", {})
    end)
    if status then
        return
    end

    vim.api.nvim_err_writeln(result or "Unknown error")
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
    elseif buf_win_count < 2 then
        vim.cmd("bd")
    else
        vim.cmd("q")
    end
end)

vim.keymap.set("n", "ZZ", "<Nop>")
vim.keymap.set("n", "ZQ", "<Nop>")

-- Window navigation is handled through the tmux-navigator plugin
vim.keymap.set("n", "<M-j>", "<cmd>resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-k>", "<cmd>resize +2<CR>", { silent = true })
vim.keymap.set("n", "<M-h>", "<cmd>vertical resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-l>", "<cmd>vertical resize +2<CR>", { silent = true })

-- Normal mode scrolls done as commands because, even with lazyredraw on,
-- visible screenshake is reduced
vim.keymap.set({ "n" }, "<C-u>", "<cmd>norm! <C-u>zz<cr>", { silent = true })
vim.keymap.set({ "n" }, "<C-d>", "<cmd>norm! <C-d>zz<cr>", { silent = true })
vim.keymap.set({ "x" }, "<C-u>", "<C-u>zz", { silent = true })
vim.keymap.set({ "x" }, "<C-d>", "<C-d>zz", { silent = true })

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
vim.keymap.set("i", ":", ":<C-g>u", { silent = true })

vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

vim.keymap.set("n", "J", function()
    if not ut.check_modifiable() then
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

vim.keymap.set("n", "x", '"_d', { silent = true })
vim.keymap.set("n", "xx", '"_dd', { silent = true })
vim.keymap.set("n", "X", '"_D', { silent = true })
vim.keymap.set("x", "x", '"_x', { silent = true })
vim.keymap.set("x", "X", "<nop>", { silent = true })
vim.keymap.set("n", "xX", 'gg"_dG', { silent = true })

-- TODO: This could be smarter/more expanded on
vim.keymap.set("n", "dd", function()
    local has_chars = string.match(vim.api.nvim_get_current_line(), "%S")
    if vim.v.count1 <= 1 and not has_chars then
        return '"_dd'
    else
        return "dd"
    end
end, { silent = true, expr = true })

vim.keymap.set("x", "D", "<nop>", { silent = true })
vim.keymap.set("n", "d^", '^dg_"_dd', { silent = true }) -- Does not yank newline character
vim.keymap.set("n", "dD", "ggdG", { silent = true })

vim.keymap.set({ "n", "x" }, "<leader>c", '"_c', { silent = true })
vim.keymap.set("n", "<leader>C", '"_C', { silent = true })
vim.keymap.set("x", "C", "<nop>", { silent = true })
vim.keymap.set("n", "c^", "^cg_", { silent = true }) -- Does not yank newline character
vim.keymap.set("n", "cC", "ggcG", { silent = true })
vim.keymap.set("n", "<leader>cC", 'gg"_cG', { silent = true })

vim.keymap.set({ "x" }, "s", "mzy`<v0o`>g_p`[=`]`z", { silent = true })

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

    vim.keymap.set("n", "d" .. obj, "v" .. obj .. "d", { silent = true })
    vim.keymap.set("n", "x" .. obj, "v" .. obj .. '"_d', { silent = true })

    vim.keymap.set("n", "c" .. obj, "v" .. obj .. "c", { silent = true })
    vim.keymap.set("n", "<leader>c" .. obj, "x" .. obj .. '"_c', { silent = true })
end

local norm_pastes = {
    { "p", "p", '"' },
    { "<leader>p", '"+p', "+" },
    { "P", "P", '"' },
    { "<leader>P", '"+P', "+" },
}
-- Done as exec commands to reduce visible text shake when fixing indentation and
-- to remove command line nags
for _, map in pairs(norm_pastes) do
    vim.keymap.set("n", map[1], function()
        if not ut.check_modifiable() then
            return
        end

        local cur_line = vim.api.nvim_get_current_line()
        local start_idx, _ = string.find(cur_line, "%S")
        local is_blank = not start_idx
        local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})

        local status, result = pcall(function()
            vim.api.nvim_exec2("silent norm! " .. vim.v.count1 .. map[2], {})
        end)
        if not status then
            if type(result) == "string" then
                vim.api.nvim_err_writeln(result)
            else
                vim.api.nvim_err_writeln("Unknown error when pasting")
            end

            return
        end

        if vim.fn.getregtype(map[3]) == "V" or is_blank then
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
        if not ut.check_modifiable() then
            return ""
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

-- TODO: Will be added as Nvim default
vim.keymap.set("n", "[<Space>", function()
    local repeated = vim.fn["repeat"]({ "" }, vim.v.count1)
    local linenr = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, linenr - 1, linenr - 1, true, repeated)
end, { desc = "Add empty line above cursor" })

vim.keymap.set("n", "]<Space>", function()
    local repeated = vim.fn["repeat"]({ "" }, vim.v.count1)
    local linenr = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, linenr, linenr, true, repeated)
end, { desc = "Add empty line below cursor" })

---@param opts? table
---@return nil
local visual_move = function(opts)
    if not ut.check_modifiable() then
        return
    end

    opts = vim.deepcopy(opts or {}, true)
    ---@return table
    local get_pieces = function()
        if opts.upward then
            return {
                fix_num = 1,
                offset_start = ".",
                offset_end = "'<",
                cmd_start = "'<,'> m '<-",
            }
        else
            return {
                fix_num = 0,
                offset_start = "'>",
                offset_end = ".",
                cmd_start = "'<,'> m '>+",
            }
        end
    end
    local pieces = get_pieces() ---@type table

    local vcount1 = vim.v.count1 ---@type integer -- Get before leaving visual mode
    vim.api.nvim_exec2('exec "silent norm! \\<esc>"', {}) -- Force update of '< and '> marks
    ---@return integer -- Calculate so that rnu jumps are correct
    local get_offset = function()
        if vcount1 <= 1 then
            return 0
        else
            return vim.fn.line(pieces.offset_start) - vim.fn.line(pieces.offset_end)
        end
    end
    local move_amt = (vcount1 + pieces.fix_num - get_offset()) ---@type integer
    local move_cmd = "silent " .. pieces.cmd_start .. move_amt ---@type string

    local status, result = pcall(function()
        vim.api.nvim_exec2(move_cmd, {})
    end) ---@type boolean, unknown|nil

    if status then
        local end_row = vim.api.nvim_buf_get_mark(0, "]")[1] ---@type integer
        ---@type integer
        local end_col = #vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)[1]
        vim.api.nvim_buf_set_mark(0, "z", end_row, end_col, {})
        vim.api.nvim_exec2("silent norm! `[=`z", {})
    elseif type(result) == "string" and string.find(result, "E16") and vcount1 <= 1 then
        do
        end
    else
        vim.api.nvim_err_writeln(result or "Unknown error in visual_move")
    end

    vim.api.nvim_exec2("norm! gv", {})
end

vim.keymap.set("x", "J", function()
    visual_move({ upward = false })
end)
vim.keymap.set("x", "K", function()
    visual_move({ upward = true })
end)

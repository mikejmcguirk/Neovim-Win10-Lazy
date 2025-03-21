local ut = require("mjm.utils")

-- Mapping <esc> to <C-c> in command mode will cause <C-c> to accept commands rather than cancel
-- Mapped in operator pending mode because if you C-c out without the remap, quickscope will not
-- properly exit highlighting
vim.keymap.set({ "x", "o" }, "<C-c>", "<esc>", { silent = true })
-- Deal with default behavior where you type just to the bound of a window, so Nvim scrolls to
-- the next column so you can see what you're typing, but then you exit insert mode, meaning the
-- character no longer can exist, but Neovim still has you scrolled to the side
vim.keymap.set("i", "<C-c>", "<esc>ze")
vim.keymap.set("n", "<C-c>", function()
    vim.api.nvim_exec2("echo ''", {})
    vim.api.nvim_exec2("noh", {})
    vim.lsp.buf.clear_references()
    -- Allows <C-c> to exit the start of commands with a count
    -- Eliminates default command line nag
    return "<esc>"
end, { expr = true, silent = true })

vim.keymap.set("i", "<enter>", function()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local after_cursor = line:sub(col + 1)

    if after_cursor:match("^%s*$") then
        return '<enter><esc>ze"_S' -- Make sure we re-enter insert mode properly indented
    else
        return "<enter><C-o>ze"
    end
end, { expr = true })

-- TODO: This should incorporate saving the last modified marks
-- TODO: Add some sort of logic so this doesn't work in runtime or plugin files
vim.keymap.set("n", "ZV", "<cmd>silent up<cr>")
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

for _, map in pairs({ "<C-w>q", "<C-w><C-q>" }) do
    vim.keymap.set("n", map, function()
        local current_buf = vim.api.nvim_get_current_buf()
        local buf_win_count = 0

        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_buf(win) == current_buf then
                buf_win_count = buf_win_count + 1
            end
        end

        local cmd = "bd"
        if buf_win_count > 1 then
            cmd = "q"
        end

        local status, result = pcall(function()
            vim.cmd("silent up | " .. cmd)
        end)

        if status then
            return
        elseif type(result) == "string" then
            vim.notify(result, vim.log.levels.WARN)
        else
            vim.notify("Unknown error closing window", vim.log.levels.WARN)
        end
    end)
end

-- Not silent so that the search prompting displays properly
vim.keymap.set("n", "/", "ms/")
vim.keymap.set("n", "?", "ms?")

vim.keymap.set("n", "N", "Nzzzv")
vim.keymap.set("n", "n", "nzzzv")

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

-- "S" enters insert with the proper indent. "I" purposefully left on default behavior
for _, map in pairs({ "i", "a", "A" }) do
    vim.keymap.set("n", map, function()
        if string.match(vim.api.nvim_get_current_line(), "^%s*$") then
            return '"_S'
        else
            return map
        end
    end, { silent = true, expr = true })
end

vim.keymap.set("i", ";", ";<C-g>u", { silent = true })

vim.keymap.set({ "n", "x" }, "k", function()
    if vim.v.count == 0 then
        return "gk"
    else
        return "k"
    end
end, { expr = true, silent = true })

vim.keymap.set({ "n", "x" }, "j", function()
    if vim.v.count == 0 then
        return "gj"
    else
        return "j"
    end
end, { expr = true, silent = true })

vim.keymap.set("n", "J", function()
    if not ut.check_modifiable() then
        return
    end

    -- Done using a view instead of a mark to prevent visible screen shake
    local view = vim.fn.winsaveview()
    vim.api.nvim_exec2("norm! J", {})
    vim.fn.winrestview(view)
end, { silent = true })

vim.keymap.set("n", "x", '"_x', { silent = true })
vim.keymap.set("n", "<leader>d", '"_d', { silent = true })
vim.keymap.set("n", "<leader>D", '"_D', { silent = true })
vim.keymap.set("x", "x", '"_x', { silent = true })
vim.keymap.set("x", "<leader>D", "<nop>", { silent = true })
vim.keymap.set("n", "<leader>dD", 'gg"_dG', { silent = true })

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
vim.keymap.set("n", "dK", "DO<esc>p==", { silent = true })

vim.keymap.set({ "n", "x" }, "<leader>c", '"_c', { silent = true })
vim.keymap.set("n", "<leader>C", '"_C', { silent = true })
vim.keymap.set("x", "C", "<nop>", { silent = true })
vim.keymap.set("n", "c^", "^cg_", { silent = true }) -- Does not yank newline character
vim.keymap.set("n", "cC", "ggcG", { silent = true })
vim.keymap.set("n", "<leader>cC", 'gg"_cG', { silent = true })

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

-- In Vim, Y is a synonym for yy. It only behaves like y$ because of a Neovim default mapping
-- Any Neovim equivalent Y behavior below must be mapped manually
vim.keymap.set("n", "Y", "mzy$", { silent = true })
vim.keymap.set("n", "<leader>Y", 'mz"+y$', { silent = true })
vim.keymap.set("x", "Y", "<nop>", { silent = true })

vim.keymap.set("n", "y^", "mz^vg_y", { silent = true })
vim.keymap.set("n", "<leader>y^", 'mz^vg_"+y', { silent = true })
-- `z included in these maps to prevent visible scrolling before the autocmd is triggered
vim.keymap.set("n", "yY", "mzggyG`z", { silent = true })
vim.keymap.set("n", "<leader>yY", 'mzgg"+yG`z', { silent = true })

local startline_objects = { "0", "_", "g^", "g0" }
-- If you do db, it does not delete the character the cursor is on, so the h's are included in
-- these maps to offset the cursor and match default behavior
for _, obj in pairs(startline_objects) do
    vim.keymap.set("n", "y" .. obj, "mzhv" .. obj .. "y", { silent = true })
    vim.keymap.set("n", "<leader>y" .. obj, "mzhv" .. obj .. '"+y', { silent = true })

    vim.keymap.set("n", "d" .. obj, "hv" .. obj .. "d", { silent = true })
    vim.keymap.set("n", "<leader>d" .. obj, "hv" .. obj .. '"_d', { silent = true })

    vim.keymap.set("n", "c" .. obj, "hv" .. obj .. "c", { silent = true })
    vim.keymap.set("n", "<leader>c" .. obj, "hv" .. obj .. '"_c', { silent = true })
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

        local line = vim.api.nvim_get_current_line() ---@type string
        local is_blank = line:match("^%s*$") ---@type boolean|nil

        local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})

        local status, result = pcall(function()
            vim.api.nvim_exec2("silent norm! " .. vim.v.count1 .. map[2], {})
        end) ---@type boolean, unknown|nil

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
            return vim.v.count1 .. map[2] .. "<cmd>silent norm! =`]<cr>"
        elseif vim.fn.getregtype(map[3]) == "V" then
            return "mz" .. vim.v.count1 .. map[2] .. "<cmd>silent norm! `[=`]`z<cr>"
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

vim.keymap.set("n", "<leader>ga", function()
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" then
        vim.notify("No file detected", vim.log.levels.WARN)
        return
    end

    local cwd = vim.fn.getcwd()
    local git_root = vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel"))
    if vim.v.shell_error ~= 0 then
        vim.notify("Current directory is not a git repository.", vim.log.levels.WARN)
        return
    end

    if git_root ~= cwd then
        vim.notify(
            "Current working directory is not the root of a Git repository.",
            vim.log.levels.WARN
        )
        return
    end

    local relative_file = vim.fn.fnamemodify(file, ":.")
    local file_check =
        vim.fn.system("git ls-files --error-unmatch " .. vim.fn.shellescape(relative_file))
    if vim.v.shell_error == 0 then
        vim.notify(relative_file .. " is already tracked in git: " .. vim.fn.trim(file_check))
        return
    end

    local git_add = vim.fn.system("git add " .. vim.fn.shellescape(relative_file))
    if vim.v.shell_error == 0 then
        print("File successfully added to git: " .. relative_file)
    else
        print("Failed to add file to git: " .. vim.fn.trim(git_add))
    end
end)

vim.keymap.set("n", "<leader>ge", function()
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" then
        vim.notify("No file detected", vim.log.levels.WARN)
        return
    end

    local cwd = vim.fn.getcwd()
    local git_root = vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel"))
    if vim.v.shell_error ~= 0 then
        vim.notify("Current directory is not a git repository.", vim.log.levels.WARN)
        return
    end

    if git_root ~= cwd then
        vim.notify(
            "Current working directory is not the root of a Git repository.",
            vim.log.levels.WARN
        )
        return
    end

    local relative_file = vim.fn.fnamemodify(file, ":.")
    local file_check =
        vim.fn.system("git ls-files --error-unmatch " .. vim.fn.shellescape(relative_file))
    if vim.v.shell_error ~= 0 then
        vim.notify(
            relative_file
                .. " is not tracked in the current Git repository: "
                .. vim.fn.trim(file_check)
        )
        return
    end

    local confirm = vim.fn.confirm(
        "This will delete the current buffer and remove it from Git. Proceed?",
        "&Yes\n&No",
        2
    )
    if confirm ~= 1 then
        return
    end

    local git_rm = vim.fn.system("git rm -f " .. vim.fn.shellescape(relative_file))
    if vim.v.shell_error == 0 then
        vim.notify(relative_file .. " removed from Git")
        vim.cmd("bd")
    else
        vim.notify(
            "Failed to remove " .. relative_file .. " from git: \n" .. vim.fn.trim(git_rm),
            vim.log.levels.WARN
        )
    end
end)

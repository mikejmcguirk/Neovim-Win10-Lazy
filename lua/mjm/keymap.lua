local ut = require("mjm.utils")

--------------------
-- Mode Switching --
--------------------

-- Mapping <esc> to <C-c> in command mode will cause <C-c> to accept commands rather than cancel
-- Mapped in operator pending mode because if you C-c out without the remap, quickscope will not
-- properly exit highlighting
vim.keymap.set({ "x", "o" }, "<C-c>", "<esc>", { silent = true })
-- Deal with default behavior where you type just to the bound of a window, so Nvim scrolls to
-- the next column so you can see what you're typing, but then you exit insert mode, meaning the
-- character no longer can exist, but Neovim still has you scrolled to the side
vim.keymap.set("i", "<C-c>", "<esc>ze")

vim.keymap.set("n", "<C-c>", function()
    return ut.clear_clutter()
end, { expr = true, silent = true })

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

vim.keymap.set("n", "v", "mvv", { silent = true })

vim.keymap.set("x", "q", "<Nop>")
vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "gQ", "<nop>")
vim.keymap.set("n", "gh", "<nop>")
vim.keymap.set("n", "gH", "<nop>")

vim.keymap.set("n", "gs", "<nop>") -- I guess this is fine here

-------------------------
-- Saving and Quitting --
-------------------------

-- TODO: This should incorporate saving the last modified marks
-- TODO: Add some sort of logic so this doesn't work in runtime or plugin files
vim.keymap.set("n", "ZV", "<cmd>silent up<cr>")
vim.keymap.set("n", "ZA", "<cmd>silent wa<cr>")
vim.keymap.set("n", "ZX", function()
    local status, result = pcall(function()
        vim.api.nvim_exec2("silent up | so", {})
    end)
    if status then
        return
    end

    vim.api.nvim_echo({ { result or "Unknown error" } }, true, { err = true })
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
        else
            vim.notify(result or "Unknown error closing window", vim.log.levels.WARN)
        end
    end)
end

-- ZZ is intuitively a better mapping to save than ZV, but by default ZZ exits the current window
-- This muscle memory becomes a problem if you need to go into vanilla vim or a clean config
-- Likewise with ZQ. By default, it is quit without save. Unfortunate to hit by accident
vim.keymap.set("n", "ZZ", "<Nop>")
vim.keymap.set("n", "ZQ", "<Nop>")

vim.keymap.set("n", "<C-z>", "<nop>")

-------------------
-- Undo and Redo --
-------------------

-- Purposefully not setup to accept counts. Don't want to accidently get lost
-- For some reason, these don't actually go silent unless run as cmds

vim.keymap.set("n", "u", function()
    vim.cmd("silent norm! u")
end, { silent = true })

vim.keymap.set("n", "<C-r>", function()
    vim.cmd('silent exec "norm! \\<C-r>"')
end, { silent = true })

---------------------
-- Window Movement --
---------------------

---@return boolean
local is_tmux_zoomed = function()
    return vim.fn.system("tmux display-message -p '#{window_zoomed_flag}'") == "1\n"
end

-- vim.keymap.set("n", "<esc>", function()
--     print(is_tmux_zoomed())
-- end)

local tmux_cmd_map = {
    ["h"] = "L",
    ["j"] = "D",
    ["k"] = "U",
    ["l"] = "R",
}

---@param direction string
---@return nil
local do_tmux_move = function(direction)
    if is_tmux_zoomed() then
        return
    end

    pcall(function()
        vim.fn.system([[tmux select-pane -]] .. tmux_cmd_map[direction])
    end)
end

---@param nvim_cmd string
---@return nil
local win_move_tmux = function(nvim_cmd)
    local is_prompt = vim.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt"
    if is_prompt then
        do_tmux_move(nvim_cmd)
        return
    end

    local start_win = vim.fn.winnr() ---@type integer
    vim.cmd("wincmd " .. nvim_cmd)

    if vim.fn.winnr() ~= start_win then
        return
    end

    do_tmux_move(nvim_cmd)
end

for k, _ in pairs(tmux_cmd_map) do
    vim.keymap.set("n", "<C-" .. k .. ">", function()
        win_move_tmux(k)
    end)
end

-- local function win_move_wezterm(key, dir)
--     local curwin = vim.fn.winnr()
--     vim.cmd("wincmd " .. key)
--     if curwin == vim.fn.winnr() then
--         vim.fn.system("wezterm cli activate-pane-direction " .. dir)
--     end
-- end

-- TODO: This should be a different map, but I can't think of a better one
-- Using alt feels like an anti-pattern
vim.keymap.set("n", "<M-j>", "<cmd>resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-k>", "<cmd>resize +2<CR>", { silent = true })
vim.keymap.set("n", "<M-h>", "<cmd>vertical resize -2<CR>", { silent = true })
vim.keymap.set("n", "<M-l>", "<cmd>vertical resize +2<CR>", { silent = true })

vim.keymap.set("x", "<C-w>", "<nop>")

-- Even mapping <C-c> in operator pending mode does not fix these
local bad_wincmds = { "c", "f", "w", "i", "+", "-" }
for _, key in pairs(bad_wincmds) do
    vim.keymap.set("n", "<C-w>" .. key, "<nop>")
    vim.keymap.set("n", "<C-w><C-" .. key .. ">", "<nop>")
end

----------------
-- Navigation --
----------------

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

vim.keymap.set({ "n", "x" }, "<C-u>", "<C-u>zz", { silent = true })
vim.keymap.set({ "n", "x" }, "<C-d>", "<C-d>zz", { silent = true })

vim.keymap.set("n", "zT", function()
    vim.opt.scrolloff = 0
    vim.cmd("norm! zt")
    vim.opt.scrolloff = Scrolloff_Val
end)

vim.keymap.set("n", "zB", function()
    vim.opt.scrolloff = 0
    vim.cmd("norm! zb")
    vim.opt.scrolloff = Scrolloff_Val
end)

vim.keymap.set("n", "'", "`")

-- Not silent so that the search prompting displays properly
vim.keymap.set("n", "/", "ms/")
vim.keymap.set("n", "?", "ms?")
vim.keymap.set("n", "N", "Nzzzv")
vim.keymap.set("n", "n", "nzzzv")

vim.keymap.set({ "n", "x" }, "[[", "<Nop>")
vim.keymap.set({ "n", "x" }, "]]", "<Nop>")
vim.keymap.set({ "n", "x" }, "[]", "<Nop>")
vim.keymap.set({ "n", "x" }, "][", "<Nop>")
vim.keymap.set({ "n", "x" }, "[/", "<Nop>")
vim.keymap.set({ "n", "x" }, "]/", "<Nop>")

-- Purposefully left alone in cmd mode
vim.keymap.set({ "n", "i", "x" }, "<left>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<right>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<up>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<down>", "<Nop>")

vim.keymap.set({ "n", "i", "x" }, "<pageup>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<pagedown>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<home>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<end>", "<Nop>")
vim.keymap.set({ "n", "i", "x" }, "<insert>", "<Nop>")
vim.keymap.set({ "n", "x" }, "<del>", "<Nop>")

--------------------
-- Capitalization --
--------------------

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

vim.keymap.set("x", "u", "<nop>")
vim.keymap.set("x", "U", "<nop>")

--------------------------
-- Yank, Change, Delete --
--------------------------

vim.keymap.set({ "n", "x" }, "x", '"_x', { silent = true })
vim.keymap.set("n", "X", '"_X', { silent = true })
vim.keymap.set("x", "X", "<nop>", { silent = true })

vim.keymap.set("x", "D", "<nop>", { silent = true })
vim.keymap.set("n", "d^", '^dg_"_dd', { silent = true }) -- Does not yank newline character
vim.keymap.set("n", "dD", "ggdG", { silent = true })
vim.keymap.set("n", "dK", "DO<esc>p==", { silent = true })

vim.keymap.set("n", "<leader>d", '"_d', { silent = true })
vim.keymap.set("n", "<leader>D", '"_D', { silent = true })
vim.keymap.set("n", "<leader>dD", 'gg"_dG', { silent = true })
vim.keymap.set("x", "<leader>D", "<nop>", { silent = true })

vim.keymap.set("n", "c^", "^cg_", { silent = true }) -- Does not yank newline character
vim.keymap.set("n", "cC", "ggcG", { silent = true })
vim.keymap.set("x", "C", "<nop>", { silent = true })

vim.keymap.set({ "n", "x" }, "<leader>c", '"_c', { silent = true })
vim.keymap.set("n", "<leader>C", '"_C', { silent = true })
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

-- Nvim sets Y to be equivalent to y$ through a lua runtime file
-- Equivalent of Neovim Y behavior must be mapped manually
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

vim.api.nvim_create_autocmd("TextChanged", {
    group = vim.api.nvim_create_augroup("delete_clear", { clear = true }),
    pattern = "*",
    callback = function()
        if vim.v.operator == "d" then
            vim.api.nvim_exec2("echo ''", {})
        end
    end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
    group = vim.api.nvim_create_augroup("change_clear", { clear = true }),
    pattern = "*",
    callback = function()
        if vim.v.operator == "c" then
            vim.api.nvim_exec2("echo ''", {})
        end
    end,
})

-------------
-- Pasting --
-------------

local norm_pastes = {
    { "p", "p", '"' },
    { "<leader>p", '"+p', "+" },
    { "P", "P", '"' },
    { "<leader>P", '"+P', "+" },
}

for _, map in pairs(norm_pastes) do
    vim.keymap.set("n", map[1], function()
        local paste_cmd = "mz<cmd>silent norm! " .. vim.v.count1 .. map[2] .. "<cr>"

        local line = vim.api.nvim_get_current_line() ---@type string
        local is_blank = line:match("^%s*$") ---@type boolean|nil
        if vim.fn.getregtype(map[3]) == "V" or is_blank then
            paste_cmd = paste_cmd .. "<cmd>silent norm! `[=`]<cr>"
        end

        return paste_cmd .. "`z"
    end, { expr = true, silent = true })
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
            return
        end

        local cur_mode = vim.api.nvim_get_mode().mode
        if cur_mode == "V" or cur_mode == "Vs" then
            -- Cursor goes to the beginning of the paste by default, no mark needed
            -- Because there is no mark, count is taken in by default
            return map[2] .. "<cmd>silent norm! =`]<cr>"
        elseif vim.fn.getregtype(map[3]) == "V" then
            return "mz" .. vim.v.count1 .. map[2] .. "<cmd>silent norm! `[=`]`z<cr>"
        else
            return "mz" .. vim.v.count1 .. map[2] .. "`z"
        end
    end, { silent = true, expr = true })
end

-----------------------
-- Insert Mode Fixes --
-----------------------

vim.keymap.set("i", ";", ";<C-g>u", { silent = true })

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

-----------------------
-- Text Manipulation --
-----------------------

vim.keymap.set("n", "J", function()
    if not ut.check_modifiable() then
        return
    end

    -- Done using a view instead of a mark to prevent visible screen shake
    local view = vim.fn.winsaveview()
    -- By default, [count]J joins one fewer lines than indicated by the relative line numbers
    local count = vim.v.count1 + 1

    vim.cmd("norm! " .. count .. "J")
    vim.fn.winrestview(view)
end, { silent = true })

---@param opts? table
---@return nil
local visual_move = function(opts)
    if not ut.check_modifiable() then
        return
    end

    vim.opt.lazyredraw = true

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
    -- Trying to move text off the screen
    elseif type(result) == "string" and string.find(result, "E16") and vcount1 <= 1 then
        do
        end
    else
        vim.api.nvim_echo({ { result or "Unknown error in visual_move" } }, true, { err = true })
    end

    vim.api.nvim_exec2("norm! gv", {})

    vim.opt.lazyredraw = false
end

vim.keymap.set("x", "J", function()
    visual_move({ upward = false })
end)
vim.keymap.set("x", "K", function()
    visual_move({ upward = true })
end)

---@param direction string
---@return nil
local visual_indent = function(direction)
    vim.opt.lazyredraw = true
    vim.opt_local.cursorline = false

    local count = vim.v.count1
    vim.api.nvim_exec2('exec "silent norm! \\<esc>"', {})
    vim.api.nvim_exec2("silent '<,'> " .. string.rep(direction, count), {})
    vim.api.nvim_exec2("silent norm! gv", {})

    vim.opt_local.cursorline = true
    vim.opt.lazyredraw = false
end

vim.keymap.set("x", "<", function()
    visual_indent("<")
end, { silent = true })
vim.keymap.set("x", ">", function()
    visual_indent(">")
end, { silent = true })

-- I don't know a better place to put this
vim.keymap.set("n", "zg", "<cmd>silent norm! zg<cr>", { silent = true })

---------------------
-- Git Integration --
---------------------

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
        vim.cmd("bd!")
    else
        vim.notify(
            "Failed to remove " .. relative_file .. " from git: \n" .. vim.fn.trim(git_rm),
            vim.log.levels.WARN
        )
    end
end)

---------------
-- The Mouse --
---------------

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
    vim.keymap.set({ "n", "i", "x", "c" }, "<" .. map .. ">", "<Nop>")
end

local ut = require("mjm.utils")
local set_z_at_cursor = function()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_mark(0, "z", row, col, {})
end

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

-- FUTURE: It might be good to imap <cr> to something like <cr><esc>zea but it contradicts with an
-- autopairs mapping. need to investigate

vim.keymap.set("n", "<C-c>", function()
    vim.cmd("echo ''")
    vim.cmd("noh")
    vim.lsp.buf.clear_references()

    -- Allows <C-c> to exit the start of commands with a count
    -- Eliminates default command line nag
    return "<esc>"
end, { expr = true, silent = true })

-- "S" enters insert with the proper indent. "I" left on default behavior
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
vim.keymap.set("n", "V", "mvV", { silent = true })

vim.keymap.set({ "n", "x" }, "s", "<Nop>")
vim.keymap.set({ "n" }, "S", "<Nop>") -- Left open in x mode for surround
vim.keymap.set("x", "q", "<Nop>")
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
        vim.cmd("silent up | so")
    end)

    if status then
        return
    end

    vim.api.nvim_echo({ { result or "Unknown error on save and source" } }, true, { err = true })
end)

for _, map in pairs({ "<C-w>q", "<C-w><C-q>" }) do
    vim.keymap.set("n", map, function()
        local cur_buf = vim.api.nvim_get_current_buf()
        local buf_win_count = 0
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_buf(win) == cur_buf then
                buf_win_count = buf_win_count + 1
            end
        end

        local cmd = "up | bd"
        if buf_win_count > 1 then
            cmd = "q"
        end

        local status, result = pcall(function()
            vim.cmd("silent " .. cmd)
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

vim.keymap.set("n", "u", function()
    vim.cmd("silent norm! u")
end, { silent = true })

vim.keymap.set("n", "U", "<nop>")

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

local resize_win = function(cmd)
    if vim.fn.win_gettype(vim.api.nvim_get_current_win()) == "" then
        vim.cmd(cmd)
    end
end

-- TODO: These should be a different map, but I can't think of a better one
-- Using alt feels like an anti-pattern
vim.keymap.set("n", "<M-j>", function()
    resize_win("silent resize -2")
end)

vim.keymap.set("n", "<M-k>", function()
    resize_win("silent resize +2")
end)

vim.keymap.set("n", "<M-h>", function()
    resize_win("silent vertical resize -2")
end)

vim.keymap.set("n", "<M-l>", function()
    resize_win("silent vertical resize +2")
end)

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

vim.keymap.set("c", "<C-p>", "<up>")
vim.keymap.set("c", "<C-n>", "<down>")

vim.keymap.set({ "n", "x" }, "<C-u>", "<C-u>zz", { silent = true })
vim.keymap.set({ "n", "x" }, "<C-d>", "<C-d>zz", { silent = true })

vim.keymap.set("n", "zT", function()
    vim.opt_local.scrolloff = 0
    vim.cmd("norm! zt")
    vim.opt_local.scrolloff = Scrolloff_Val
end)

vim.keymap.set("n", "zB", function()
    vim.opt_local.scrolloff = 0
    vim.cmd("norm! zb")
    vim.opt_local.scrolloff = Scrolloff_Val
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

------------------
-- Text Objects --
------------------

-- Translated from justinmk from jdaddy.vim
local function whole_file()
    local line_count = vim.api.nvim_buf_line_count(0)
    if vim.api.nvim_buf_get_lines(0, 0, 1, true)[1] == "" and line_count == 1 then
        -- Because the omap is not an expr, we need the <esc> keycode literal
        return "'\027'"
    end

    -- get_lines result does not include \n. Subtract one because set_mark's col is 0 indexed
    local last_line_len = #vim.api.nvim_buf_get_lines(0, -2, -1, true)[1] - 1
    vim.api.nvim_buf_set_mark(0, "[", 1, 0, {})
    vim.api.nvim_buf_set_mark(0, "]", line_count, last_line_len, {})

    return "'[o']g_"
end

vim.keymap.set("x", "al", function()
    return whole_file()
end, { expr = true })

vim.keymap.set("o", "al", "<cmd>normal Val<CR>", { silent = true })

-- TODO: Make this text object accept a count
-- This could also be made to start at the first non-blank character rather than the first char
-- But test this first rather than speculatively make adjustments

-- Translated from justinmk from jdaddy.vim
local function inner_line()
    local cur_line = vim.api.nvim_get_current_line()
    if cur_line == "" then
        -- Because the omap is not an expr, we need the <esc> keycode literal
        return "'\027'"
    end

    local row = vim.api.nvim_win_get_cursor(0)[1]
    -- #cur_line does not include \n. Subtract one because set_mark's col is 0 indexed
    local end_col = #cur_line - 1
    vim.api.nvim_buf_set_mark(0, "[", row, 0, {})
    vim.api.nvim_buf_set_mark(0, "]", row, end_col, {})

    return "`[o`]"
end

vim.keymap.set("x", "il", function()
    return inner_line()
end, { expr = true })

vim.keymap.set("o", "il", "<cmd>normal vil<CR>", { silent = true })

vim.keymap.set("o", "_", "<cmd>normal v_<cr>", { silent = true })

--------------------
-- Capitalization --
--------------------

-- I am not sure how to do these fixes without manually returning to the mark
-- If you use an autocmd to goto mark based on v:operator, v:operator persists after the autocmd,
-- so the goto mark can retrigger after changing text in insert mode
-- v:operator is read-only, so it cannot be manually set to ""
-- vim.v.event.operator is nil in TextChanged

local cap_motions_norm = {
    "~",
    "guu",
    "guiw",
    "guiW",
    "guil",
    "gual",
    "gUU",
    "gUiw",
    "gUiW",
    "gUil",
    "gUal",
    "g~~",
    "g~iw",
    "g~il",
    "g~al",
}

for _, map in pairs(cap_motions_norm) do
    vim.keymap.set("n", map, function()
        set_z_at_cursor()
        return map .. "`z"
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
        set_z_at_cursor()
        return map .. "`z"
    end, { silent = true, expr = true })
end

-- Don't want to confuse muscle memory for "u"
vim.keymap.set("x", "u", "<nop>")
vim.keymap.set("x", "U", "<nop>")

--------------------------
-- Yank, Change, Delete --
--------------------------

-- Currently, autocmds are used to handle mark movement and suppress information messages
-- Alternatively, it might be possible to handle these using custom operatorfuncs
-- But for now, there is not an issue with the message suppression or mark movement significant
-- enough to necessitate that

vim.keymap.set({ "n", "x" }, "x", '"_x', { silent = true })
vim.keymap.set("n", "X", '"_X', { silent = true })
vim.keymap.set("x", "X", 'd0"_Dp==', { silent = true })

-- For now, I'm going to omit specific maps for "_d and "_c in normal mode
-- Trying to use the pattern of <leader> maps being for external plugins only
-- <leader>d and <leader>c contradict that
-- gd and gc are goto definition and comment, so can't be used
-- Could use Zc and Zd, but a bit cumbersome
-- zd and zc are fold maps, but could be fine since I don't use those

-- Explicitly delete to unnamed to write the contents to reg 0
-- No mark, so count does not need to be manually specified

local dc_maps = { "d", "c", "D", "C" }
for _, map in pairs(dc_maps) do
    vim.keymap.set({ "n", "x" }, map, function()
        if (not vim.v.register) or vim.v.register == "" or vim.v.register == '"' then
            -- If you type ""di, Nvim will see the command as """"di
            -- This does not seem to cause an issue, but still, limit to only this case
            return '""' .. map
        else
            return map
        end
    end, { expr = true })
end

vim.keymap.set("x", "D", '"_d', { silent = true })
vim.keymap.set("x", "C", '"_c', { silent = true })

vim.keymap.set("n", "dK", "DO<esc>p==", { silent = true })
-- Not necessarily a huge use case for this in and of itself, but points to the idea that
-- d, c, and y have a lot more behind them than da, di, ca, ci, ya, and yi
-- Surround was an early indicator of this
vim.keymap.set("n", "dm", "<cmd>delmarks!<cr>")

vim.api.nvim_create_autocmd("TextChanged", {
    group = vim.api.nvim_create_augroup("delete_clear", { clear = true }),
    pattern = "*",
    callback = function()
        if vim.v.operator == "d" then
            vim.cmd("echo ''")
        end
    end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
    group = vim.api.nvim_create_augroup("change_clear", { clear = true }),
    pattern = "*",
    callback = function()
        if vim.v.operator == "c" then
            vim.cmd("echo ''")
        end
    end,
})

-- FUTURE: No strong use case for this at the moment, but could use reges 1-9 as a yank ring for
-- all yank commands, not just delete or change. But this could potentially create more conflicts
-- under the hood
vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("yank_cleanup", { clear = true }),
    callback = function()
        if vim.v.event.operator == "y" then
            vim.cmd("norm! `z")
        end

        -- We want to suppress any "X lines yanked" messages
        vim.cmd("echo ''")

        -- The below assumes that the default clipboard is not set to unnamed plus:
        -- All yanks write to unnamed if a register is not specified
        -- If the yank command is used, the latest yank also writes to reg 0
        -- The latest delete or change also writes to reg 1 or - (:h quote_number)
        -- If you delete or change to unnamed explicitly, it will also write to reg 0
        --- (the default writes to reg 1 are preserved. Not so with reg -. Acceptable loss)
        -- The code below assumes that deletes/changes to unnamed are explicit
        -- When explicitly yanking to a register other than unnamed, unnamed is still overwritten
        --- (except for the black hole register)
        -- To override this, the code below copies back from reg 0
        -- When using a yank cmd without specifying a register, vim.v.event.regname shows "
        -- When using a delete or change without specifying, regname shows nothing
        -- regname will show a register for delete/change if one is specified
        -- If yanking to the black hole register with any method, regname will show nothing
        -- Therefore, do not copy from reg 0 if regname is '"' or ""
        if vim.v.event.regname ~= '"' and vim.v.event.regname ~= "" then
            vim.fn.setreg('"', vim.fn.getreg("0"))
        end
    end,
})

-- Set mark with the API so vim.v.count1 and vim.v.register don't need to be manually added
-- to the return
vim.keymap.set("n", "y", function()
    set_z_at_cursor()
    return "y"
end, { silent = true, expr = true })

vim.keymap.set("x", "y", function()
    set_z_at_cursor()
    return "y"
end, { silent = true, expr = true })

vim.keymap.set("n", "gy", function()
    set_z_at_cursor()
    return '"+y'
end, { silent = true, expr = true })

vim.keymap.set("x", "Y", function()
    set_z_at_cursor()
    return '"+y'
end, { silent = true, expr = true })

-- Nvim sets Y to be equivalent to y$ through a lua runtime file (:h default-mappings)
-- Equivalent of Neovim Y behavior must be mapped manually
vim.keymap.set("n", "Y", function()
    set_z_at_cursor()
    return "y$"
end, { silent = true, expr = true })

vim.keymap.set("n", "gY", function()
    set_z_at_cursor()
    return '"+y$'
end, { silent = true, expr = true })

-------------
-- Pasting --
-------------

-- NOTE: For now, I have omitted marks to return to original position. This is more consistent
-- with the behavior of other text editors. Can add them back in if it becomes annoying

-- NOTE: I had previously added code to the text ftplugin file to not autoformat certain pastes
-- If we see wonky formatting issues again, add an ftdetect here instead to avoid code duplication

---@param reg string
---@return boolean
local should_format_paste = function(reg)
    if vim.api.nvim_get_current_line():match("^%s*$") then
        return true
    end

    if vim.fn.getregtype(reg or '"') == "V" then
        return true
    end

    local cur_mode = vim.api.nvim_get_mode().mode ---@type string
    if cur_mode == "V" or cur_mode == "Vs" then
        return true
    end

    return false
end

local better_norm_pastes = {
    { "p", nil },
    { "P", nil },
    { "gp", "+" },
    { "gP", "+" },
}

for _, map in pairs(better_norm_pastes) do
    vim.keymap.set("n", map[1], function()
        local reg = map[2] or vim.v.register or '"' ---@type string

        ---@type string
        local paste_cmd = "<cmd>silent norm! " .. vim.v.count1 .. '"' .. reg .. map[1] .. "<cr>"
        if should_format_paste(reg) then
            return paste_cmd .. "<cmd>silent norm! `[=`]<cr>"
        else
            return paste_cmd
        end
    end, { expr = true, silent = true })
end

-- Visual pastes do not need any additional contrivances in order to run silently, as they
-- run a delete under the hood, which triggers the TextChanged autocmd for deletes
vim.keymap.set("x", "p", function()
    if should_format_paste(vim.v.register) then
        return "Pmz<cmd>silent norm! `[=`]`z<cr>"
    else
        return "P"
    end
end, { silent = true, expr = true })

vim.keymap.set("x", "P", function()
    if should_format_paste("+") then
        return '"+Pmz<cmd>silent norm! `[=`]`z<cr>'
    else
        return '"+P'
    end
end, { silent = true, expr = true })

-----------------------
-- Text Manipulation --
-----------------------

-- Good Primeagen map, but not sure what to set it for
-- vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

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
    local vcount1 = vim.v.count1 ---@type integer -- Get before leaving visual mode
    vim.cmd('exec "silent norm! \\<esc>"') -- Force update of '< and '> marks

    opts = opts or {}
    local fix_num = opts.upward and 1 or 0
    local cmd_start = opts.upward and "'<,'> m '<-" or "'<,'> m '>+"

    local offset = 0 ---@type integer
    if vcount1 > 1 and opts.upward then
        offset = vim.fn.line(".") - vim.fn.line("'<")
    elseif vcount1 > 1 and not opts.upward then
        offset = vim.fn.line("'>") - vim.fn.line(".")
    end

    local status, result = pcall(function()
        vim.cmd("silent " .. cmd_start .. (vcount1 + fix_num - offset))
    end) ---@type boolean, unknown|nil

    if status then
        local end_row = vim.api.nvim_buf_get_mark(0, "]")[1] ---@type integer
        ---@type integer
        local end_col = #vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)[1]
        vim.api.nvim_buf_set_mark(0, "z", end_row, end_col, {})
        vim.cmd("silent norm! `[=`z")
    else
        vim.api.nvim_echo({ { result or "Unknown error in visual_move" } }, true, { err = true })
    end

    vim.cmd("norm! gv")
    vim.opt.lazyredraw = false
end

vim.keymap.set("x", "J", function()
    visual_move()
end)

vim.keymap.set("x", "K", function()
    visual_move({ upward = true })
end)

-- Done using a function to prevent nag when shifting multiple lines
---@param opts? table
---@return nil
local visual_indent = function(opts)
    vim.opt.lazyredraw = true
    vim.opt_local.cursorline = false

    local count = vim.v.count1
    opts = opts or {}
    local shift = opts.back and "<" or ">"

    vim.cmd('exec "silent norm! \\<esc>"')
    vim.cmd("silent '<,'> " .. string.rep(shift, count))
    vim.cmd("silent norm! gv")

    vim.opt_local.cursorline = true
    vim.opt.lazyredraw = false
end

vim.keymap.set("x", "<", function()
    visual_indent({ back = true })
end, { silent = true })

vim.keymap.set("x", ">", function()
    visual_indent()
end, { silent = true })

-- I don't know a better place to put this
vim.keymap.set("n", "zg", "<cmd>silent norm! zg<cr>", { silent = true })

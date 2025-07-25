local ut = require("mjm.utils")

--------------------
-- Mode Switching --
--------------------

-- Mapping <C-c> to <esc> in cmd mode causes <C-C> to accept commands rather than cancel them
-- omapped so that Quickscope highlighting properly exits
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

    -- Allows <C-c> to exit commands with a count. Also eliminates command line nag
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

-----------------
-- Insert Mode --
-----------------

-- TODO: Where should this go?
-- vim.keymap.set("i", "<C-e>", "<C-o>ze", { silent = true })

vim.keymap.set("i", "<C-a>", "<C-o>_")
vim.keymap.set("i", "<C-k>", "<C-o>D")
vim.keymap.set("i", "<C-e>", "<C-o>$")

-- Ideas:
-- - <M-f>/<M-b> (forward and backward one word)

-------------------------
-- Saving and Quitting --

-- FUTURE: These maps should save the `[`] marks. This cannot be done using an autocmd because
-- they are altered too early. But with these maps it should be possible. But we would need
-- a way to calculate their new positions after formatters run. There is Neovim code for
-- LSP formatting that might be able to handle this. I think conform uses a version of this
-- as well

-------------------------

vim.keymap.set("n", "ZZ", function()
    if ut.check_modifiable() then
        vim.cmd("silent up")
    end
end)

vim.keymap.set("n", "ZQ", function()
    if ut.check_modifiable() then
        vim.cmd("silent wq")
    end
end)

vim.keymap.set("n", "ZA", "<cmd>silent wa<cr>")
vim.keymap.set("n", "ZX", function()
    if not ut.check_modifiable() then
        return
    end

    local status, result = pcall(function() ---@type boolean, unknown|nil
        vim.cmd("silent up | so")
    end)

    if status then
        return
    end

    vim.api.nvim_echo({ { result or "Unknown error on save and source" } }, true, { err = true })
end)

for _, map in pairs({ "<C-w>q", "<C-w><C-q>" }) do
    vim.keymap.set("n", map, function()
        local buf = vim.api.nvim_get_current_buf() ---@type integer
        local buf_wins = 0 ---@type integer
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_buf(win) == buf then
                buf_wins = buf_wins + 1
            end
        end

        local cmd = buf_wins > 1 and "silent q" or "silent up | bd"
        local status, result = pcall(function() ---@type boolean, unknown|nil
            vim.cmd(cmd)
        end)

        if not status then
            vim.notify(result or "Unknown error closing window", vim.log.levels.WARN)
        end
    end)
end

vim.keymap.set("n", "<C-z>", "<nop>")
-- This trick mostly doesn't work because it also blocks any map in the layer below it, but
-- anything under Z has to be manually mapped anyway, so this is fine
vim.keymap.set("n", "Z", "<nop>")

-------------------
-- Undo and Redo --
-------------------

vim.keymap.set("n", "u", function()
    if not ut.check_modifiable() then
        return
    end

    if vim.v.count1 > 1 then
        vim.cmd("norm! " .. vim.v.count1 .. "u")
    else
        vim.cmd("silent norm! u")
    end
end)

vim.keymap.set("n", "<C-r>", function()
    if not ut.check_modifiable() then
        return
    end

    if vim.v.count1 > 1 then
        vim.cmd('exec "norm! ' .. vim.v.count1 .. '\\<C-r>"')
    else
        vim.cmd('silent exec "norm! \\<C-r>"')
    end
end)

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
} ---@type table {[string]: string}

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
    ---@type boolean
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

-- See tmux config (mikejmcguirk/dotfiles) for reasoning and how on C-S for this mapping
for k, _ in pairs(tmux_cmd_map) do
    vim.keymap.set("n", "<C-S-" .. k .. ">", function()
        win_move_tmux(k)
    end)

    vim.keymap.set("i", "<C-S-" .. k .. ">", function()
        vim.cmd("stopinsert")
        win_move_tmux(k)
    end)
end

local good_wintypes = { "", "quickfix", "loclist" }
local resize_win = function(cmd)
    if vim.tbl_contains(good_wintypes, vim.fn.win_gettype(vim.api.nvim_get_current_win())) then
        vim.cmd(cmd)
    end
end

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

local tab = 10
for _ = 1, 10 do
    -- Need to bring tab into this scope, or else the final value of tab is
    -- used for all maps
    local this_tab = tab -- 10, 1, 2, 3, 4, 5, 6, 7, 8, 9
    local mod_tab = this_tab % 10 -- 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
    vim.keymap.set("n", string.format("<M-%s>", mod_tab), function()
        local ok, err = pcall(function() ---@type boolean, unknown|nil
            vim.cmd("tabn " .. this_tab)
        end)

        if not ok then
            vim.notify(err or ("Unknown error moving to " .. this_tab), vim.log.levels.ERROR)
        end
    end)

    tab = mod_tab + 1
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

vim.keymap.set("n", "'", "g`")

-- Not silent so that the search prompting displays properly
vim.keymap.set("n", "/", "ms/")
vim.keymap.set("n", "?", "ms?")
vim.keymap.set("n", "N", "Nzzzv")
vim.keymap.set("n", "n", "nzzzv")

vim.keymap.set("n", "<C-w>c", "<nop>")
vim.keymap.set("n", "<C-w><C-c>", "<nop>")

------------------
-- Text Objects --
------------------

-- Translated from justinmk from jdaddy.vim
local function whole_file()
    local line_count = vim.api.nvim_buf_line_count(0) ---@type integer
    if vim.api.nvim_buf_get_lines(0, 0, 1, true)[1] == "" and line_count == 1 then
        -- Because the omap is not an expr, we need the <esc> keycode literal
        return "'\027'"
    end

    -- get_lines result does not include \n. Subtract one because set_mark's col is 0 indexed
    local last_line_len = #vim.api.nvim_buf_get_lines(0, -2, -1, true)[1] - 1 ---@type integer
    vim.api.nvim_buf_set_mark(0, "[", 1, 0, {})
    vim.api.nvim_buf_set_mark(0, "]", line_count, last_line_len, {})

    return "'[o']g_"
end

vim.keymap.set("x", "al", function()
    return whole_file()
end, { expr = true })

vim.keymap.set("o", "al", "<cmd>normal Val<CR>", { silent = true })

vim.keymap.set("x", "il", function()
    local keys = "g_o^o" .. vim.v.count .. "g_"
    vim.api.nvim_feedkeys(keys, "ni", false)
end, { silent = true })

vim.keymap.set("o", "il", function()
    local vcount1 = vim.v.count1
    if vcount1 <= 1 then
        return vim.cmd("normal vil")
    end

    vim.cmd("normal v" .. vcount1 .. "il")
end, { silent = true })

--------------------------
-- Yank, Change, Delete --
--------------------------

vim.keymap.set({ "n", "x" }, "x", '"_x', { silent = true })
vim.keymap.set("n", "X", '"_X', { silent = true })
vim.keymap.set("x", "X", 'd0"_Dp==', { silent = true })

-- FUTURE: These should remove trailing whitespace from the original line. The == should handle
-- invalid leading whitespace on the new line
vim.keymap.set("n", "dJ", "Do<esc>p==", { silent = true })
vim.keymap.set("n", "dK", "DO<esc>p==", { silent = true })
vim.keymap.set("n", "dm", "<cmd>delmarks!<cr>")

-----------------------
-- Text Manipulation --
-----------------------

-- Credit ThePrimeagen
vim.keymap.set("n", "g%", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

vim.keymap.set("n", "gV", "`[v`]")

-- FUTURE: I'm not sure why, but this properly handles being on the very top line
-- This could also handle whitespace/comments/count/view, but is fine for now as a quick map
vim.keymap.set("n", "H", 'mzk_D"_ddA <esc>p`zze', { silent = true })
vim.keymap.set("n", "J", function()
    if not ut.check_modifiable() then
        return
    end

    -- Done using a view instead of a mark to prevent visible screen shake
    local view = vim.fn.winsaveview() ---@type vim.fn.winsaveview.ret
    -- By default, [count]J joins one fewer lines than indicated by the relative line numbers
    local count = vim.v.count1 + 1 ---@type integer
    vim.cmd("norm! " .. count .. "J")
    vim.fn.winrestview(view)
end, { silent = true })

-- FUTURE: Do this with the API so it's dot-repeatable
---@param opts? table(upward:boolean)
---@return nil
local visual_move = function(opts)
    if not ut.check_modifiable() then
        return
    end

    local cur_mode = vim.api.nvim_get_mode().mode ---@type string
    if cur_mode ~= "V" and cur_mode ~= "Vs" then
        return vim.notify("Not in visual line mode", vim.log.levels.WARN)
    end

    vim.opt.lazyredraw = true
    opts = opts or {}
    -- Get before leaving visual mode
    local vcount1 = vim.v.count1 + (opts.upward and 1 or 0) ---@type integer
    local cmd_start = opts.upward and "silent '<,'>m '<-" or "silent '<,'>m '>+"
    vim.cmd('exec "silent norm! \\<esc>"') -- Force the '< and '> marks to update

    local offset = 0 ---@type integer
    if vcount1 > 2 and opts.upward then
        offset = vim.fn.line(".") - vim.fn.line("'<")
    elseif vcount1 > 1 and not opts.upward then
        offset = vim.fn.line("'>") - vim.fn.line(".")
    end

    local status, result = pcall(function()
        local cmd = cmd_start .. (vcount1 - offset)
        vim.cmd(cmd)
    end) ---@type boolean, unknown|nil

    if status then
        local row_1 = vim.api.nvim_buf_get_mark(0, "]")[1] ---@type integer
        local row_0 = row_1 - 1
        local end_col = #vim.api.nvim_buf_get_lines(0, row_0, row_1, false)[1] ---@type integer
        vim.api.nvim_buf_set_mark(0, "]", row_1, end_col, {})
        vim.cmd("silent norm! `[=`]")
    else
        vim.api.nvim_echo({ { result or "Unknown error in visual_move" } }, true, { err = true })
    end

    vim.cmd("norm! gv")
    vim.opt.lazyredraw = false
end

vim.keymap.set("n", "<C-j>", function()
    if not ut.check_modifiable() then
        return
    end

    local vcount1 = vim.v.count1 -- Need to grab this first
    vim.cmd("m+" .. vcount1 .. " | norm! ==")
end)

vim.keymap.set("n", "<C-k>", function()
    if not ut.check_modifiable() then
        return
    end

    local vcount1 = vim.v.count1 + 1 -- Since the base count to go up is -2
    vim.cmd("m-" .. vcount1 .. " | norm! ==")
end)

vim.keymap.set("x", "<C-j>", function()
    visual_move()
end)

vim.keymap.set("x", "<C-k>", function()
    visual_move({ upward = true })
end)

-- Done as a function to suppress a nag when shifting multiple lines
---@param opts? table
---@return nil
local visual_indent = function(opts)
    vim.opt.lazyredraw = true
    vim.opt_local.cursorline = false

    local count = vim.v.count1 ---@type integer
    opts = opts or {}
    local shift = opts.back and "<" or ">" ---@type string

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

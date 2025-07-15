local ut = require("mjm.utils")
local set_z_at_cursor = function()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_mark(0, "z", row, col, {})
end

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

vim.keymap.set("i", "<C-bs>", "<C-g>u<C-w>")
vim.keymap.set("i", "<C-S-bs>", "<C-g>u<C-u>")
vim.keymap.set("i", "<M-bs>", "<C-g>u<C-o>vBx")

vim.keymap.set("i", "<C-h>", "<C-o>h")
vim.keymap.set("i", "<C-j>", "<C-o>j")
vim.keymap.set("i", "<C-k>", "<C-o>k")
vim.keymap.set("i", "<C-l>", "<C-o>l")

--------------------------------
-- Layered Command Cancelling --

-- When a layered command is pressed and allowed to time out, the layered command is still
-- queued and waiting for follow-up input, the maps no longer apply
-- Disable layered commands on their own to prevent this

--------------------------------

vim.keymap.set("n", "Z", "<nop>")
vim.keymap.set("n", "[", "<nop>")
vim.keymap.set("n", "]", "<nop>")

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

-- Translated from justinmk from jdaddy.vim
local function inner_line()
    local cur_line = vim.api.nvim_get_current_line() ---@type string
    if cur_line == "" then
        -- Because the omap is not an expr, we need the <esc> keycode literal
        return "'\027'"
    end

    local row = vim.api.nvim_win_get_cursor(0)[1] ---@type integer
    local first_non_blank_col = cur_line:find("%S") or 1 ---@type integer
    first_non_blank_col = first_non_blank_col - 1
    -- #cur_line does not include \n. Subtract one because set_mark's col is 0-indexed
    local end_col = #cur_line - 1 ---@type integer
    vim.api.nvim_buf_set_mark(0, "[", row, first_non_blank_col, {})
    vim.api.nvim_buf_set_mark(0, "]", row, end_col, {})

    return "`[o`]"
end

vim.keymap.set("x", "il", function()
    return inner_line()
end, { expr = true })

vim.keymap.set("o", "il", function()
    local vcount1 = vim.v.count1
    if vcount1 <= 1 then
        return vim.cmd("normal vil")
    end

    vim.cmd("normal vil" .. vcount1 .. "jg_")
end, { silent = true })

vim.keymap.set("o", "_", "<cmd>normal v_<cr>", { silent = true })

local function find_pipe_pair(line, col)
    local function is_pipe_pair(pos)
        return line:sub(pos, pos) == "|" and line:find("|", pos + 1, true)
    end

    local start_pos, end_pos
    for i = col, 1, -1 do
        if is_pipe_pair(i) then
            start_pos = i
            end_pos = line:find("|", i + 1, true)
            break
        end
    end

    if not start_pos and line:sub(col, col) == "|" then
        for i = col, #line do
            if is_pipe_pair(i) then
                start_pos = i
                end_pos = line:find("|", i + 1, true)
                break
            end
        end
    end

    if not start_pos then
        for i = col, #line do
            if is_pipe_pair(i) then
                start_pos = i
                end_pos = line:find("|", i + 1, true)
                break
            end
        end
    end

    return start_pos, end_pos
end

local function pipe_text_object(opts)
    local line = vim.api.nvim_get_current_line() ---@type string
    if line == "" then
        return "'\027'"
    end

    local row, col = unpack(vim.api.nvim_win_get_cursor(0)) ---@type integer, integer
    local start_pos, end_pos = find_pipe_pair(line, col)
    if not start_pos or not end_pos then
        return "'\027'"
    end

    opts = opts or {}
    local start_col, end_col
    if opts.outer then
        start_col = start_pos - 1
        end_col = end_pos - 1
        if end_pos < #line and line:sub(end_pos + 1, end_pos + 1):match("%s") then
            end_col = end_col + 1
        elseif start_pos > 1 and line:sub(start_pos - 1, start_pos - 1):match("%s") then
            start_col = start_col - 1
        end
    else
        start_col = start_pos
        end_col = end_pos - 2
    end

    if start_col < 0 then
        start_col = 0
    end

    if end_col >= #line then
        end_col = #line - 1
    end

    vim.api.nvim_buf_set_mark(0, "[", row, start_col, {})
    vim.api.nvim_buf_set_mark(0, "]", row, end_col, {})
    return "`[o`]"
end

vim.keymap.set("x", "i|", function()
    return pipe_text_object()
end, { expr = true })

vim.keymap.set("x", "a|", function()
    return pipe_text_object({ outer = true })
end, { expr = true })

vim.keymap.set("o", "i|", "<cmd>normal vi|<cr>")

vim.keymap.set("o", "a|", "<cmd>normal va|<cr>")

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
} ---@type table string[]

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

vim.keymap.set("n", "ss", "VP==", { silent = true })

-- FUTURE: No strong use case for this at the moment, but could use reges 1-9 as a yank ring for
-- all yank commands, not just delete or change. But this could potentially create more conflicts
-- under the hood
vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("yank_cleanup", { clear = true }),
    callback = function(ev)
        if vim.v.event.operator == "y" then
            local mark = vim.api.nvim_buf_get_mark(ev.buf, "z")
            vim.api.nvim_buf_del_mark(ev.buf, "z")
            local win = vim.api.nvim_get_current_win()
            local win_buf = vim.api.nvim_win_get_buf(win)
            if win_buf == ev.buf then
                vim.api.nvim_win_set_cursor(win, mark)
            end
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

-- FUTURE: Consider making a custom operator for these. It should be possible to
-- store cursor position in some form of state that's not a mark, like the substitute plugin does

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
            return paste_cmd .. "<cmd>silent norm! mz`[=`]`z<cr>"
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
    local view = vim.fn.winsaveview() ---@type vim.fn.winsaveview.ret
    -- By default, [count]J joins one fewer lines than indicated by the relative line numbers
    local count = vim.v.count1 + 1 ---@type integer
    vim.cmd("norm! " .. count .. "J")
    vim.fn.winrestview(view)
end, { silent = true })

-- Future: It would be better if the visual move were done with vim.fn.line("v"), which would
-- avoid the contrivance of leaving visual mode. This would require both redoing the offset math
-- and changing the range value of the move command
-- Future: It would be cool to do all of these moves in a way that is dot-repeatable
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

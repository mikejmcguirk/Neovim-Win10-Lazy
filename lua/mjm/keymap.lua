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

-- It is fine if this is over-written with LSP goto implementation
-- FUTURE: A corner case where this could be overwritten but should not be is marksman in
-- markdown files. Can look at that if I ever use that LSP again
vim.keymap.set("n", "gI", "g^i")

-- Because I remove "o" from the fo-table
vim.keymap.set("n", "<M-o>", "A<cr>", { silent = true })
vim.keymap.set("n", "<M-O>", "A<cr><esc>ddkPA ", { silent = true }) -- FUTURE: brittle

vim.keymap.set("n", "v", "mvv", { silent = true })
vim.keymap.set("n", "V", "mvV", { silent = true })

vim.keymap.set("n", "<M-r>", "gr", { silent = true })
vim.keymap.set("n", "<M-R>", "gR", { silent = true })

------------------
-- Command Mode --
------------------

vim.keymap.set("c", "<C-a>", "<C-b>")

vim.keymap.set("c", "<C-d>", "<Del>")
-- MAYBE: FIgure out how to do <M-d> if it's really needed
vim.keymap.set(
    "c",
    "<C-k>",
    "<c-\\>estrpart(getcmdline(), 0, getcmdpos()-1)<cr>",
    { noremap = true }
)

vim.keymap.set("c", "<C-b>", "<left>")
vim.keymap.set("c", "<C-f>", "<right>")
vim.keymap.set("c", "<M-b>", "<S-left>")
vim.keymap.set("c", "<M-f>", "<S-right>")

-----------------
-- Insert Mode --
-----------------

-- FUTURE: Re-create these maps in cmd mode as well

-- Bash style typing
vim.keymap.set("i", "<C-a>", "<C-o>I")
vim.keymap.set("i", "<C-e>", "<End>")

vim.keymap.set("i", "<C-d>", "<Del>")
vim.keymap.set("i", "<M-d>", "<C-g>u<C-o>dw")
vim.keymap.set("i", "<C-k>", "<C-g>u<C-o>D")
vim.keymap.set("i", "<C-l>", "<esc>u")

vim.keymap.set("i", "<C-b>", "<left>")
vim.keymap.set("i", "<C-f>", "<right>")
vim.keymap.set("i", "<M-b>", "<S-left>")
vim.keymap.set("i", "<M-f>", "<S-right>")

vim.keymap.set("i", "<C-m>", "<C-d>")
vim.keymap.set("i", "<cr>", "<cr>") -- Remove key simplification

-- Reserve for blink
vim.keymap.set("i", "<C-y>", "<nop>")
vim.keymap.set("i", "<C-n>", "<nop>")
vim.keymap.set("i", "<C-p>", "<nop>")
vim.keymap.set("i", "<M-y>", "<nop>")
vim.keymap.set("i", "<M-n>", "<nop>")
vim.keymap.set("i", "<M-p>", "<nop>")

vim.keymap.set("i", "<C-cr>", "<nop>") -- To avoid mistypes while transitioning back

--Other stuff
vim.keymap.set("i", "<M-j>", "<Down>")
vim.keymap.set("i", "<M-k>", "<Up>")

-- M-z is too much like ctrl-z
-- vim.keymap.set("i", "<M-z>", "<C-o>ze", { silent = true })

-- i_Ctrl-v always shows the simplified form of a key, Ctrl-Shift-v must be used to show the
-- unsimplified form. Use this map since I have Ctrl-Shift-v as terminal paste
vim.keymap.set("i", "<C-q>", "<C-S-v>")

-------------------------

-- Saving and Quitting --

-- FUTURE: Save `[`] marks. Cannot be done using an autocmd because they are altered before
-- BufWritePre. Calculate changes using Nvim LSP/Conform functions
-- Have had mixed luck with lockmarks + conform formatting. Sometimes conform adjusts the
-- marks properly, sometimes it doesn't

-------------------------

-- Don't map ZQ. Running ZZ in vanilla Vim is a gaffe. ZQ not so much
vim.keymap.set("n", "ZQ", "<nop>")

vim.keymap.set("n", "ZZ", function()
    if ut.check_modifiable() then
        vim.cmd("silent up")
    end
end)

vim.keymap.set("n", "ZA", "<cmd>silent wa<cr>")
vim.keymap.set("n", "ZI", "<cmd>wqa<cr>")
vim.keymap.set("n", "ZR", function()
    vim.cmd("silent wa")
    vim.cmd("restart")
end)

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
vim.keymap.set("n", "<C-S-z>", "<nop>")

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
    vim.cmd("silent norm! " .. vim.v.count1 .. "u")
end)

vim.keymap.set("n", "<C-r>", function()
    if not ut.check_modifiable() then
        return
    end
    vim.cmd("silent norm! " .. vim.v.count1 .. "\18")
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

    if vim.fn.winnr() == start_win then
        do_tmux_move(nvim_cmd)
    end
end

-- tmux-navigator style window navigation
-- C-S because I want terminal ctrl-k and ctrl-l available
-- C-S is also something of a super layer for terminal commands, so this is a better pattern

-- See tmux config (mikejmcguirk/dotfiles) for reasoning and how on C-S for this mapping
for k, _ in pairs(tmux_cmd_map) do
    vim.keymap.set("n", "<C-S-" .. k .. ">", function()
        win_move_tmux(k)
    end)

    vim.keymap.set("i", "<C-S-" .. k .. ">", function()
        vim.cmd("stopinsert")
        win_move_tmux(k)
    end)

    vim.keymap.set("x", "<C-S-" .. k .. ">", function()
        vim.cmd("norm! \27")
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

-- Relies on a terminal protocol that can send <C-i> and <tab> separately
vim.keymap.set("n", "<tab>", "gt")
vim.keymap.set("n", "<S-tab>", "gT")
-- See :h <tab> and https://github.com/neovim/neovim/pull/17932
-- Note: This also applies to <cr>/<C-m> and <esc>/<C-[>
vim.keymap.set("n", "<C-i>", "<C-i>")

local tab = 10
for _ = 1, 10 do
    local this_tab = tab -- 10, 1, 2, 3, 4, 5, 6, 7, 8, 9
    local mod_tab = this_tab % 10 -- 0, 1, 2, 3, 4, 5, 6, 7, 8, 9

    vim.keymap.set("n", string.format("<M-%s>", mod_tab), function()
        local tabs = vim.api.nvim_list_tabpages()
        if #tabs < this_tab then
            return
        end

        vim.api.nvim_set_current_tabpage(tabs[this_tab])
    end)

    tab = mod_tab + 1
end

vim.keymap.set("n", "<C-w>c", "<nop>")
vim.keymap.set("n", "<C-w><C-c>", "<nop>")

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

vim.keymap.set({ "n", "x" }, "gg", "<nop>")
vim.keymap.set({ "n", "x", "o" }, "go", function()
    if vim.v.count < 1 then
        return "gg" -- I have startofline off, so this keeps cursor position
    else
        return "go"
    end
end, { expr = true })

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
vim.keymap.set("n", "g'", "g`")

-- Not silent so that the search prompting displays properly
vim.keymap.set("n", "/", "ms/")
vim.keymap.set("n", "?", "ms?")
vim.keymap.set("n", "N", "Nzzzv")
vim.keymap.set("n", "n", "nzzzv")

------------------
-- Text Objects --
------------------

vim.keymap.set("o", "al", function()
    vim.cmd("norm! ggVG")
end, { silent = true })

vim.keymap.set("x", "al", function()
    vim.cmd("norm! ggoVG")
end, { silent = true })

vim.keymap.set("o", "il", function()
    vim.cmd("norm! _v" .. vim.v.count1 .. "g_")
end, { silent = true })

vim.keymap.set("x", "il", function()
    local keys = "g_o^o" .. vim.v.count .. "g_"
    vim.api.nvim_feedkeys(keys, "ni", false)
end, { silent = true })

--------------------
-- Capitalization --
--------------------

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

vim.keymap.set({ "n", "x" }, "x", '"_x', { silent = true })
vim.keymap.set("n", "X", '"_X', { silent = true })
vim.keymap.set("x", "X", 'ygvV"_d<cmd>put!<cr>=`]', { silent = true })
-- TODO: Should not need the mz here if the spec-ops yank works out
-- vim.keymap.set("x", "X", 'mzygvV"_d<cmd>put!<cr>=`]', { silent = true })

vim.keymap.set("n", "ss", function()
    local count = vim.v.count1 - 1
    -- Use feedkeys so the count is not multiplied implicitly
    if count > 0 then
        vim.api.nvim_feedkeys(string.format("V%djP", count), "ni", false)
    else
        vim.api.nvim_feedkeys("VP", "ni", false)
    end
end, { silent = true })

local dc_maps = { "c", "C" }
-- local dc_maps = { "d", "c", "D", "C" }
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

-- Helix style black hole mappings
-- vim.keymap.set({ "n", "x" }, "<M-d>", '"_d', { silent = true })
vim.keymap.set({ "n", "x" }, "<M-c>", '"_c', { silent = true })
-- vim.keymap.set("n", "<M-D>", '"_D', { silent = true })
vim.keymap.set("n", "<M-C>", '"_C', { silent = true })

vim.keymap.set("x", "C", "<nop>")

-- vim.api.nvim_create_autocmd("TextChanged", {
--     group = vim.api.nvim_create_augroup("delete_clear", { clear = true }),
--     pattern = "*",
--     callback = function()
--         if vim.v.operator == "d" then
--             vim.cmd("echo ''")
--         end
--     end,
-- })

vim.api.nvim_create_autocmd("InsertEnter", {
    group = vim.api.nvim_create_augroup("change_clear", { clear = true }),
    pattern = "*",
    callback = function()
        if vim.v.operator == "c" then
            vim.cmd("echo ''")
        end
    end,
})

-- FUTURE: These should remove trailing whitespace from the original line. The == should handle
-- invalid leading whitespace on the new line
vim.keymap.set("n", "dJ", "Do<esc>p==", { silent = true })
vim.keymap.set("n", "dK", "DO<esc>p==", { silent = true })
vim.keymap.set("n", "dm", "<cmd>delmarks!<cr>")

-- Keeping around with the custom yank to move reges after deletes
vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("yank_cleanup", { clear = true }),
    callback = function()
        vim.fn.confirm(vim.inspect(vim.v.event))
        -- callback = function(ev)
        -- if vim.v.event.operator == "y" then
        --     local row, col = unpack(vim.api.nvim_buf_get_mark(ev.buf, "z"))
        --     if row and col then
        --         local count_lines = vim.api.nvim_buf_line_count(ev.buf)
        --         if row > count_lines then
        --             row = count_lines
        --         end
        --         local line_len = #vim.api.nvim_buf_get_lines(ev.buf, row - 1, row, false)[1]
        --         if line_len == 0 then
        --             col = 0
        --         elseif col >= line_len then
        --             col = line_len - 1
        --         end

        --         vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row, col })
        --     end
        -- end
        -- vim.api.nvim_buf_del_mark(ev.buf, "z")

        -- Suppress any "X lines yanked" messages
        -- vim.cmd("echo ''")

        -- The below assumes that the default clipboard is unset:
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
        --     if vim.v.event.regname ~= '"' and vim.v.event.regname ~= "" then
        --         vim.fn.setreg('"', vim.fn.getreg("0"))
        --     end
    end,
})

-- Set mark with the API so vim.v.count1 and vim.v.register don't need to be manually added
-- to the return
-- vim.keymap.set({ "n", "x" }, "y", function()
--     set_z_at_cursor()
--     return "y"
-- end, { silent = true, expr = true })

-- vim.keymap.set({ "n", "x" }, "<M-y>", function()
--     set_z_at_cursor()
--     return '"+y'
-- end, { silent = true, expr = true })

-- -- :h Y-default
-- vim.keymap.set("n", "Y", function()
--     set_z_at_cursor()
--     return "y$"
-- end, { silent = true, expr = true })

-- vim.keymap.set("n", "<M-Y>", function()
--     set_z_at_cursor()
--     return '"+y$'
-- end, { silent = true, expr = true })

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

-- local better_norm_pastes = {
--     { "p", nil },
--     { "P", nil },
--     { "<M-p>", "+" },
--     { "<M-P>", "+" },
-- }

-- for _, map in pairs(better_norm_pastes) do
--     vim.keymap.set("n", map[1], function()
--         local reg = map[2] or vim.v.register or '"' ---@type string

--         ---@type string
--         local paste_cmd = "<cmd>silent norm! " .. vim.v.count1 .. '"' .. reg .. map[1] .. "<cr>"
--         if should_format_paste(reg) then
--             return paste_cmd .. "<cmd>silent norm! mz`[=`]`z<cr>"
--         else
--             return paste_cmd
--         end
--     end, { expr = true, silent = true })
-- end

-- Visual pastes do not need any additional contrivances in order to run silently, as they
-- run a delete under the hood, which triggers the TextChanged autocmd for deletes
-- vim.keymap.set("x", "p", function()
--     if should_format_paste(vim.v.register) then
--         return "Pmz<cmd>silent norm! `[=`]`z<cr>"
--     else
--         return "P"
--     end
-- end, { silent = true, expr = true })

-- vim.keymap.set("x", "<M-p>", function()
--     if should_format_paste("+") then
--         return '"+Pmz<cmd>silent norm! `[=`]`z<cr>'
--     else
--         return '"+P'
--     end
-- end, { silent = true, expr = true })

-- vim.keymap.set("x", "P", "<nop>")

vim.keymap.set("x", "p", "P")

-----------------------
-- Text Manipulation --
-----------------------

-- Credit ThePrimeagen
vim.keymap.set("n", "g%", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

vim.keymap.set("n", "gV", "`[v`]")
vim.keymap.set("n", "g<C-v>", "`[<C-v>`]")

vim.keymap.set("n", "g?", "<nop>")

-- FUTURE: I'm not sure why, but this properly handles being on the very top line
-- This could also handle whitespace/comments/count/view, but is fine for now as a quick map
-- TODO: Find a better key for this
-- vim.keymap.set("n", "H", 'mzk_D"_ddA <esc>p`zze', { silent = true })
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
        return vim.notify("Not in visual line mode")
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
    local offset_count = vcount1 - offset

    local status, result = pcall(function()
        local cmd = cmd_start .. offset_count
        vim.cmd(cmd)
    end) ---@type boolean, unknown|nil

    if status then
        local row_1 = vim.api.nvim_buf_get_mark(0, "]")[1] ---@type integer
        local row_0 = row_1 - 1
        local end_col = #vim.api.nvim_buf_get_lines(0, row_0, row_1, false)[1] ---@type integer
        vim.api.nvim_buf_set_mark(0, "]", row_1, end_col, {})
        vim.cmd("silent norm! `[=`]")
    elseif offset_count > 1 then
        vim.api.nvim_echo({ { result or "Unknown error in visual_move" } }, true, { err = true })
    end

    vim.cmd("norm! gv")
    vim.opt.lazyredraw = false
end

vim.keymap.set(
    "x",
    "<C-=>",
    -- Has to be literally opening the cmdline or else the visual selection goes haywire
    ":s/\\%V.*\\%V./\\=eval(submatch(0))/<CR>",
    { noremap = true, silent = true }
)

vim.keymap.set("n", "<C-j>", function()
    if not ut.check_modifiable() then
        return
    end

    local vcount1 = vim.v.count1 -- Need to grab this first
    local ok, err = pcall(function()
        vim.cmd("m+" .. vcount1 .. " | norm! ==")
    end)

    if not ok then
        vim.api.nvim_echo({ { err or "Unknown error in normal move" } }, true, { err = true })
    end
end)

vim.keymap.set("n", "<C-k>", function()
    if not ut.check_modifiable() then
        return
    end

    local vcount1 = vim.v.count1 + 1 -- Since the base count to go up is -2
    local ok, err = pcall(function()
        vim.cmd("m-" .. vcount1 .. " | norm! ==")
    end)

    if not ok then
        vim.api.nvim_echo({ { err or "Unknown error in normal move" } }, true, { err = true })
    end
end)

vim.keymap.set("x", "<C-j>", function()
    visual_move()
end)

vim.keymap.set("x", "<C-k>", function()
    visual_move({ upward = true })
end)

-- TODO: A cool extension of the add space unimpaired command would be to perform it on a visual
-- selection. Easier to add space around a multi-line paste

-- Done as a function to suppress a nag when shifting multiple lines
---@param opts? table
---@return nil
local visual_indent = function(opts)
    vim.opt.lazyredraw = true
    vim.opt_local.cursorline = false

    local count = vim.v.count1 ---@type integer
    opts = opts or {}
    local shift = opts.back and "<" or ">" ---@type string

    vim.cmd("norm! \27")
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

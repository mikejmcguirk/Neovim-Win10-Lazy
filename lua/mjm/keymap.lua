-- TODO: Remove all <C-S> and <M-S> mappings
-- MAYBE: Make a convenience mapping for comment headings
-- TODO: Look at how Neovim auto-generates its docs from strings

-------------
-- Disable --
-------------

-- Cumbersome default functionality. Use for swaps as in Helix
Map("n", "(", "<nop>")
Map("n", ")", "<nop>")

-- I use this as a prefix for inserting boilerplate code. Don't want this falling back to other
-- behavior on timeout
Map("n", "<leader>-", "<nop>")

Map("n", "<C-c>", function()
    print("")
    vim.cmd("noh")
    vim.lsp.buf.clear_references()

    -- Allows <C-c> to exit commands with a count. Also eliminates command line nag
    return "<esc>"
end, { expr = true, silent = true })

------------------
-- Command Mode --
------------------

Map("c", "<C-a>", "<C-b>")
Map("c", "<C-d>", "<Del>")
Map("c", "<M-d>", "<S-right><Del>")
-- MAYBE: Figure out how to do <M-d> if it's really needed
Map("c", "<C-k>", "<c-\\>estrpart(getcmdline(), 0, getcmdpos()-1)<cr>")

Map("c", "<C-b>", "<left>")
Map("c", "<C-f>", "<right>")
Map("c", "<M-b>", "<S-left>")
Map("c", "<M-f>", "<S-right>")

Map("c", "<M-p>", "<up>")
Map("c", "<M-n>", "<down>")

-------------------------
-- Saving and Quitting --
-------------------------

-- TODO: Look at lockmarks again. Do a test conform format just by itself first

-- This trick mostly doesn't work because it also blocks any map in the layer below it, but
-- anything under Z has to be manually mapped anyway, so this is fine
Map("n", "Z", "<nop>")

Map("n", "ZQ", function()
    vim.api.nvim_cmd({ cmd = "qall", bang = true }, {})
end)

Map("n", "ZZ", "<cmd>lockmarks silent up<cr>")
Map("n", "ZA", "<cmd>lockmarks silent wa<cr>")
Map("n", "ZC", "<cmd>lockmarks wqa<cr>")
Map("n", "ZR", "<cmd>lockmarks silent wa | restart<cr>")

-- FUTURE: Can pare this down once extui is stabilized
Map("n", "ZS", function()
    if not require("mjm.utils").check_modifiable() then
        return
    end

    local status, result = pcall(function() ---@type boolean, unknown|nil
        vim.cmd("lockmarks silent up | so")
    end)

    if status then
        return
    end

    vim.api.nvim_echo({ { result or "Unknown error on save and source" } }, true, { err = true })
end)

-- TODO: Noname buffers appearing when doing this out of other tabs
-- TODO: Need more consistent behavior in terms of when windows close
for _, map in pairs({ "<C-w>q", "<C-w><C-q>" }) do
    Map("n", map, function()
        local buf = vim.api.nvim_get_current_buf() ---@type integer
        local buf_wins = 0 ---@type integer
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_buf(win) == buf then
                buf_wins = buf_wins + 1
            end
        end

        local cmd = buf_wins > 1 and "lockmarks silent up | q" or "silent up | bd"
        local status, result = pcall(function() ---@type boolean, unknown|nil
            vim.cmd(cmd)
        end)

        if not status then
            vim.notify(result or "Unknown error closing window", vim.log.levels.WARN)
        end
    end)
end

---------------------
-- Window Movement --
---------------------

---@type {[string]: string}
local tmux_cmd_map = { ["h"] = "L", ["j"] = "D", ["k"] = "U", ["l"] = "R" }

---@param direction string
---@return nil
local do_tmux_move = function(direction)
    if vim.fn.system("tmux display-message -p '#{window_zoomed_flag}'") == "1\n" then
        return
    end

    pcall(function()
        vim.fn.system([[tmux select-pane -]] .. tmux_cmd_map[direction])
    end)
end

---@param nvim_cmd string
---@return nil
local win_move_tmux = function(nvim_cmd)
    -- TODO: How to make this work in fzflua search
    if vim.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt" then
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
    Map("n", "<C-S-" .. k .. ">", function()
        win_move_tmux(k)
    end)

    Map("i", "<C-S-" .. k .. ">", function()
        vim.cmd("stopinsert")
        win_move_tmux(k)
    end)

    Map("x", "<C-S-" .. k .. ">", function()
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

Map("n", "<M-j>", function()
    resize_win("silent resize -2")
end)

Map("n", "<M-k>", function()
    resize_win("silent resize +2")
end)

Map("n", "<M-h>", function()
    resize_win("silent vertical resize -2")
end)

Map("n", "<M-l>", function()
    resize_win("silent vertical resize +2")
end)

-- Relies on a terminal protocol that can send <C-i> and <tab> separately
Map("n", "<tab>", "gt")
Map("n", "<S-tab>", "gT")
-- See :h <tab> and https://github.com/neovim/neovim/pull/17932
-- Note: This also applies to <cr>/<C-m> and <esc>/<C-[>
Map("n", "<C-i>", "<C-i>") -- Unsimplify mapping

local tab = 10
for _ = 1, 10 do
    local this_tab = tab -- 10, 1, 2, 3, 4, 5, 6, 7, 8, 9
    local mod_tab = this_tab % 10 -- 0, 1, 2, 3, 4, 5, 6, 7, 8, 9

    Map("n", string.format("<M-%s>", mod_tab), function()
        local tabs = vim.api.nvim_list_tabpages()
        if #tabs < this_tab then
            return
        end

        vim.api.nvim_set_current_tabpage(tabs[this_tab])
    end)

    tab = mod_tab + 1
end

Map("n", "<C-w>c", "<nop>")
Map("n", "<C-w><C-c>", "<nop>")

------------------
-- Setting Maps --
------------------

Map("n", "\\d", function()
    vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end)

-- \D set in diagnostic.lua to toggle virtual lines

Map("n", "\\s", function()
    local is_spell = vim.api.nvim_get_option_value("spell", { win = 0 })
    vim.api.nvim_set_option_value("spell", not is_spell, { win = 0 })
end)

Map("n", "\\w", function()
    local is_wrap = vim.api.nvim_get_option_value("wrap", { win = 0 })
    vim.api.nvim_set_option_value("wrap", not is_wrap, { win = 0 })
end)

-- TODO: The Old "Lazy Keymaps" are below. Some of this can indeed be hidden behind an autocmd, but
-- that actually needs to be gone through

--- LOW: An operator that copies text to a line. The first count would be the line to goto, and the
--- second count would be the motion could. So you would do 14gz3j to move 3j lines to line 14
--- The motion should detect if rnu is on, and do the line placements based on relative number
--- jumps if so. The issue though is that rnu is absolute value both ways. Could do gz gZ for
--- different directions, but feels hacky

--------------------
-- Mode Switching --
--------------------

-- TODO: Test mapping <C-c> to <esc> in replace mode to avoid inserting <C-c> literals

-- Mapping <C-c> to <esc> in cmd mode causes <C-C> to accept commands rather than cancel them
-- omapped so that Quickscope highlighting properly exits
Map({ "x", "o" }, "<C-c>", "<esc>", { silent = true })
-- Deal with default behavior where you type just to the bound of a window, so Nvim scrolls to
-- the next column so you can see what you're typing, but then you exit insert mode, meaning the
-- character no longer can exist, but Neovim still has you scrolled to the side
Map("i", "<C-c>", "<esc>ze")

-- "S" enters insert with the proper indent. "I" left on default behavior
for _, map in pairs({ "i", "a", "A" }) do
    Map("n", map, function()
        if string.match(vim.api.nvim_get_current_line(), "^%s*$") then
            return '"_S'
        else
            return map
        end
    end, { silent = true, expr = true })
end

Map("n", "gI", "g^i")

-- Because I remove "o" from the fo-table
-- LOW: Unmapped because of shift+alt. Unsure what a good alternative here is
-- Map("n", "<M-o>", "A<cr>", { silent = true })
-- Map("n", "<M-O>", "A<cr><esc>ddkPA ", { silent = true }) -- FUTURE: brittle

Map("n", "v", "mvv", { silent = true })
Map("n", "V", "mvV", { silent = true })

Map("n", "<M-r>", "gr", { silent = true })
-- LOW: Unmapped because of shift+alt. The default here is functionally okay, because it uses an
-- unergonomic mapping for a relatively obscure functionality. Somewhat of an anti-pattern, but
-- also fits in with stuff like gq/gQ
-- Map("n", "<M-R>", "gR", { silent = true })

-----------------
-- Insert Mode --
-----------------

-- Bash style typing
Map("i", "<C-a>", "<C-o>I")
Map("i", "<C-e>", "<End>")

Map("i", "<C-d>", "<Del>")
Map("i", "<M-d>", "<C-g>u<C-o>dw")
Map("i", "<C-k>", "<C-g>u<C-o>D")
Map("i", "<C-l>", "<esc>u")

Map("i", "<C-b>", "<left>")
Map("i", "<C-f>", "<right>")
Map("i", "<M-b>", "<S-left>")
Map("i", "<M-f>", "<S-right>")

-- Since <C-d> is remapped
Map("i", "<C-m>", "<C-d>")
-- Since autopairs remaps this
-- Map("i", "<cr>", "<cr>") -- Remove key simplification

Map("i", "<M-j>", "<down>")
Map("i", "<M-k>", "<up>")

Map("i", "<M-e>", "<C-o>ze", { silent = true })

-- i_Ctrl-v always shows the simplified form of a key, Ctrl-Shift-v must be used to show the
-- unsimplified form. Use this map since I have Ctrl-Shift-v as terminal paste
Map("i", "<C-q>", "<C-S-v>")

-------------------
-- Undo and Redo --
-------------------

Map("n", "u", function()
    return "<cmd>silent norm! " .. vim.v.count1 .. "u<cr>"
end, { expr = true })

Map("n", "<C-r>", function()
    return "<cmd>silent norm! " .. vim.v.count1 .. "\18<cr>"
end, { expr = true })

----------------
-- Navigation --
----------------

-- TODO:
-- For jumps (here and gj/gk), jumps under a certain amount should not affect the jumplist
-- Jumps over a certain amount should
-- I'm not sure what options there are to respect here though
Map({ "n", "x" }, "k", function()
    if vim.v.count == 0 then
        return "gk"
    else
        return "k"
    end
end, { expr = true, silent = true })

Map({ "n", "x" }, "j", function()
    if vim.v.count == 0 then
        return "gj"
    else
        return "j"
    end
end, { expr = true, silent = true })

-- <C--> is used as the prefix for pragma/annotation/syntax mappings. Disable in normal and
-- insert here so we don't fallback to defaults. Note that <C-v> literals still work
Map("n", "<C-->", "<nop>")
Map("i", "<C-->", "<nop>")

-- Used by mini operators
-- Map({ "n", "x" }, "gg", "<nop>")
Map("o", "gg", "<esc>")
Map({ "n", "x", "o" }, "go", function()
    if vim.v.count < 1 then
        return "gg" -- I have startofline off, so this keeps cursor position
    else
        return "go"
    end
end, { expr = true })

-- Address cursorline flickering
Map({ "n", "x" }, "<C-u>", function()
    vim.api.nvim_set_option_value("lz", true, { scope = "global" })

    local win = vim.api.nvim_get_current_win()
    local cul = vim.api.nvim_get_option_value("cul", { win = win })
    vim.api.nvim_set_option_value("cul", false, { win = win })

    vim.cmd("norm! \21zz")
    vim.api.nvim_set_option_value("cul", cul, { win = win })

    vim.api.nvim_set_option_value("lz", false, { scope = "global" })
end, { silent = true })

Map({ "n", "x" }, "<C-d>", function()
    vim.api.nvim_set_option_value("lz", true, { scope = "global" })

    local win = vim.api.nvim_get_current_win()
    local cul = vim.api.nvim_get_option_value("cul", { win = win })
    vim.api.nvim_set_option_value("cul", false, { win = win })

    vim.cmd("norm! \4zz")
    vim.api.nvim_set_option_value("cul", cul, { win = win })

    vim.api.nvim_set_option_value("lz", false, { scope = "global" })
end, { silent = true })

Map("n", "zT", function()
    vim.opt_local.scrolloff = 0
    vim.cmd("norm! zt")
    vim.opt_local.scrolloff = Scrolloff_Val
end)

Map("n", "zB", function()
    vim.opt_local.scrolloff = 0
    vim.cmd("norm! zb")
    vim.opt_local.scrolloff = Scrolloff_Val
end)

Map("n", "'", "`")
Map("n", "g'", "g`")
Map("n", "['", "[`")
Map("n", "]'", "]`")

-- Not silent so that the search prompting displays properly
Map("n", "/", "ms/")
Map("n", "?", "ms?")
Map("n", "N", "Nzzzv")
Map("n", "n", "nzzzv")

------------------
-- Text Objects --
------------------

Map("o", "a_", function()
    vim.cmd("norm! ggVG")
end, { silent = true })

Map("x", "a_", function()
    vim.cmd("norm! ggoVG")
end, { silent = true })

Map("o", "i_", function()
    vim.cmd("norm! _v" .. vim.v.count1 .. "g_")
end, { silent = true })

Map("x", "i_", function()
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
    Map("n", map, function()
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_set_mark(0, "z", row, col, {})
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
    Map("x", map, function()
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_set_mark(0, "z", row, col, {})
        return map .. "`z"
    end, { silent = true, expr = true })
end

--------------------------
-- Yank, Change, Delete --
--------------------------

Map({ "n", "x" }, "x", '"_x', { silent = true })
Map("n", "X", '"_X', { silent = true })
Map("x", "X", 'ygvV"_d<cmd>put!<cr>=`]', { silent = true })

-- FUTURE: These should remove trailing whitespace from the original line. The == should handle
-- invalid leading whitespace on the new line
Map("n", "dJ", "Do<esc>p==", { silent = true })
Map("n", "dK", function()
    vim.api.nvim_set_option_value("lz", true, { scope = "global" })
    vim.api.nvim_feedkeys("DO\27p==", "nix", false)
    vim.api.nvim_set_option_value("lz", false, { scope = "global" })
end)
Map("n", "dm", "<cmd>delmarks!<cr>")

-----------------------
-- Text Manipulation --
-----------------------

-- MAYBE: I'm not convinced this is a good mapping, but can't think of anything else that fits
Map("n", "<M-s>", ":'<,'>s/\\%V")
Map("x", "<M-s>", ":s/\\%V")

-- Credit ThePrimeagen
Map("n", "g%", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

Map(
    "n",
    "gV",
    '"`[" . strpart(getregtype(), 0, 1) . "`]"',
    { expr = true, replace_keycodes = false }
)

Map("n", "g?", "<nop>")

-- FUTURE: I'm not sure why, but this properly handles being on the very top line
-- This could also handle whitespace/comments/count/view, but is fine for now as a quick map
-- LOW: Find a better key for this
-- Map("n", "H", 'mzk_D"_ddA <esc>p`zze', { silent = true })
Map("n", "J", function()
    if not require("mjm.utils").check_modifiable() then
        return
    end

    -- Done using a view instead of a mark to prevent visible screen shake
    local view = vim.fn.winsaveview() ---@type vim.fn.winsaveview.ret
    -- By default, [count]J joins one fewer lines than indicated by the relative line numbers
    vim.cmd("norm! " .. vim.v.count1 + 1 .. "J")
    vim.fn.winrestview(view)
end, { silent = true })

-- FUTURE: Do this with the API so it's dot-repeatable
---@param opts? {upward:boolean}
---@return nil
local visual_move = function(opts)
    if not require("mjm.utils").check_modifiable() then
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
    vim.cmd("norm! \27") -- Update '< and '>

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

Map(
    "x",
    "<C-=>",
    -- Has to be literally opening the cmdline or else the visual selection goes haywire
    ":s/\\%V.*\\%V./\\=eval(submatch(0))/<CR>",
    { noremap = true, silent = true }
)

Map("n", "<C-j>", function()
    if not require("mjm.utils").check_modifiable() then
        return
    end

    local ok, err = pcall(function()
        vim.cmd("m+" .. vim.v.count1 .. " | norm! ==")
    end)

    if not ok then
        vim.api.nvim_echo({ { err or "Unknown error in normal move" } }, true, { err = true })
    end
end)

Map("n", "<C-k>", function()
    if not require("mjm.utils").check_modifiable() then
        return
    end

    local ok, err = pcall(function()
        vim.cmd("m-" .. vim.v.count1 + 1 .. " | norm! ==")
    end)

    if not ok then
        vim.api.nvim_echo({ { err or "Unknown error in normal move" } }, true, { err = true })
    end
end)

Map("x", "<C-j>", function()
    visual_move()
end)

Map("x", "<C-k>", function()
    visual_move({ upward = true })
end)

-- LOW: You could make this an ofunc for dot-repeating
-- FUTURE: Make a resolver for the "." and "v" getpos() values
local function add_blank_visual(up)
    vim.api.nvim_set_option_value("lz", true, { scope = "global" })

    local vcount1 = vim.v.count1
    vim.cmd("norm! \27") -- Update '< and '>

    local mark = up and "<" or ">"
    local row, col = unpack(vim.api.nvim_buf_get_mark(0, mark))
    row = up and row or row + 1
    local new_lines = {}
    for _ = 1, vcount1 do
        table.insert(new_lines, "")
    end

    vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, new_lines)

    local new_row = up and row + #new_lines or row - 1
    vim.api.nvim_buf_set_mark(0, mark, new_row, col, {})
    vim.api.nvim_cmd({ cmd = "norm", args = { "gv" }, bang = true }, {})

    vim.api.nvim_set_option_value("lz", false, { scope = "global" })
end

Map("x", "[<space>", function()
    add_blank_visual(true)
end)

Map("x", "]<space>", function()
    add_blank_visual()
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

    vim.cmd("norm! \27")
    vim.cmd("silent '<,'> " .. string.rep(shift, count))
    vim.cmd("silent norm! gv")

    vim.opt_local.cursorline = true
    vim.opt.lazyredraw = false
end

Map("x", "<", function()
    visual_indent({ back = true })
end, { silent = true })

Map("x", ">", function()
    visual_indent()
end, { silent = true })

-- I don't know a better place to put this
Map("n", "zg", "<cmd>silent norm! zg<cr>", { silent = true })

Map("n", "[s", "[w")
Map("n", "]s", "]w")

local api = vim.api
local fn = vim.fn
local set = vim.keymap.set
local uv = vim.uv
local vimv = vim.v

_G.I_Dedent = "<C-m>"

-----------------
-- LEADER MAPS --
-----------------

-- I use this as a prefix for inserting boilerplate code. Don't want this falling back to other
-- behavior on timeout
set("n", "<leader>-", "<nop>")

set("n", mjm.v.fmt_lhs, function()
    api.nvim_echo({ { "Formatter not configured" } }, true, {})
end)

--------------------------
-- MARK: NORMAL Z LAYER --
--------------------------

-- LOW: More testing on lockmarks/conform behavior

set("n", "Z", "<nop>")
set("n", "ZQ", "<cmd>qall!<cr>")
set("n", "ZR", "<cmd>restart +wqa<cr>")
set("n", "ZA", "<cmd>lockmarks silent wa<cr>")
set("n", "ZS", "<cmd>lockmarks silent up | so<cr>")
set("n", "ZZ", "<cmd>lockmarks silent up<cr>")
set("n", "ZC", "<cmd>lockmarks wqa<cr>")

set("n", "ZU", function()
    local cur_buf = api.nvim_get_current_buf()
    local ntb = require("nvim-tools.buf")
    local listed_bufs = ntb.bufs_get_filtered(function(buf)
        return buf ~= cur_buf and api.nvim_get_option_value("buflisted", { buf = buf })
    end)

    for _, buf in ipairs(listed_bufs) do
        local ok, _, _ = ntb.save(buf)
        if ok and #vim.call("win_findbuf", buf) == 0 then
            api.nvim_set_option_value("buflisted", false, { buf = buf })
            api.nvim_buf_delete(buf, { unload = true })
        end
    end
end)
-- LOW: Getting listed bufs (requires a filter) then filtering again for current buf is
-- inefficient.

----------------
-- MARK: TABS --
----------------

set("n", "[t", "gT")
set("n", "]t", "gt")
set("n", "<tab>", function()
    local vcount = vimv.count
    local count_tabpages = fn.tabpagenr("$")
    local pos = vcount == 0 and count_tabpages or math.min(vcount, count_tabpages)
    require("nvim-tools.tab").open_new_tab(nil, true, pos)
end)

set("n", "[T", function()
    local vcount = vimv.count
    if vcount > 0 then
        local count_tabpages = fn.tabpagenr("$")
        local pos = vcount == 0 and count_tabpages or math.min(vcount, count_tabpages)
        api.nvim_cmd({ cmd = "norm", args = { pos .. "gt" }, bang = true }, {})
    else
        api.nvim_cmd({ cmd = "tabrewind" }, {})
    end
end)

set("n", "]T", function()
    local vcount = vimv.count
    if vcount > 0 then
        local count_tabpages = fn.tabpagenr("$")
        local pos = vcount == 0 and count_tabpages or math.min(vcount, count_tabpages)
        api.nvim_cmd({ cmd = "norm", args = { pos .. "gt" }, bang = true }, {})
    else
        api.nvim_cmd({ cmd = "tablast" }, {})
    end
end)

set("n", "ZT", function()
    if fn.tabpagenr("$") == 1 then
        api.nvim_echo({ { "Cannot close last tabpage" } }, false, {})
        return
    end

    local vcount = vimv.count
    local args = vcount > 0 and { tostring(vcount) } or nil
    api.nvim_cmd({ cmd = "tabclose", args = args }, {})
end)

set("n", "ZB", function()
    local vcount = vimv.count
    local args = vcount > 0 and { tostring(vcount) } or nil
    api.nvim_cmd({ cmd = "tabonly", args = args }, {})
end)

----------------------------
-- MARK: Jump Corrections --
----------------------------

set({ "n", "x" }, "%", "<cmd>keepjumps norm! %<cr>")
set({ "n", "x" }, "H", "<cmd>keepjumps norm! H<cr>")
set({ "n", "x" }, "L", "<cmd>keepjumps norm! L<cr>")
set({ "n", "x" }, "M", "<cmd>keepjumps norm! M<cr>")

set({ "n", "x" }, "{", function()
    vim.cmd("keepjumps norm! " .. vimv.count1 .. "{")
end)

set({ "n", "x" }, "}", function()
    vim.cmd("keepjumps norm! " .. vimv.count1 .. "}")
end)
-- LOW: You could scan upwards for the next blank line and only set a mark if it's off the screen.
-- Avoid setting marks for now since a lot of whitespace is the typical case.

set({ "n", "x" }, "<C-f>", "m`<C-f>")
set({ "n", "x" }, "<C-b>", "m`<C-b>")

-----------------------
-- WINDOW MANAGEMENT --
-----------------------

-- MAYBE: The built-ins do not map, say <C-w>gf holding ctrl the whole way through. If this
-- becomes a problem here, can adjust
set("n", "<C-w>ge", "<cmd>fclose!<cr>")

local tmux_cmd_map = { h = "L", j = "D", k = "U", l = "R" }

---@param dir string
---@return nil
local do_tmux_move = function(dir)
    if os.getenv("TMUX") == nil then
        return
    end

    local zoom_cmd = { "tmux", "display-message", "-p", "#{window_zoomed_flag}" }
    local result = vim.system(zoom_cmd, { text = true }):wait()
    if (result.code == 0 and result.stdout == "1\n") or result.code == 124 then
        return
    end

    local cmd_parts = { "tmux", "select-pane", "-" .. tmux_cmd_map[dir] }
    vim.system(cmd_parts, { text = true, timeout = 1000 })
end

---@param dir string
---@return nil
local win_move_tmux = function(dir)
    local start_win = api.nvim_get_current_win()
    api.nvim_cmd({ cmd = "wincmd", args = { dir } }, {})
    if start_win == api.nvim_get_current_win() then
        do_tmux_move(dir)
    end
end

-- See tmux config (mikejmcguirk/dotfiles) for reasoning and how on C-S for this mapping
for k, _ in pairs(tmux_cmd_map) do
    set("n", "<C-S-" .. k .. ">", function()
        win_move_tmux(k)
    end)
end

---@param amt string
---@param vert boolean
local resize_win = function(amt, vert)
    local wintype = fn.win_gettype(0)
    if not (wintype == "" or wintype == "quickfix" or wintype == "loclist") then
        return
    end
    local old_spk = api.nvim_get_option_value("spk", { scope = "global" }) ---@type string
    api.nvim_set_option_value("spk", "topline", { scope = "global" })
    ---@type vim.api.keyset.cmd
    local cmd = { cmd = "resize", args = { amt }, mods = { silent = true, vertical = vert } }
    api.nvim_cmd(cmd, {})
    api.nvim_set_option_value("spk", old_spk, { scope = "global" })
end

---@type { [1]:string, [2]:string, [3]:boolean }[]
local resize_maps = {
    { "<M-h>", "-2", true },
    { "<M-j>", "-2", false },
    { "<M-k>", "+2", false },
    { "<M-l>", "+2", true },
}

for _, m in ipairs(resize_maps) do
    set("n", m[1], function()
        resize_win(m[2], m[3])
    end)
end

for _, map in ipairs({ "<C-w>q", "<C-w><C-q>" }) do
    set("n", map, function()
        local ntw = require("nvim-tools.win")
        local cur_win = api.nvim_get_current_win()
        local cur_buf = api.nvim_win_get_buf(cur_win)

        local ntb = require("nvim-tools.buf")
        local ok_s, err_s, hl_s = ntb.save(cur_buf)
        if not ok_s then
            err_s = err_s or ("Unknown error saving buffer " .. cur_buf)
            if not string.match(err_s, "Cannot save buftype") then
                api.nvim_echo({ { err_s, hl_s } }, true, {})
                return
            end
        end

        local _, buf_w, err_w, hl_w = ntw.protected_close(cur_win, false)
        if not buf_w then
            api.nvim_echo({ { err_w, hl_w } }, false, {})
            return
        end

        vim.schedule(function()
            if #fn.win_findbuf(buf_w) > 0 then
                return
            end

            -- FUTURE: Use wipeout when that logic is fixed
            -- https://github.com/neovim/neovim/pull/33402
            ---@type vim.api.keyset.buf_delete
            local buf_del_opts = { force = false, unload = true }
            local ok_b, err_b, hl_b = ntb.protected_del(buf_w, true, buf_del_opts)
            if not ok_b and hl_b == "ErrorMsg" then
                api.nvim_echo({ { err_b, hl_b } }, false, {})
            end
        end)
    end)
end
-- MID: This logic should be used for win/buf closing in a lot of different places, because
-- bwipe closes in all windows and close does not handle the underlying buffer data
-- - Check defaults, such as in Fugitive, to make sure this doesn't have side-effects

set("n", "<C-w>c", "<nop>")
set("n", "<C-w><C-c>", "<nop>")

---------------------
-- CAP MOTION MAPS --
---------------------

-- FUTURE: Should be fixed in spec-ops

---@type { [1]:string, [2]: string }[]
local cap_motions = {
    { "n", "~" },
    { "n", "guu" },
    { "n", "guiw" },
    { "n", "guiW" },
    { "n", "guil" },
    { "n", "gual" },
    { "n", "gUU" },
    { "n", "gUiw" },
    { "n", "gUiW" },
    { "n", "gUil" },
    { "n", "gUal" },
    { "n", "g~~" },
    { "n", "g~iw" },
    { "n", "g~il" },
    { "n", "g~al" },
    { "x", "~" },
    { "x", "g~" },
    { "x", "gu" },
    { "x", "gU" },
}

for _, m in pairs(cap_motions) do
    set(m[1], m[2], function()
        local row, col = unpack(api.nvim_win_get_cursor(0))
        api.nvim_buf_set_mark(0, "z", row, col, {})
        return m[2] .. "`z<cmd>delm z<cr>"
    end, { silent = true, expr = true })
end

---------------------------
-- SCROLLING AND JUMPING --
---------------------------

-- MID: When you zz on a line with a virtual line on the first line, it will scroll out the
-- virtual line.
-- PR: This feels like some kind of issue in the core that should actually be fixed. Unsure if
-- it's done in Lua and I can fix it, or if it needs to be done in C, which I would need to do an
-- issue for
-- MID: In the meantime, could try calculating the position for the scroll character
-- MID: PR: Related to this - k does not scroll up to the virt line

-- Address cursorline flickering. Purposefully do not implement the default count mechanic
---@param args string
local function map_scroll(lhs, args)
    set({ "n", "x" }, lhs, function()
        local old_cul = api.nvim_get_option_value("cul", { win = 0 }) ---@type boolean
        local old_lz = api.nvim_get_option_value("lz", { scope = "global" }) ---@type boolean
        api.nvim_set_option_value("lz", true, { scope = "global" })
        api.nvim_set_option_value("cul", false, { win = 0 })

        api.nvim_cmd({ cmd = "norm", args = { args }, bang = true }, {})
        api.nvim_set_option_value("cul", old_cul, { win = 0 })
        api.nvim_set_option_value("lz", old_lz, { scope = "global" })
    end)
end

map_scroll("<C-u>", "\21zz")
map_scroll("<C-d>", "\4zz")

set("o", "gg", "<esc>")
set({ "n", "x" }, "go", function()
    -- gg Retains cursor position since I keep startofline off
    return vimv.count < 1 and "m`gg" or "m`" .. vimv.count1 .. "go"
end, { expr = true })

set("o", "go", function()
    return vimv.count < 1 and "gg" or "go"
end, { expr = true })

---@param char "j"|"k"
---@param do_pc_mark fun(cur:integer, count1:integer): boolean
---@return string
local function up_down(char, do_pc_mark)
    if vimv.count == 0 then
        return "g" .. char
    end

    local cur = fn.line(".")
    local count1 = vimv.count1
    if do_pc_mark(cur, count1) then
        return "m'" .. count1 .. char -- Manually add count because m' eats the implicit one
    else
        return char
    end
end

set({ "n", "x" }, "j", function()
    return up_down("j", function(cur, count1)
        local new = math.min(cur + count1, api.nvim_buf_line_count(0))
        return new > fn.line("w$")
    end)
end, { expr = true })

set({ "n", "x" }, "k", function()
    return up_down("k", function(cur, count1)
        return math.min(cur - count1, 1) < fn.line("w0")
    end)
end, { expr = true })

-- MID: Showing the search string would be more useful when hlsearch is turned on than with n/N
-- But I'd have to make the initial output match

-- MID: N should only set a jump if you are not already in a search term. Could hack into it
-- with hlsearch status maybe
-- MID: If you hit n without hlsearch and the term is not on the screen, no feedback on what is
-- happening. Unsure how to proceed
-- For the N/n maps, when I tested this with silent = true, it does show the result/total counter
-- but not the searched term, which is the goal. Disable silent if something changes here
-- set("n", "N", function()
--     if vim.v.hlsearch == 0 then
--         vim.v.hlsearch = 1
--         return "\27"
--     else
--         return "Nzzzv"
--     end
-- end, { expr = true })
--
-- set("n", "n", function()
--     if vim.v.hlsearch == 0 then
--         vim.v.hlsearch = 1
--         return "\27"
--     else
--         return "nzzzv"
--     end
-- end, { expr = true })
set("n", "n", "nzzzv")
set("n", "N", "Nzzzv")

-- Not silent so that the search prompting displays properly
-- set("n", "/", "ms/")
-- set("n", "?", "ms?")

-- LOW: Why does [s]s navigation work in some buffers but not others?
set("n", "[w", "[s")
set("n", "]w", "]s")

set("n", "g`", "<nop>")
set("n", "g'", "g`")
set("n", "`", "<nop>")
set("n", "'", "`")
set("n", "[`", "<nop>")
set("n", "]`", "<nop>")
set("n", "['", "[`")
set("n", "]'", "]`")

-----------------------
-- NORMAL <BS> LAYER --
-----------------------

-- MAYBE: Thinking of moving these keys to the leader layer behind <bs>. These can all be set
-- from the cmdline, and stuff like diagnostic config does not fit naturally as "builtin" keymaps.
-- Counterpoint: <bs> is not an especially important namespace to free. And, this would have to
-- be considered relative to the nature of other builtins. [q]q do not "need" to be keymaps but
-- obviously make sense. Being able to toggle spell in particular is useful.

set("n", "<bs>", "<nop>")
set("n", "<bs>d", function()
    require("mjm.diagnostics").toggle_virt_lines()
end)

set("n", "<bs>s", function()
    ---@type boolean
    local cur_spell = api.nvim_get_option_value("spell", { scope = "local" })
    api.nvim_set_option_value("spell", not cur_spell, { scope = "local" })
end)

set("n", "<bs><M-s>", "<cmd>set spell?<cr>")

set("n", "<bs>w", function()
    ---@type boolean
    local cur_wrap = api.nvim_get_option_value("wrap", { scope = "local" })
    api.nvim_set_option_value("wrap", not cur_wrap, { scope = "local" })
end)

set("n", "<bs><M-w>", "<cmd>set wrap?<cr>")

-- LOW: It is incongruous that I have spellnav on [w]w (to make room for ts-text-objects) but
-- then have spell still as s here, with wrap on w. The problem is that [w]w is a valuable key
-- because it's fairly ergonamic, and there's no practical need to use it for navigating w/W
-- text objects. s is also a great key to use for a text object.

--------------------
-- MODE SWITCHING --
--------------------

-- NOTE: could not get set lmap "\3\27" to work
set("n", "<C-c>", function()
    api.nvim_cmd({ cmd = "echo", args = { '""' } }, {})
    api.nvim_cmd({ cmd = "nohlsearch" }, {})
    -- Trying auto highlight again
    -- vim.lsp.buf.clear_references()

    -- Allows <C-c> to exit commands with a count. Also eliminates command line nag
    return "<esc>"
end, { expr = true, silent = true })

set("n", "gI", "g^i")
-- "S" enters insert with the proper indent. "I" left on default behavior
-- LOW: This creates an undo point, even when exiting insert immediately
for _, map in pairs({ "i", "a", "A" }) do
    set("n", map, function()
        if string.match(api.nvim_get_current_line(), "^%s*$") then
            return '"_S'
        end

        return map
    end, { expr = true })
end

-- Since gr is used for LSP maps
-- MAYBE: The obvious mappings are move U to redo, gr to <C-r>, and gR to <M-r>. But this is a
-- non-trivial departure from vanilla vim, which is relevant in the server context. I could make
-- a server-safe vimrc, but that's more complexity
set("n", "<M-r>", "gr")

set("n", "v", "mvv")
set("n", "V", "mvV")
set("n", "<C-v>", "mv<C-v>")
set("n", "gV", "`[v`]")

-- LOW: When doing gv, first check the locations of the '< and '> marks. If gv would take you
-- past top or botline, set a pcmark

-- Deal with default behavior where you type just to the bound of a window, so Nvim scrolls to
-- the next column so you can see what you're typing, but then you exit insert mode, meaning
-- the character no longer can exist, but Neovim still has you scrolled to the side
-- NOTE: This also applies to replace mode, but not single replace char
set("i", "<C-c>", "<esc>ze")
set({ "x", "o" }, "<C-c>", "<esc>")

-----------------
-- NORMAL MODE --
-----------------

set("n", "U", "<nop>")

set({ "n" }, "<M-s>", ":'<,'>s/\\%V")
set({ "x" }, "<M-s>", ":s/\\%V")

-- FUTURE: These should remove trailing whitespace from the original line. The == should handle
-- invalid leading whitespace on the new line
-- set("n", "dJ", "Do<esc>p==", { silent = true })
-- MID: The dJ map below is more useful than the commented one above, but creates an anti-pattern.
-- You have the following "move" ideas:
-- - Take the line below and append: J
-- - Take the line above and append: unmapped
--   - This so obviously should be K, but alas
-- - Push the suffix to a new line above: dK
-- - Push the suffix to a new line below: unmapped
--   - This is basically i<cr> but in normal mode. Aside from the convenience, it feels like it
--   needs a little more, like auto-indenting, to justify itself.
-- - Push the suffix to the line below: dJ
-- - Push the suffix to the line above: unmapped
-- dH/dL might be fine here.
set("n", "dJ", "Djg_p")
-- MID: This creates two undo points
set("n", "dK", "DO\27p==", { silent = true })

-- MAYBE: This is never used
set("n", "dm", "<cmd>delmarks!<cr>")

-- LOW: Find a viable keymap for this and make it more robust to edge cases:
-- map("n", "H", 'mzk_D"_ddA <esc>p`zze', { silent = true })
set("n", "J", function()
    if not api.nvim_get_option_value("modifiable", { buf = 0 }) then
        api.nvim_echo({ { "Cannot make changes, 'modifiable' is off" } }, false, {})
    end

    local view = fn.winsaveview()
    -- By default, [count]J joins one fewer lines than indicated by the relative line numbers
    local args = { vimv.count1 + 1 .. "J" }
    api.nvim_cmd({ cmd = "norm", args = args, bang = true }, {})
    fn.winrestview(view)
end, { silent = true })

---@param upward boolean
local function mv_normal(upward)
    if not api.nvim_get_option_value("modifiable", { buf = 0 }) then
        api.nvim_echo({ { "Cannot make changes, 'modifiable' is off" } }, false, {})
    end

    local dir = upward and "-" or "+"
    local count = vimv.count1 + (upward and 1 or 0)
    local ok_m, err_m = pcall(function()
        vim.cmd("m" .. dir .. count .. " | norm! ==")
    end)

    if not ok_m then
        local err_msg = err_m or "Unknown error in normal move"
        api.nvim_echo({ { err_msg, "ErrorMsg" } }, true, {})
    end
end

set("n", "<C-j>", mv_normal)
set("n", "<C-k>", function()
    mv_normal(true)
end)

set({ "n", "x" }, "x", '"_x')
set("n", "X", '"_X')

-----------------------------
-- NORMAL UNIMPAIRED LAYER --
-----------------------------

set("n", "[;", "g;")
set("n", "];", "g,")

--------------------
-- NORMAL g LAYER --
--------------------

-- LOW: Make a map of this in visual mode that uses the same syntax but without %
-- Credit ThePrimeagen
set("n", "g%", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- set("n", "g?", "<nop>")

--------------------
-- NORMAL z LAYER --
--------------------

set("n", "zg", "<cmd>silent norm! zg<cr>")

-----------------
-- VISUAL MODE --
-----------------

-- Has to be literally opening the cmdline or else the visual selection goes haywire
local eval_cmd = ":s/\\%V.*\\%V./\\=eval(submatch(0))/<CR>"
set("x", "<C-=>", eval_cmd, { noremap = true, silent = true })

--- LOW: These can be re-written as functions. For omode, get the current line. For vmode,
--- can use getregionpos to get the boundaries and extend by count appropriately
---@param up? boolean
---@return nil
local function add_blank_visual(up)
    local vrange4 = require("nvim-tools.range").get_regionpos4(".", "v", "v", false)
    if not vrange4 then
        return
    end

    local row = up and vrange4[1] or vrange4[3] + 1 ---@type integer
    local new_lines = {} ---@type string[]
    for _ = 1, vimv.count1 do
        new_lines[#new_lines + 1] = ""
    end

    -- LOW: Currently exiting and re-selecting visual mode because new lines upward pins the
    -- visual selection to the new lines. It should be possible to calculate the adjustment of
    -- the selection without actually leaving visual mode
    local old_lz = api.nvim_get_option_value("lz", { scope = "global" }) ---@type boolean
    api.nvim_set_option_value("lz", true, { scope = "global" })
    api.nvim_cmd({ cmd = "norm", args = { "\27" }, bang = true }, {})
    api.nvim_buf_set_lines(0, row - 1, row - 1, false, new_lines)
    api.nvim_cmd({ cmd = "norm", args = { "gv" }, bang = true }, {})
    api.nvim_set_option_value("lz", old_lz, { scope = "global" })
end

set("x", "[<space>", function()
    add_blank_visual(true)
end)

set("x", "]<space>", add_blank_visual)

---@class mjm.map.VisualMoveOpts
---@field upward? boolean

---@param opts? mjm.map.VisualMoveOpts
---@return nil
local visual_move = function(opts)
    if not api.nvim_get_option_value("modifiable", { buf = 0 }) then
        api.nvim_echo({ { "Cannot make changes, 'modifiable' is off" } }, false, {})
    end

    local cur_mode = api.nvim_get_mode().mode ---@type string
    if cur_mode ~= "V" and cur_mode ~= "Vs" then
        -- MAYBE: Move into visual line mode?
        api.nvim_echo({ { "Not in visual line mode", "" } }, false, {})
        return
    end

    opts = opts or {}
    -- Get before leaving visual mode
    local vcount1 = vimv.count1 + (opts.upward and 1 or 0) ---@type integer
    local cmd_start = opts.upward and "silent '<,'>m '<-" or "silent '<,'>m '>+"
    vim.cmd("norm! \27") -- Update '< and '>

    local offset = 0 ---@type integer
    if vcount1 > 2 and opts.upward then
        offset = fn.line(".") - fn.line("'<")
    elseif vcount1 > 1 and not opts.upward then
        offset = fn.line("'>") - fn.line(".")
    end

    local offset_count = vcount1 - offset
    ---@type boolean, unknown|nil
    local status, result = pcall(function()
        local cmd = cmd_start .. offset_count
        vim.cmd(cmd)
    end)

    if status then
        local row = api.nvim_buf_get_mark(0, "]")[1] ---@type integer
        local end_col = #api.nvim_buf_get_lines(0, row - 1, row, false)[1] ---@type integer
        api.nvim_buf_set_mark(0, "]", row, end_col, {})
        vim.cmd("silent norm! `[=`]")
    elseif offset_count > 1 then
        local msg = result or "Unknown error in visual_move"
        api.nvim_echo({ { msg } }, true, { err = true })
    end

    api.nvim_cmd({ cmd = "norm", args = { "gv" }, bang = true }, {})
end

set("x", "<C-j>", visual_move)
set("x", "<C-k>", function()
    visual_move({ upward = true })
end)

-- MID: Idea: Say you have this line:
-- local foo = bar(bazz(0, 1), "buzz")
-- You should be able to do `vaf` to select bazz, then Xis to select the whole statement and trim
-- around bazz
-- This idea of omode from xmode would also support swaps. You could do viw)/foo and swap with
-- the next instance of foo. Or V)5j to swap with the line 5rnu down. Or Vj)5j to swap two lines
-- with the two lines five down.
-- The problem is with how omode's area works. The swap examples above would extend the marks
-- from the cursor to the destination, so you have no way of isolating the destination. You
-- would almost have to use on_key to capture the text objects or something.
-- (The snip example actually works with this, since in theory it would be within the text
-- object)
set("x", "X", 'ygvV"_d<cmd>put!<cr>=`]', { silent = true })

---@param lt? boolean
local visual_indent = function(lt)
    local old_cursorline = api.nvim_get_option_value("cursorline", {}) ---@type boolean
    api.nvim_set_option_value("cursorline", false, { scope = "local" })

    api.nvim_cmd({ cmd = "norm", args = { "\27" }, bang = true }, {})
    local shift = lt and "<" or ">"
    vim.cmd("silent '<,'> " .. string.rep(shift, vimv.count1))
    api.nvim_cmd({ cmd = "norm", args = { "gv" }, bang = true, mods = { silent = true } }, {})

    api.nvim_set_option_value("cursorline", old_cursorline, { scope = "local" })
end

set("x", "<", function()
    visual_indent(true)
end, { silent = true })

set("x", ">", function()
    visual_indent()
end, { silent = true })

------------
-- SYSTEM --
------------

local PERM_MASK = 511

---@param perm_bits integer
---@return string
local function mode_to_readable_perms(perm_bits)
    local perms = {}

    local bit = require("bit")

    perms[1] = bit.band(perm_bits, 256) ~= 0 and "r" or "-"
    perms[2] = bit.band(perm_bits, 128) ~= 0 and "w" or "-"
    perms[3] = bit.band(perm_bits, 64) ~= 0 and "x" or "-"

    perms[4] = bit.band(perm_bits, 32) ~= 0 and "r" or "-"
    perms[5] = bit.band(perm_bits, 16) ~= 0 and "w" or "-"
    perms[6] = bit.band(perm_bits, 8) ~= 0 and "x" or "-"

    perms[7] = bit.band(perm_bits, 4) ~= 0 and "r" or "-"
    perms[8] = bit.band(perm_bits, 2) ~= 0 and "w" or "-"
    perms[9] = bit.band(perm_bits, 1) ~= 0 and "x" or "-"

    return table.concat(perms, "")
end

---@param buf integer
local function get_file_perms(buf)
    local full_bufname = api.nvim_buf_get_name(buf)
    uv.fs_stat(full_bufname, function(err, stat)
        vim.schedule(function()
            local basename = vim.fs.basename(full_bufname)
            if err then
                local msg = "Cannot stat " .. basename .. ": " .. err
                api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
                return
            end

            if not stat then
                local msg = basename .. " does not exist"
                api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
                return
            end

            local perm_bits = bit.band(stat.mode, PERM_MASK)
            local perms = mode_to_readable_perms(perm_bits)
            local octal = string.format("%03o", perm_bits)
            api.nvim_echo({
                { basename .. ": ", "Normal" },
                { perms, "Special" },
                { " (" .. octal .. ")", "Comment" },
            }, true, {})
        end)
    end)
end

---@param plus boolean|nil
---@param layer_bits integer|string
---@return string
local function get_chmod_arg(plus, layer_bits)
    local bits = type(layer_bits) == "number" and layer_bits or tonumber(layer_bits, 8)
    if not bits then
        return ""
    end

    if bits < 0 or bits > PERM_MASK then
        error("Permission value out of range (0-777 octal)", 2)
    end

    local fmt = string.format("%03o", bits)
    return plus == nil and fmt or (plus and "+" or "-") .. fmt
end

---@param buf integer
---@param plus boolean|nil   -- true = +, false = -, nil = absolute
---@param layer_bits integer|string -- e.g. 111 (for +x/-x) or 755 (for absolute)
function chmod(buf, plus, layer_bits)
    vim.validate("layer_bits", layer_bits, { "number", "string" })
    vim.validate("plus", plus, "boolean", true)
    if fn.has("win32") == 1 then
        api.nvim_echo({ { "chmod is not supported on Windows" } }, true, {})
        return
    end

    local full_bufname = api.nvim_buf_get_name(buf)
    local cmd = { "chmod", get_chmod_arg(plus, layer_bits), full_bufname }
    vim.system(cmd, { text = true }, function(result)
        if result.code ~= 0 then
            vim.schedule(function()
                local stderr = result.stderr and result.stderr:gsub("%s+$", "") or "(no output)"
                local msg = string.format("Error(%d): %s", result.code, stderr)
                api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
            end)

            return
        end

        uv.fs_stat(full_bufname, function(err, stat)
            vim.schedule(function()
                local basename = vim.fs.basename(full_bufname)
                if err then
                    local msg = "Cannot re-stat " .. basename .. ": " .. err
                    api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
                    return
                end

                if not stat then
                    local msg = basename .. " does not exist"
                    api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
                    return
                end

                local perm_bits = bit.band(stat.mode, PERM_MASK)
                local perms = mode_to_readable_perms(perm_bits)
                local octal = string.format("%03o", perm_bits)
                api.nvim_echo({
                    { "Success: " .. basename, "Normal" },
                    { " → ", "Normal" },
                    { perms, "Special" },
                    { " (" .. octal .. ")", "Comment" },
                }, true, {})
            end)
        end)
    end)
end

local sys_leader = "/"

set("n", "<leader>" .. sys_leader .. "cc", function()
    get_file_perms(0)
end)

set("n", "<leader>" .. sys_leader .. "cx", function()
    chmod(0, true, 0b001001001)
end)

set("n", "<leader>" .. sys_leader .. "cX", function()
    chmod(0, false, 0b001001001)
end)

set("n", "<leader>" .. sys_leader .. "cw", function()
    chmod(0, true, 0b010010010)
end)

set("n", "<leader>" .. sys_leader .. "cW", function()
    chmod(0, false, 0b010010010)
end)

set("n", "<leader>" .. sys_leader .. "ce", function()
    chmod(0, true, 0b100100100)
end)

set("n", "<leader>" .. sys_leader .. "cE", function()
    chmod(0, false, 0b100100100)
end)

-----------------
-- INSERT MODE --
-----------------

set("i", "<C-q>", "<C-S-v>") -- See unsimplified char literals. Avoid terminal paste

set("i", "<C-a>", "<C-o>I")
set("i", "<C-e>", "<End>")
set("i", "<C-f>", "<right>")
set("i", "<C-b>", "<left>")
-- <S-right> goes to the beginning of the next word. This is awkward for when you want to go to
-- the end of the current word and type a new one after it. I almost never want to go to the
-- beginning of the next word and start prepending text to it. Doing an extra <C-f> is also
-- easier than <C-b>
set("i", "<M-f>", "<C-o>e<right>")
set("i", "<M-b>", "<S-left>")
set("i", "<M-j>", "<down>")
set("i", "<M-k>", "<up>")

set("i", "<M-e>", "<C-o>ze")

set("i", "<C-d>", "<Del>")
set("i", "<M-d>", "<C-g>u<C-o>de")
set("i", "<C-k>", "<C-g>u<C-o>D")
set("i", "<C-l>", "<esc><cmd>silent norm! u<cr>")
set("i", I_Dedent, "<C-d>")

-- MID: Send the CSI to make this work
-- set("i", "<M-[>", "<C-o>[")
--
-- set("i", "<M-]>", "<C-o>]")

-- set("i", "<M-[>", function()
--     api.nvim_feedkeys("\15[", "nix", false)
-- end)
--
-- set("i", "<M-]>", function()
--     api.nvim_feedkeys("\15]", "nix", false)
-- end)

------------------
-- COMMAND MODE --
------------------

-- NOTE: Setting <C-c> in cmd mode causes <C-c> to accept commands rather than cancel them
-- LOW: How to do delete word in cmd mode

set("c", "<M-p>", "<up>")

set("c", "<C-a>", "<C-b>")
set("c", "<C-d>", "<Del>")
set("c", "<C-f>", "<right>")
set("c", "<M-f>", "<S-right>")

set("c", "<C-k>", "<c-\\>estrpart(getcmdline(), 0, getcmdpos()-1)<cr>")

set("c", "<C-b>", "<left>")

set("c", "<M-b>", "<S-left>")

set("c", "<M-n>", "<down>")

-- MID: Would like a solution to the problem of opening a comment line above the current one.
-- Perhaps you just toggle the option. You could swap the fo options o and r, but that gets
-- unnatural when trying to type out multi-line comments
-- MID: Worth considering mapping [] like wincmds, so you could do <C-[><C-q> to use the cpfile
-- default, for example. It would shrink the namespace, but I'm not sure it would be practical to
-- use anyway

-- LOW: Visual mode mapping to trim whitespace from selection
-- LOW: Re-organize these by topic

-- MAYBE: Map <M-o> and <M-O> in normal mode so they are easier to use with the same map in
-- insert mode.

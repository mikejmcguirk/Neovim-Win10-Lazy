local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

local noremap = { noremap = true }

-------------
-- Disable --
-------------

-- Use for ts-text-object swaps
ApiMap("n", "(", "<nop>", noremap)
ApiMap("n", ")", "<nop>", noremap)

-------------------------
-- Saving and Quitting --
-------------------------

ApiMap("n", "Z", "<nop>", noremap)

ApiMap("n", "ZA", "<cmd>lockmarks silent wa<cr>", noremap)
ApiMap("n", "ZC", "<cmd>lockmarks wqa<cr>", noremap)
ApiMap("n", "ZR", "<cmd>lockmarks silent wa | restart<cr>", noremap)
ApiMap("n", "ZQ", "<cmd>qall!<cr>", noremap)
ApiMap("n", "ZZ", "<cmd>lockmarks silent up<cr>", noremap)

-- FUTURE: Can pare this down once extui is stabilized
Map("n", "ZS", function()
    if not ut.check_modifiable() then return end
    ---@diagnostic disable-next-line: missing-fields
    Cmd({ cmd = "update", mods = { lockmarks = true, silent = true } }, {})
    Cmd({ cmd = "source" }, {})
end)

for _, map in pairs({ "<C-w>q", "<C-w><C-q>" }) do
    Map("n", map, function()
        -- TODO: Use wipeout when that logic is fixed
        -- https://github.com/neovim/neovim/pull/33402
        ut.pclose_and_rm(vim.api.nvim_get_current_win(), false, false)
    end)
end

---------------------
-- Window Movement --
---------------------

---@type {[string]: string}
local tmux_cmd_map = { ["h"] = "L", ["j"] = "D", ["k"] = "U", ["l"] = "R" }

---@param dir string
---@return nil
local do_tmux_move = function(dir)
    if vim.fn.getenv("TMUX") == vim.NIL then return end

    local zoom_cmd = { "tmux", "display-message", "-p", "#{window_zoomed_flag}" }
    local result = vim.system(zoom_cmd, { text = true }):wait()
    if result.code == 0 and result.stdout == "1\n" then return end

    local cmd_parts = { "tmux", "select-pane", "-" .. tmux_cmd_map[dir] }
    vim.system(cmd_parts, { text = true, timeout = 1000 })
end

---@param nvim_cmd string
---@return nil
local win_move_tmux = function(nvim_cmd)
    if vim.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt" then
        do_tmux_move(nvim_cmd)
        return
    end

    local start_win = vim.api.nvim_get_current_win() ---@type integer
    vim.cmd("wincmd " .. nvim_cmd)

    if vim.api.nvim_get_current_win() == start_win then do_tmux_move(nvim_cmd) end
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

--- @param cmd vim.api.keyset.cmd
local resize_win = function(cmd)
    local wintype = vim.fn.win_gettype(vim.api.nvim_get_current_win())
    if wintype == "" or wintype == "quickfix" or wintype == "loclist" then
        local old_spk = vim.api.nvim_get_option_value("splitkeep", { scope = "global" })
        vim.api.nvim_set_option_value("spk", "topline", { scope = "global" })
        Cmd(cmd, {})
        vim.api.nvim_set_option_value("spk", old_spk, { scope = "global" })
    end
end

Map("n", "<M-h>", function()
    ---@diagnostic disable-next-line: missing-fields
    resize_win({ cmd = "resize", args = { "-2" }, mods = { silent = true, vertical = true } })
end)

Map("n", "<M-j>", function()
    ---@diagnostic disable-next-line: missing-fields
    resize_win({ cmd = "resize", args = { "-2" }, mods = { silent = true } })
end)

Map("n", "<M-k>", function()
    ---@diagnostic disable-next-line: missing-fields
    resize_win({ cmd = "resize", args = { "+2" }, mods = { silent = true } })
end)

Map("n", "<M-l>", function()
    ---@diagnostic disable-next-line: missing-fields
    resize_win({ cmd = "resize", args = { "+2" }, mods = { silent = true, vertical = true } })
end)

ApiMap("n", "<C-w>c", "<nop>", { noremap = true })
ApiMap("n", "<C-w><C-c>", "<nop>", { noremap = true })

--- MID: Missing cmds:
--- - tabclose
--- - tabnew
--- - tabmove
--- - tabonly

--- Leaves ctrl-tab/ctrl-shift-tab open
ApiMap("n", "<tab>", "gt", { noremap = true })
ApiMap("n", "<S-tab>", "gT", { noremap = true })

--- TODO: Appears I might need to manually send these down thru tmux
local tab = 10
for _ = 1, 10 do
    -- Otherwise a closure is formed around tab
    local this_tab = tab -- 10, 1, 2, 3, 4, 5, 6, 7, 8, 9
    local mod_tab = this_tab % 10 -- 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
    ApiMap("n", string.format("<M-%d>", mod_tab), "<nop>", {
        noremap = true,
        callback = function()
            local tabs = vim.api.nvim_list_tabpages()
            if #tabs < this_tab then return end

            vim.api.nvim_set_current_tabpage(tabs[this_tab])
        end,
    })

    tab = mod_tab + 1
end

------------------
-- Setting Maps --
------------------

-- d is used in diagnostic.lua

-- Prevent falling back to defaults
ApiMap("n", "\\", "<nop>", noremap)

Map("n", "\\s", function()
    local is_spell = vim.api.nvim_get_option_value("spell", { win = 0 })
    vim.api.nvim_set_option_value("spell", not is_spell, { win = 0 })
end)

Map("n", "\\w", function()
    local is_wrap = vim.api.nvim_get_option_value("wrap", { win = 0 })
    vim.api.nvim_set_option_value("wrap", not is_wrap, { win = 0 })
end)

--------------------
-- MODE SWITCHING --
--------------------

-- NOTE: could not get set lmap "\3\27" to work
Map("n", "<C-c>", function()
    print("")
    vim.cmd("noh")
    vim.lsp.buf.clear_references()

    -- Allows <C-c> to exit commands with a count. Also eliminates command line nag
    return "<esc>"
end, { expr = true, silent = true })

--- omapped so that Quickscope highlighting properly exits
Map({ "o", "x" }, "<C-c>", "<esc>")

ApiMap("n", "v", "mvv", noremap)
ApiMap("n", "V", "mvV", noremap)
ApiMap("n", "<C-v>", "mv<C-v>", noremap)

----------------
-- Navigation --
----------------

--- Keep these from adding to the jumplist. :h jump-motions

Map({ "n", "x" }, "H", "<cmd>keepjumps norm! H<cr>")
Map({ "n", "x" }, "L", "<cmd>keepjumps norm! L<cr>")
Map({ "n", "x" }, "M", "<cmd>keepjumps norm! M<cr>")
Map({ "n", "x" }, "%", "<cmd>keepjumps norm! %<cr>")

Map({ "n", "x" }, "{", function()
    local args = vim.v.count1 .. "{"
    local cmd = { cmd = "normal", args = { args }, bang = true, mods = { keepjumps = true } }
    vim.api.nvim_cmd(cmd, {})
end)

Map({ "n", "x" }, "}", function()
    local args = vim.v.count1 .. "}"
    local cmd = { cmd = "normal", args = { args }, bang = true, mods = { keepjumps = true } }
    vim.api.nvim_cmd(cmd, {})
end)

--- NOTE: the pcmark has to be set through the m command rather than the API in order to actually
--- modify the jumplist
Map({ "n", "x" }, "j", function()
    if vim.v.count == 0 then
        return "gj"
    elseif vim.v.count >= vim.api.nvim_get_option_value("lines", { scope = "global" }) then
        return "m'" .. vim.v.count1 .. "j"
    else
        return "j"
    end
end, { expr = true, silent = true })

Map({ "n", "x" }, "k", function()
    if vim.v.count == 0 then
        return "gk"
    elseif vim.v.count >= vim.api.nvim_get_option_value("lines", { scope = "global" }) then
        return "m'" .. vim.v.count1 .. "k"
    else
        return "k"
    end
end, { expr = true, silent = true })

ApiMap("o", "gg", "<esc>", noremap)
Map("o", "go", function()
    return vim.v.count < 1 and "gg" or "go"
end, { expr = true })

Map({ "n", "x" }, "go", function()
    -- gg Retains cursor position since I have startofline off
    return vim.v.count < 1 and "m'gg" or "m'" .. vim.v.count1 .. "go"
end, { expr = true })

-- Address cursorline flickering
-- Purposefully does not implement the default count mechanic in <C-u>/<C-d>, as it is painful to
-- accidently hit
Map({ "n", "x" }, "<C-u>", function()
    vim.api.nvim_set_option_value("lz", true, { scope = "global" })
    local win = vim.api.nvim_get_current_win()
    local cul = vim.api.nvim_get_option_value("cul", { win = win })
    vim.api.nvim_set_option_value("cul", false, { win = win })

    Cmd({ cmd = "normal", args = { "\21zz" }, bang = true }, {})
    vim.api.nvim_set_option_value("cul", cul, { win = win })
    vim.api.nvim_set_option_value("lz", false, { scope = "global" })
end, { silent = true })

Map({ "n", "x" }, "<C-d>", function()
    vim.api.nvim_set_option_value("lz", true, { scope = "global" })
    local win = vim.api.nvim_get_current_win()
    local cul = vim.api.nvim_get_option_value("cul", { win = win })
    vim.api.nvim_set_option_value("cul", false, { win = win })

    Cmd({ cmd = "normal", args = { "\4zz" }, bang = true }, {})
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

--- MID: These can be re-written as functions. For omode, get the current line. For vmode, can use
--- getregionpos to get the boundaries and extend by count appropriately

Map("o", "a_", "<cmd>norm! ggVG<cr>", { silent = true })
Map("x", "a_", "<cmd>norm! ggoVG<cr>", { silent = true })

Map("o", "i_", function()
    vim.cmd("norm! _v" .. vim.v.count1 .. "g_")
end, { silent = true })

Map("x", "i_", function()
    local keys = "g_o^o" .. vim.v.count .. "g_"
    vim.api.nvim_feedkeys(keys, "ni", false)
end, { silent = true })

local function map_on_bufreadpre()
    -- NOTE: I have my initial buffer set to nomodifiable, eliminating the possibility of a lot
    -- of maps being used
    -- BASELINE: Do the same

    -------------
    -- Disable --
    -------------

    -- Cumbersome default functionality. Use for swaps as in Helix
    ApiMap("n", "(", "<nop>", { noremap = true })
    ApiMap("n", ")", "<nop>", { noremap = true })

    -- I use this as a prefix for inserting boilerplate code. Don't want this falling back to other
    -- behavior on timeout
    ApiMap("n", "<leader>-", "<nop>", { noremap = true })

    --------------------
    -- Mode Switching --
    --------------------

    -- Mapping <C-c> to <esc> in cmd mode causes <C-C> to accept commands rather than cancel them

    -- Deal with default behavior where you type just to the bound of a window, so Nvim scrolls to
    -- the next column so you can see what you're typing, but then you exit insert mode, meaning
    -- the character no longer can exist, but Neovim still has you scrolled to the side
    -- NOTE: This also applies to replace mode, but not single replace char
    ApiMap("i", "<C-c>", "<esc>ze", { noremap = true })

    -- "S" enters insert with the proper indent. "I" left on default behavior
    for _, map in pairs({ "i", "a", "A" }) do
        Map("n", map, function()
            if string.match(vim.api.nvim_get_current_line(), "^%s*$") then
                return '"_S'
            else
                return map
            end
        end, { expr = true })
    end

    ApiMap("n", "gI", "g^i", noremap)
    -- NOTE: At least for now, keep the default gR mapping
    ApiMap("n", "<M-r>", "gr", noremap)
    ApiMap("n", "gr", "<nop>", noremap)

    -------------------
    -- Undo and Redo --
    -------------------

    Map("n", "u", function()
        return "<cmd>silent norm! " .. vim.v.count1 .. "u<cr>"
    end, { expr = true })

    Map("n", "<C-r>", function()
        return "<cmd>silent norm! " .. vim.v.count1 .. "\18<cr>"
    end, { expr = true })

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

    ---------------------
    --- Change/Delete ---
    ---------------------

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

    Map("n", "<M-s>", ":'<,'>s/\\%V")
    Map("x", "<M-s>", ":s/\\%V")

    -- TODO: Make a map of this in visual mode that uses the same syntax but without %
    -- Credit ThePrimeagen
    Map("n", "g%", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

    Map(
        "n",
        "gV",
        '"`[" . strpart(getregtype(), 0, 1) . "`]"',
        { expr = true, replace_keycodes = false }
    )

    Map("n", "g?", "<nop>")

    Map("n", "J", function()
        if not require("mjm.utils").check_modifiable() then return end

        -- Done using a view instead of a mark to prevent visible screen shake
        local view = vim.fn.winsaveview() ---@type vim.fn.winsaveview.ret
        -- By default, [count]J joins one fewer lines than indicated by the relative line numbers
        vim.api.nvim_cmd({ cmd = "norm", args = { vim.v.count1 + 1 .. "J" }, bang = true }, {})
        vim.fn.winrestview(view)
    end, { silent = true })

    -- FUTURE: Do this with the API so it's dot-repeatable
    ---@param opts? {upward:boolean}
    ---@return nil
    local visual_move = function(opts)
        if not require("mjm.utils").check_modifiable() then return end

        local cur_mode = vim.api.nvim_get_mode().mode ---@type string
        if cur_mode ~= "V" and cur_mode ~= "Vs" then
            vim.api.nvim_echo({ { "Not in visual line mode", "" } }, false, {})
            return
        end

        vim.api.nvim_set_option_value("lz", true, { scope = "global" })
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
            local msg = result or "Unknown error in visual_move"
            vim.api.nvim_echo({ { msg } }, true, { err = true })
        end

        vim.api.nvim_cmd({ cmd = "norm", args = { "gv" }, bang = true }, {})
        vim.api.nvim_set_option_value("lz", false, { scope = "global" })
    end

    -- Has to be literally opening the cmdline or else the visual selection goes haywire
    local eval_cmd = ":s/\\%V.*\\%V./\\=eval(submatch(0))/<CR>"
    Map("x", "<C-=>", eval_cmd, { noremap = true, silent = true })

    Map("n", "<C-j>", function()
        if not require("mjm.utils").check_modifiable() then return end

        local ok, err = pcall(function()
            vim.cmd("m+" .. vim.v.count1 .. " | norm! ==")
        end)

        if not ok then
            vim.api.nvim_echo({ { err or "Unknown error in normal move" } }, true, { err = true })
        end
    end)

    Map("n", "<C-k>", function()
        if not require("mjm.utils").check_modifiable() then return end

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

    -- Done as a function to suppress nag when shifting multiple lines
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

    -------------
    --- Spell ---
    -------------

    Map("n", "zg", "<cmd>silent norm! zg<cr>", { silent = true })
    ApiMap("n", "[w", "[s", { noremap = true })
    ApiMap("n", "]w", "]s", { noremap = true })
end

Autocmd({ "BufReadPre", "BufNewFile" }, {
    group = Augroup("keymap-setup", { clear = true }),
    once = true,
    callback = function()
        map_on_bufreadpre()
        vim.schedule(function()
            vim.api.nvim_del_augroup_by_name("keymap-setup")
        end)
    end,
})

local function map_on_cmdlineenter()
    ApiMap("c", "<C-a>", "<C-b>", noremap)
    ApiMap("c", "<C-d>", "<Del>", noremap)

    Map("c", "<C-k>", "<c-\\>estrpart(getcmdline(), 0, getcmdpos()-1)<cr>")
    ApiMap("c", "<C-b>", "<left>", noremap)
    ApiMap("c", "<C-f>", "<right>", noremap)
    ApiMap("c", "<M-b>", "<S-left>", noremap)
    ApiMap("c", "<M-f>", "<S-right>", noremap)

    ApiMap("c", "<M-p>", "<up>", noremap)
    ApiMap("c", "<M-n>", "<down>", noremap)
end

Autocmd("CmdlineEnter", {
    group = Augroup("keymap-cmdlineenter", { clear = true }),
    once = true,
    callback = function()
        map_on_cmdlineenter()
        vim.api.nvim_del_augroup_by_name("keymap-cmdlineenter")
    end,
})

local function map_on_insertenter()
    -- Bash style typing
    ApiMap("i", "<C-a>", "<C-o>I", noremap)
    ApiMap("i", "<C-e>", "<End>", noremap)
    ApiMap("i", "<C-b>", "<left>", noremap)
    ApiMap("i", "<C-f>", "<right>", noremap)
    ApiMap("i", "<M-b>", "<S-left>", noremap)
    ApiMap("i", "<M-f>", "<S-right>", noremap)

    ApiMap("i", "<C-d>", "<Del>", noremap)
    ApiMap("i", "<M-d>", "<C-g>u<C-o>dw", noremap)
    ApiMap("i", "<C-k>", "<C-g>u<C-o>D", noremap)
    ApiMap("i", "<C-l>", "<esc>u", noremap)

    -- Since <C-d> is remapped
    ApiMap("i", "<C-m>", "<C-d>", noremap)

    ApiMap("i", "<M-j>", "<down>", noremap)
    ApiMap("i", "<M-k>", "<up>", noremap)

    ApiMap("i", "<M-e>", "<C-o>ze", noremap)

    -- i_Ctrl-v always shows the simplified form of a key, Ctrl-Shift-v must be used to show the
    -- unsimplified form. Use this map since I have Ctrl-Shift-v as terminal paste
    Map("i", "<C-q>", "<C-S-v>")
end

Autocmd("InsertEnter", {
    group = Augroup("keymap-insertenter", { clear = true }),
    once = true,
    callback = function()
        map_on_insertenter()
        vim.schedule(function()
            vim.api.nvim_del_augroup_by_name("keymap-insertenter")
        end)
    end,
})

-------------------
--- Custom Cmds ---
-------------------

--- @param path string
--- @return boolean
local function is_git_tracked(path)
    if not vim.g.gitsigns_head then return false end

    local cmd = { "git", "ls-files", "--error-unmatch", "--", path }
    local output = vim.system(cmd):wait()

    return output.code == 0
end

--- @return integer|nil, string|nil
local function get_cur_buf()
    local buf = vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_echo({ { "Invalid buf", "WarningMsg" } }, true, { err = true })
        return nil, nil
    end

    local bufname = vim.api.nvim_buf_get_name(buf)
    if bufname == "" then
        vim.api.nvim_echo({ { "No bufname", "" } }, true, { err = true })
        return nil, nil
    end

    return buf, bufname
end

local function del_cur_buf_from_disk(cargs)
    local buf, bufname = get_cur_buf()
    if (not buf) or not bufname then return end

    if not cargs.bang then
        if vim.api.nvim_get_option_value("modified", { buf = buf }) then
            vim.api.nvim_echo({ { "Buf is modified", "" } }, false, {})
            return
        end
    end

    local full_bufname = vim.fn.fnamemodify(bufname, ":p")
    local is_tracked = is_git_tracked(full_bufname)

    if is_tracked then
        -- # Fugitive
        local gdelete = { cmd = "GDelete", bang = true }
        local ok, err = pcall(vim.api.nvim_cmd, gdelete, {})
        if not ok then
            local msg = err or "Unknown error performing GDelete"
            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        end
    else
        if vim.fn.delete(full_bufname) ~= 0 then
            local msg = "Failed to delete file from disk"
            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
            return
        end

        vim.api.nvim_buf_delete(buf, { force = true })
    end

    require("mjm.utils").harpoon_rm_buf({ bufname = full_bufname })
end

vim.api.nvim_create_user_command("BKill", function(cargs)
    del_cur_buf_from_disk(cargs)
end, { bang = true })

local function do_mkdir(path)
    local mkdir = vim.system({ "mkdir", "-p", path }):wait()
    if mkdir.code == 0 then return true end

    local err = mkdir.stderr or ("Cannot open " .. path)
    vim.api.nvim_echo({ { err, "ErrorMsg" } }, true, { err = true })
    return false
end

-- MID: Use vim.fs.normalize?

--- @param cargs vim.api.keyset.create_user_command.command_args
--- @return nil
local function mv_cur_buf(cargs)
    local arg = cargs.fargs[1] or ""
    if arg == "" then
        vim.api.nvim_echo({ { "No argument", "" } }, false, {})
        return
    end

    local buf, bufname = get_cur_buf()
    if (not buf) or not bufname then return end

    if (not cargs.bang) and vim.api.nvim_get_option_value("modified", { buf = buf }) then
        vim.api.nvim_echo({ { "Buf is modified", "" } }, false, {})
        return
    end

    local target = (function()
        if arg:match("[/\\]$") or vim.fn.isdirectory(arg) == 1 then
            local dir = arg:gsub("[/\\]+$", "")
            return dir .. "/" .. vim.fn.fnamemodify(bufname, ":t")
        elseif vim.fn.fnamemodify(arg, ":h") == "." then
            return vim.fn.fnamemodify(bufname, ":h") .. "/" .. arg
        else
            return arg
        end
    end)()

    local full_target = vim.fn.fnamemodify(target, ":p")
    local escape_target = vim.fn.fnameescape(full_target)
    local full_bufname = vim.fn.fnamemodify(bufname, ":p")
    local escape_bufname = vim.fn.fnameescape(full_bufname)
    if escape_target == escape_bufname then return end

    do_mkdir(vim.fn.fnamemodify(escape_target, ":h"))
    local is_tracked = is_git_tracked(escape_bufname)
    if is_tracked then
        -- # Fugitive
        local gmove = { cmd = "GMove", args = { escape_target } }
        local ok, err = pcall(vim.api.nvim_cmd, gmove, {})
        if not ok then
            local err_msg = err or "Unknown error performing GMove"
            vim.api.nvim_echo({ { err_msg, "ErrorMsg" } }, true, { err = true })
            return
        end
    else
        if vim.fn.rename(escape_bufname, escape_target) ~= 0 then
            local err_chunk = { "Failed to rename file on disk", "ErrorMsg" }
            vim.api.nvim_echo({ err_chunk }, true, { err = true })
            return
        end

        local args = { escape_target }
        local mods = { keepalt = true }
        vim.api.nvim_cmd({ cmd = "saveas", args = args, bang = true, mods = mods }, {})
    end

    for _, b in pairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(b) == bufname then
            vim.api.nvim_buf_delete(b, { force = true })
        end
    end

    require("mjm.utils").harpoon_mv_buf(escape_bufname, escape_target)
end

vim.api.nvim_create_user_command("BMove", function(cargs)
    mv_cur_buf(cargs)
end, { bang = true, nargs = 1, complete = "file_in_path" })

local function close_floats()
    for _, win in pairs(vim.fn.getwininfo()) do
        local id = win.winid
        local config = vim.api.nvim_win_get_config(id)
        if config.relative and config.relative ~= "" then vim.api.nvim_win_close(id, false) end
    end
end

vim.api.nvim_create_user_command("CloseFloats", close_floats, {})

vim.api.nvim_create_user_command("Parse", function(cargs)
    print(vim.inspect(vim.api.nvim_parse_cmd(cargs.args, {})))
end, { nargs = "+" })

local function tab_kill()
    local confirm = vim.fn.confirm(
        "This will delete all buffers in the current tab. Unsaved changes will be lost. Proceed?",
        "&Yes\n&No",
        2
    )

    if confirm ~= 1 then return end

    local buffers = vim.fn.tabpagebuflist(vim.fn.tabpagenr())
    for _, buf in pairs(buffers) do
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end
end

vim.api.nvim_create_user_command("TabKill", tab_kill, {})

vim.api.nvim_create_user_command("We", "silent up | e", {}) -- Quick refresh if Treesitter bugs out

vim.api.nvim_create_user_command("Termcode", function(cargs)
    local replaced = vim.api.nvim_replace_termcodes(cargs.args, true, true, true)
    print(vim.inspect(replaced))
end, { nargs = "+" })

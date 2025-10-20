local di = Mjm_Defer_Require("mjm.diagnostics") ---@type MjmDiags
local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

local api = vim.api
local fn = vim.fn

-------------
-- DISABLE --
-------------

-- Do these now to avoid contradicting config later

-- Use for ts-text-object swaps
Map("n", "(", "<nop>")
Map("n", ")", "<nop>")

-- I use this as a prefix for inserting boilerplate code. Don't want this falling back to other
-- behavior on timeout
Map("n", "<leader>-", "<nop>")

-- Keep the default gr mappings since I have gr renmapped to <M-r>
-- NOTE: "K" is mapped automatically when the LSP attaches, not unconditionally
Map("n", "gr", "<nop>")
if fn.maparg("gO", "n", false, false) ~= "" then api.nvim_del_keymap("n", "gO") end

-------------------------
-- SAVING AND QUITTING --
-------------------------

-- LOW: More testing on lockmarks/conform behavior

Map("n", "Z", "<nop>")

Map("n", "ZA", "<cmd>lockmarks silent wa<cr>")
Map("n", "ZC", "<cmd>lockmarks wqa<cr>")
Map("n", "ZR", "<cmd>lockmarks silent wa | restart<cr>")
Map("n", "ZQ", "<cmd>qall!<cr>")
Map("n", "ZS", "<cmd>lockmarks silent up | so<cr>")
Map("n", "ZZ", "<cmd>lockmarks silent up<cr>")

for _, map in pairs({ "<C-w>q", "<C-w><C-q>" }) do
    Map("n", map, function()
        -- TODO: Use wipeout when that logic is fixed
        -- https://github.com/neovim/neovim/pull/33402
        ut.pclose_and_rm(api.nvim_get_current_win(), false, false)
    end)
end

-------------------------------
-- WINDOW AND TAB NAVIGATION --
-------------------------------

local tmux_cmd_map = { h = "L", j = "D", k = "U", l = "R" } ---@type table<string, string>

---@param dir string
---@return nil
local do_tmux_move = function(dir)
    if fn.getenv("TMUX") == vim.NIL then return end

    local zoom_cmd = { "tmux", "display-message", "-p", "#{window_zoomed_flag}" } ---@type string[]
    local result = vim.system(zoom_cmd, { text = true }):wait() ---@type vim.SystemCompleted
    if result.code == 0 and result.stdout == "1\n" then return end

    local cmd_parts = { "tmux", "select-pane", "-" .. tmux_cmd_map[dir] } ---@type string[]
    vim.system(cmd_parts, { text = true, timeout = 1000 })
end

---@param dir string
---@return nil
local win_move_tmux = function(dir)
    -- LOW: How to make work in prompt buffers?
    if api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt" then
        do_tmux_move(dir)
        return
    end

    local start_win = api.nvim_get_current_win() ---@type integer
    Cmd({ cmd = "wincmd", args = { dir } }, {})

    if api.nvim_get_current_win() == start_win then do_tmux_move(dir) end
end

-- tmux-navigator style window navigation
-- C-S because I want terminal ctrl-k and ctrl-l available
-- C-S is also something of a super layer for terminal commands, so this is a better pattern
-- See tmux config (mikejmcguirk/dotfiles) for reasoning and how on C-S for this mapping
for k, _ in pairs(tmux_cmd_map) do
    Map({ "n", "x" }, "<C-S-" .. k .. ">", function()
        win_move_tmux(k)
    end)
end

--- @param cmd vim.api.keyset.cmd
local resize_win = function(cmd)
    local wintype = fn.win_gettype(api.nvim_get_current_win())
    if wintype == "" or wintype == "quickfix" or wintype == "loclist" then
        local old_spk = api.nvim_get_option_value("splitkeep", { scope = "global" })
        api.nvim_set_option_value("spk", "topline", { scope = "global" })
        Cmd(cmd, {})
        api.nvim_set_option_value("spk", old_spk, { scope = "global" })
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

Map("n", "<C-w>c", "<nop>")
Map("n", "<C-w><C-c>", "<nop>")

-- MID: Missing tab cmds:
-- - tabclose
-- - tabnew
-- - tabmove
-- - tabonly

Autocmd("TabNew", {
    group = Augroup("mjm-tab-maps", {}),
    once = true,
    callback = function()
        -- Leaves ctrl-tab/ctrl-shift-tab open
        -- TODO: Saw issue where these were not advancing/going back correctly
        Map("n", "<tab>", "gt")
        Map("n", "<S-tab>", "gT")

        -- MID: Appears I might need to manually send these down now thru tmux
        local tab = 10 ---@type integer
        for _ = 1, 10 do
            -- Otherwise a closure is formed around tab
            local this_tab = tab -- 10, 1, 2, 3, 4, 5, 6, 7, 8, 9
            local mod_tab = this_tab % 10 -- 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
            Map("n", string.format("<M-%d>", mod_tab), function()
                local tabs = api.nvim_list_tabpages()
                if #tabs < this_tab then return end

                api.nvim_set_current_tabpage(tabs[this_tab])
            end)

            tab = mod_tab + 1
        end
    end,
})

------------------
-- Setting Maps --
------------------

-- Do all these here so it's simple to see how the namespace is being used

Map("n", "\\", "<nop>")

Map("n", "\\d", function()
    di.toggle_diags()
end)

Map("n", "\\D", function()
    di.toggle_virt_lines()
end)

-- LOW: Could do <M-d> as errors or top only

Map("n", "\\s", function()
    local is_spell = api.nvim_get_option_value("spell", { win = 0 })
    api.nvim_set_option_value("spell", not is_spell, { win = 0 })
end)

Map("n", "\\<C-s>", "<cmd>set spell?<cr>")

Map("n", "\\w", function()
    -- LOW: How does this interact with local scope?
    local is_wrap = api.nvim_get_option_value("wrap", { win = 0 })
    api.nvim_set_option_value("wrap", not is_wrap, { win = 0 })
end)

Map("n", "\\<C-w>", "<cmd>set wrap?<cr>")

--------------------
-- MODE SWITCHING --
--------------------

-- NOTE: could not get set lmap "\3\27" to work
Map("n", "<C-c>", function()
    print("")
    Cmd({ cmd = "noh" }, {})
    vim.lsp.buf.clear_references()

    -- Allows <C-c> to exit commands with a count. Also eliminates command line nag
    return "<esc>"
end, { expr = true, silent = true })

--- omapped so that Quickscope highlighting properly exits
Map({ "o", "x" }, "<C-c>", "<esc>")

--------------------
-- BUF NAVIGATION --
--------------------

--- Keep these from adding to the jumplist. :h jump-motions

Map({ "n", "x" }, "H", "<cmd>keepjumps norm! H<cr>")
Map({ "n", "x" }, "L", "<cmd>keepjumps norm! L<cr>")
Map({ "n", "x" }, "M", "<cmd>keepjumps norm! M<cr>")
Map({ "n", "x" }, "%", "<cmd>keepjumps norm! %<cr>")

Map({ "n", "x" }, "{", function()
    local args = vim.v.count1 .. "{"
    local cmd = { cmd = "normal", args = { args }, bang = true, mods = { keepjumps = true } }
    api.nvim_cmd(cmd, {})
end)

Map({ "n", "x" }, "}", function()
    local args = vim.v.count1 .. "}"
    local cmd = { cmd = "normal", args = { args }, bang = true, mods = { keepjumps = true } }
    api.nvim_cmd(cmd, {})
end)

Map("n", "'", "`")
Map("n", "g'", "g`")
-- Just keep these all together
Map("n", "['", "[`")
Map("n", "]'", "]`")

local function map_on_bufreadpre()
    -- NOTE: I have my initial buffer set to nomodifiable, eliminating the possibility of a lot
    -- of maps being used

    --------------------
    -- MODE SWITCHING --
    --------------------

    -- Mapping <C-c> to <esc> in cmd mode causes <C-C> to accept commands rather than cancel them

    -- Deal with default behavior where you type just to the bound of a window, so Nvim scrolls to
    -- the next column so you can see what you're typing, but then you exit insert mode, meaning
    -- the character no longer can exist, but Neovim still has you scrolled to the side
    -- NOTE: This also applies to replace mode, but not single replace char
    Map("i", "<C-c>", "<esc>ze")

    Map("n", "v", "mvv")
    Map("n", "V", "mvV")
    Map("n", "<C-v>", "mv<C-v>")

    -- "S" enters insert with the proper indent. "I" left on default behavior
    for _, map in pairs({ "i", "a", "A" }) do
        Map("n", map, function()
            if string.match(api.nvim_get_current_line(), "^%s*$") then return '"_S' end
            return map
        end, { expr = true })
    end

    -- LOW: Not sure what to map to M-i
    Map("n", "gI", "g^i")
    -- NOTE: At least for now, keep the default gR mapping
    Map("n", "<M-r>", "gr")

    --------------------
    -- BUF NAVIGATION --
    --------------------

    -- NOTE: the pcmark has to be set through the m command rather than the API in order to
    -- actually modify the jumplist
    Map({ "n", "x" }, "j", function()
        if vim.v.count == 0 then return "gj" end
        if vim.v.count >= api.nvim_get_option_value("lines", { scope = "global" }) then
            return "m'" .. vim.v.count1 .. "j"
        else
            return "j"
        end
    end, { expr = true, silent = true })

    Map({ "n", "x" }, "k", function()
        if vim.v.count == 0 then return "gk" end
        if vim.v.count >= api.nvim_get_option_value("lines", { scope = "global" }) then
            return "m'" .. vim.v.count1 .. "k"
        else
            return "k"
        end
    end, { expr = true, silent = true })

    Map("o", "gg", "<esc>")
    Map("o", "go", function()
        return vim.v.count < 1 and "gg" or "go"
    end, { expr = true })

    Map({ "n", "x" }, "go", function()
        -- gg Retains cursor position since I have startofline off
        return vim.v.count < 1 and "m'gg" or "m'" .. vim.v.count1 .. "go"
    end, { expr = true })

    -- Address cursorline flickering
    -- Purposefully does not implement the default count mechanic in <C-u>/<C-d>, as it is painful
    -- to accidently hit
    ---@param cmd string
    local function scroll(cmd)
        api.nvim_set_option_value("lz", true, { scope = "global" })
        local win = api.nvim_get_current_win()
        local cul = api.nvim_get_option_value("cul", { win = win })
        api.nvim_set_option_value("cul", false, { win = win })

        Cmd({ cmd = "normal", args = { cmd }, bang = true }, {})
        api.nvim_set_option_value("cul", cul, { win = win })
        api.nvim_set_option_value("lz", false, { scope = "global" })
    end

    Map({ "n", "x" }, "<C-u>", function()
        scroll("\21zz")
    end, { silent = true })

    Map({ "n", "x" }, "<C-d>", function()
        scroll("\4zz")
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

    -- Not silent so that the search prompting displays properly
    Map("n", "/", "ms/")
    Map("n", "?", "ms?")
    Map("n", "N", "Nzzzv")
    Map("n", "n", "nzzzv")

    ------------------
    -- TEXT OBJECTS --
    ------------------

    --- MID: These can be re-written as functions. For omode, get the current line. For vmode,
    --- can use getregionpos to get the boundaries and extend by count appropriately

    Map("o", "a_", "<cmd>norm! ggVG<cr>", { silent = true })
    Map("x", "a_", "<cmd>norm! ggoVG<cr>", { silent = true })

    Map("o", "i_", function()
        vim.cmd("norm! _v" .. vim.v.count1 .. "g_")
    end, { silent = true })

    Map("x", "i_", function()
        local keys = "g_o^o" .. vim.v.count .. "g_"
        api.nvim_feedkeys(keys, "ni", false)
    end, { silent = true })

    -------------------
    -- UNDO AND REDO --
    -------------------

    Map("n", "u", function()
        return "<cmd>silent norm! " .. vim.v.count1 .. "u<cr>"
    end, { expr = true })

    Map("n", "<C-r>", function()
        return "<cmd>silent norm! " .. vim.v.count1 .. "\18<cr>"
    end, { expr = true })

    --------------------
    -- CAPITALIZATION --
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
            local row, col = unpack(api.nvim_win_get_cursor(0))
            api.nvim_buf_set_mark(0, "z", row, col, {})
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
            local row, col = unpack(api.nvim_win_get_cursor(0))
            api.nvim_buf_set_mark(0, "z", row, col, {})
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
        api.nvim_set_option_value("lz", true, { scope = "global" })
        api.nvim_feedkeys("DO\27p==", "nix", false)
        api.nvim_set_option_value("lz", false, { scope = "global" })
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

    -- TODO: Find a viable keymap for this and make it more robust to edge cases:
    -- Map("n", "H", 'mzk_D"_ddA <esc>p`zze', { silent = true })

    Map("n", "J", function()
        if not require("mjm.utils").check_modifiable() then return end

        -- Done using a view instead of a mark to prevent visible screen shake
        local view = fn.winsaveview() ---@type vim.fn.winsaveview.ret
        -- By default, [count]J joins one fewer lines than indicated by the relative line numbers
        api.nvim_cmd({ cmd = "norm", args = { vim.v.count1 + 1 .. "J" }, bang = true }, {})
        fn.winrestview(view)
    end, { silent = true })

    -- FUTURE: Do this with the API so it's dot-repeatable
    ---@param opts? {upward:boolean}
    ---@return nil
    local visual_move = function(opts)
        if not require("mjm.utils").check_modifiable() then return end

        local cur_mode = api.nvim_get_mode().mode ---@type string
        if cur_mode ~= "V" and cur_mode ~= "Vs" then
            api.nvim_echo({ { "Not in visual line mode", "" } }, false, {})
            return
        end

        api.nvim_set_option_value("lz", true, { scope = "global" })
        opts = opts or {}
        -- Get before leaving visual mode
        local vcount1 = vim.v.count1 + (opts.upward and 1 or 0) ---@type integer
        local cmd_start = opts.upward and "silent '<,'>m '<-" or "silent '<,'>m '>+"
        vim.cmd("norm! \27") -- Update '< and '>

        local offset = 0 ---@type integer
        if vcount1 > 2 and opts.upward then
            offset = fn.line(".") - fn.line("'<")
        elseif vcount1 > 1 and not opts.upward then
            offset = fn.line("'>") - fn.line(".")
        end
        local offset_count = vcount1 - offset

        local status, result = pcall(function()
            local cmd = cmd_start .. offset_count
            vim.cmd(cmd)
        end) ---@type boolean, unknown|nil

        if status then
            local row_1 = api.nvim_buf_get_mark(0, "]")[1] ---@type integer
            local row_0 = row_1 - 1
            local end_col = #api.nvim_buf_get_lines(0, row_0, row_1, false)[1] ---@type integer
            api.nvim_buf_set_mark(0, "]", row_1, end_col, {})
            vim.cmd("silent norm! `[=`]")
        elseif offset_count > 1 then
            local msg = result or "Unknown error in visual_move"
            api.nvim_echo({ { msg } }, true, { err = true })
        end

        api.nvim_cmd({ cmd = "norm", args = { "gv" }, bang = true }, {})
        api.nvim_set_option_value("lz", false, { scope = "global" })
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
            api.nvim_echo({ { err or "Unknown error in normal move" } }, true, { err = true })
        end
    end)

    Map("n", "<C-k>", function()
        if not require("mjm.utils").check_modifiable() then return end

        local ok, err = pcall(function()
            vim.cmd("m-" .. vim.v.count1 + 1 .. " | norm! ==")
        end)

        if not ok then
            api.nvim_echo({ { err or "Unknown error in normal move" } }, true, { err = true })
        end
    end)

    Map("x", "<C-j>", function()
        visual_move()
    end)

    Map("x", "<C-k>", function()
        visual_move({ upward = true })
    end)

    ---@param up? boolean
    ---@return nil
    local function add_blank_visual(up)
        local vrange4 = ut.get_vrange4() ---@type Range4|nil
        if not vrange4 then return end

        local row = up and vrange4[1] or vrange4[3] + 1
        local new_lines = {} ---@type string[]
        for _ = 1, vim.v.count1 do
            new_lines[#new_lines + 1] = ""
        end

        -- LOW: Currently exiting and re-selecting visual mode because new lines upward pins the
        -- visual selection to the new lines. It should be possible to calculate the adjustment of
        -- the selection without actually leaving visual mode
        api.nvim_set_option_value("lz", true, { scope = "global" })
        Cmd({ cmd = "norm", args = { "\27" }, bang = true }, {})
        api.nvim_buf_set_lines(0, row - 1, row - 1, false, new_lines)
        Cmd({ cmd = "norm", args = { "gv" }, bang = true }, {})
        api.nvim_set_option_value("lz", false, { scope = "global" })
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

    -- TODO: Do these as a spec-ops mapping, same in normal mode due to the nag there
    Map("x", "<", function()
        visual_indent({ back = true })
    end, { silent = true })

    Map("x", ">", function()
        visual_indent()
    end, { silent = true })

    -------------
    --- Spell ---
    -------------

    -- MID: Why does [s]s navigation work in some buffers but not others?

    Map("n", "zg", "<cmd>silent norm! zg<cr>", { silent = true })
    Map("n", "[w", "[s")
    Map("n", "]w", "]s")
end

Autocmd({ "BufReadPre", "BufNewFile" }, {
    group = Augroup("keymap-setup", { clear = true }),
    once = true,
    callback = function()
        map_on_bufreadpre()
        vim.schedule(function()
            api.nvim_del_augroup_by_name("keymap-setup")
        end)
    end,
})

-- LOW: Would like <M-d> to work properly

local function map_on_cmdlineenter()
    Map("c", "<C-a>", "<C-b>")
    Map("c", "<C-d>", "<Del>")

    Map("c", "<C-k>", "<c-\\>estrpart(getcmdline(), 0, getcmdpos()-1)<cr>")
    Map("c", "<C-b>", "<left>")
    Map("c", "<C-f>", "<right>")
    Map("c", "<M-b>", "<S-left>")
    Map("c", "<M-f>", "<S-right>")

    Map("c", "<M-p>", "<up>")
    Map("c", "<M-n>", "<down>")
end

Autocmd("CmdlineEnter", {
    group = Augroup("keymap-cmdlineenter", { clear = true }),
    once = true,
    callback = function()
        map_on_cmdlineenter()
        api.nvim_del_augroup_by_name("keymap-cmdlineenter")
    end,
})

local function map_on_insertenter()
    -- Bash style typing
    Map("i", "<C-a>", "<C-o>I")
    Map("i", "<C-e>", "<End>")
    Map("i", "<C-b>", "<left>")
    Map("i", "<C-f>", "<right>")
    Map("i", "<M-b>", "<S-left>")
    Map("i", "<M-f>", "<S-right>")

    Map("i", "<C-d>", "<Del>")
    Map("i", "<M-d>", "<C-g>u<C-o>dw")
    Map("i", "<C-k>", "<C-g>u<C-o>D")
    Map("i", "<C-l>", "<esc>u")

    -- Since <C-d> is remapped
    Map("i", "<C-m>", "<C-d>")

    Map("i", "<M-j>", "<down>")
    Map("i", "<M-k>", "<up>")

    Map("i", "<M-e>", "<C-o>ze")

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
            api.nvim_del_augroup_by_name("keymap-insertenter")
        end)
    end,
})

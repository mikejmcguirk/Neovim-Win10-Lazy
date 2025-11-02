local api = vim.api
local apimap = api.nvim_set_keymap
local di = Mjm_Defer_Require("mjm.diagnostics") ---@type MjmDiags
local fn = vim.fn
local map = vim.keymap.set
local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

-- See :h <tab> and https://github.com/neovim/neovim/pull/17932
apimap("n", "<C-i>", "<C-i>", { noremap = true })
apimap("n", "<tab>", "<tab>", { noremap = true })
apimap("n", "<C-m>", "<C-m>", { noremap = true })
apimap("n", "<cr>", "<cr>", { noremap = true })
apimap("n", "<C-[>", "<C-[>", { noremap = true })
apimap("n", "<esc>", "<esc>", { noremap = true })

-----------------
-- NORMAL MODE --
-----------------

apimap("n", "`", "<nop>", { noremap = true })
-- ~ remapped in the g layer section
apimap("x", "%", "<cmd>keepjumps norm! %<cr>", { noremap = true })

-- LOW: Appears I might need to manually send these down now thru tmux
local tab = 10 ---@type integer
for _ = 1, 10 do
    -- Otherwise a closure is formed around tab
    local this_tab = tab -- 10, 1, 2, 3, 4, 5, 6, 7, 8, 9
    local mod_tab = this_tab % 10 -- 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
    map("n", string.format("<M-%d>", mod_tab), function()
        local tabs = api.nvim_list_tabpages()
        if #tabs < this_tab then return end

        api.nvim_set_current_tabpage(tabs[this_tab])
    end)

    tab = mod_tab + 1
end

-- () are used for TS Text Object swap
-- - and + are used for oil
-- I use this as a prefix for inserting boilerplate code. Don't want this falling back to other
-- behavior on timeout
map("n", "<leader>-", "<nop>")

-- LOW: Missing tab cmds:
-- - tabclose (Z<tab>?)
-- - Would need to test tabonly before mapping it. Maybe do it as a custom function
map("n", "<tab>", "gt")
map("n", "<S-tab>", "gT")
map("n", "g<tab>", "<cmd>tabnew<cr>")
map("n", "<C-tab>", "<nop>")
map("n", "<C-S-tab>", "<nop>")

map("n", "<C-r>", function()
    return "<cmd>silent norm! " .. vim.v.count1 .. "\18<cr>"
end, { expr = true })

-- NOTE: At least for now, keep the default gR mapping
map("n", "<M-r>", "gr")

map("n", "u", function()
    return "<cmd>silent norm! " .. vim.v.count1 .. "u<cr>"
end, { expr = true })

apimap("n", "U", "<nop>", { noremap = true })
-- Address cursorline flickering
-- Purposefully does not implement the default count mechanic in <C-u>/<C-d>, as it is painful
-- to accidently hit
---@param cmd string
local function map_scroll(m, cmd)
    map({ "n", "x" }, m, function()
        local win = api.nvim_get_current_win()
        local cul = vim.api.nvim_get_option_value("cul", { win = win })
        vim.api.nvim_set_option_value("lz", true, { scope = "global" })
        vim.api.nvim_set_option_value("cul", false, { win = win })

        vim.api.nvim_cmd({ cmd = "normal", args = { cmd }, bang = true }, {})
        vim.api.nvim_set_option_value("cul", cul, { win = win })
        vim.api.nvim_set_option_value("lz", false, { scope = "global" })
    end, { silent = true })
end

map_scroll("<C-u>", "\21zz")

-- "S" enters insert with the proper indent. "I" left on default behavior
for _, m in pairs({ "i", "a", "A" }) do
    map("n", m, function()
        if string.match(api.nvim_get_current_line(), "^%s*$") then return '"_S' end
        return m
    end, { expr = true })
end

-- LOW: Not sure what to map to M-i
map({ "n", "x" }, "go", function()
    -- gg Retains cursor position since I have startofline off
    return vim.v.count < 1 and "m'gg" or "m'" .. vim.v.count1 .. "go"
end, { expr = true })

map({ "n", "x" }, "{", function()
    local args = vim.v.count1 .. "{"
    local cmd = { cmd = "normal", args = { args }, bang = true, mods = { keepjumps = true } }
    api.nvim_cmd(cmd, {})
end)

map({ "n", "x" }, "}", function()
    local args = vim.v.count1 .. "}"
    local cmd = { cmd = "normal", args = { args }, bang = true, mods = { keepjumps = true } }
    api.nvim_cmd(cmd, {})
end)

-- Create normal \ layer
map_scroll("<C-d>", "\4zz")
map("n", "\\", "<nop>")

-- a/A remapped with i
-- s used for substitution maps
apimap("n", "<M-s>", ":'<,'>s/\\%V", { noremap = true })

-- FUTURE: These should remove trailing whitespace from the original line. The == should handle
-- invalid leading whitespace on the new line
map("n", "dJ", "Do<esc>p==", { silent = true })
map("n", "dK", function()
    vim.api.nvim_set_option_value("lz", true, { scope = "global" })
    api.nvim_feedkeys("DO\27p==", "nix", false)
    vim.api.nvim_set_option_value("lz", false, { scope = "global" })
end)

map("n", "dm", "<cmd>delmarks!<cr>")
map("o", "gg", "<esc>")

local function map_vert(dir)
    map({ "n", "x" }, dir, function()
        if vim.v.count == 0 then return "g" .. dir end
        if vim.v.count >= vim.api.nvim_get_option_value("lines", { scope = "global" }) then
            return "m'" .. vim.v.count1 .. dir
        else
            return dir
        end
    end, { expr = true, silent = true })
end

map_vert("j")
map_vert("k")

local tmux_cmd_map = { h = "L", j = "D", k = "U", l = "R" } ---@type table<string, string>

---@param dir string
---@return nil
local do_tmux_move = function(dir)
    if os.getenv("TMUX") == nil then return end

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
    if vim.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt" then
        do_tmux_move(dir)
        return
    end

    local start_win = api.nvim_get_current_win() ---@type integer
    vim.api.nvim_cmd({ cmd = "wincmd", args = { dir } }, {})

    if api.nvim_get_current_win() == start_win then do_tmux_move(dir) end
end

-- tmux-navigator style window navigation
-- C-S because I want terminal ctrl-k and ctrl-l available
-- C-S is also something of a super layer for terminal commands, so this is a better pattern
-- See tmux config (mikejmcguirk/dotfiles) for reasoning and how on C-S for this mapping
for k, _ in pairs(tmux_cmd_map) do
    map({ "n", "x" }, "<C-S-" .. k .. ">", function()
        win_move_tmux(k)
    end)
end

apimap("x", "H", "<cmd>keepjumps norm! H<cr>", { noremap = true })
-- LOW: Find a viable keymap for this and make it more robust to edge cases:
-- map("n", "H", 'mzk_D"_ddA <esc>p`zze', { silent = true })
map("n", "J", function()
    if not require("mjm.utils").check_modifiable() then return end

    -- Done using a view instead of a mark to prevent visible screen shake
    local view = fn.winsaveview() ---@type vim.fn.winsaveview.ret
    -- By default, [count]J joins one fewer lines than indicated by the relative line numbers
    api.nvim_cmd({ cmd = "norm", args = { vim.v.count1 + 1 .. "J" }, bang = true }, {})
    fn.winrestview(view)
end, { silent = true })

local function mv_normal(upward)
    if not ut.check_modifiable() then return end
    local dir = upward and "-" or "+" ---@type string
    local count = vim.v.count1 + (upward and 1 or 0) ---@type integer
    local ok, err = pcall(function()
        vim.cmd("m" .. dir .. count .. " | norm! ==")
    end)

    if not ok then
        api.nvim_echo({ { err or "Unknown error in normal move" } }, true, { err = true })
    end
end

map("n", "<C-j>", mv_normal)
map("n", "<C-k>", function()
    mv_normal(true)
end)

apimap("x", "L", "<cmd>keepjumps norm! L<cr>", { noremap = true })

---@param cmd vim.api.keyset.cmd
local resize_win = function(cmd)
    local wintype = fn.win_gettype(api.nvim_get_current_win())
    if not (wintype == "" or wintype == "quickfix" or wintype == "loclist") then return end
    local old_spk = api.nvim_get_option_value("splitkeep", { scope = "global" })
    api.nvim_set_option_value("spk", "topline", { scope = "global" })
    api.nvim_cmd(cmd, {})
    api.nvim_set_option_value("spk", old_spk, { scope = "global" })
end

local resize_maps = {
    { "<M-h>", "-2", true },
    { "<M-j>", "-2", false },
    { "<M-k>", "+2", false },
    { "<M-l>", "+2", true },
}

for _, m in ipairs(resize_maps) do
    map("n", m[1], function()
        ---@diagnostic disable-next-line: missing-fields
        resize_win({ cmd = "resize", args = { m[2] }, mods = { silent = true, vertical = m[3] } })
    end)
end

map("n", "'", "`")
-- <cr> is used for Jump2D

map("n", "Z", "<nop>") -- Create normal Z layer
map({ "n", "x" }, "x", '"_x', { silent = true })
map("n", "X", '"_X', { silent = true })
-- NOTE: could not get set lmap "\3\27" to work
map("n", "<C-c>", function()
    print("")
    vim.api.nvim_cmd({ cmd = "noh" }, {})
    vim.lsp.buf.clear_references()

    -- Allows <C-c> to exit commands with a count. Also eliminates command line nag
    return "<esc>"
end, { expr = true, silent = true })

map("n", "v", "mvv")
map("n", "V", "mvV")
map("n", "<C-v>", "mv<C-v>")

-- Not silent so that the search prompting displays properly
apimap("n", "N", "Nzzzv", { noremap = true })
apimap("n", "n", "nzzzv", { noremap = true })
apimap("n", "/", "ms/", { noremap = true })
apimap("n", "?", "ms?", { noremap = true })
apimap("x", "M", "<cmd>keepjumps norm! M<cr>", { noremap = true })

-----------------------------
-- NORMAL UNIMPAIRED LAYER --
-----------------------------

-- LOW: Why does [s]s navigation work in some buffers but not others?
map("n", "[w", "[s")
map("n", "]w", "]s")

map("n", "[;", "g;")
map("n", "];", "g,")
map("n", "['", "[`")
map("n", "]'", "]`")

--------------------
-- NORMAL \ LAYER --
--------------------

-- MAYBE: Use \t to toggle the tabline, which would also de-activate/activate the harpoon state

map("n", "\\d", function()
    di.toggle_diags()
end)

map("n", "\\D", function()
    di.toggle_virt_lines()
end)

-- LOW: Could do <M-d> as errors or top only

map("n", "\\s", function()
    vim.api.nvim_set_option_value(
        "spell",
        not vim.api.nvim_get_option_value("spell", { scope = "local" }),
        { scope = "local" }
    )
end)

map("n", "\\<C-s>", "<cmd>set spell?<cr>")

map("n", "\\w", function()
    -- LOW: How does this interact with local scope?
    vim.api.nvim_set_option_value(
        "wrap",
        not vim.api.nvim_get_option_value("wrap", { scope = "local" }),
        { scope = "local" }
    )
end)

map("n", "\\<C-w>", "<cmd>set wrap?<cr>")

--------------------
-- NORMAL g LAYER --
--------------------

apimap("n", "g`", "<nop>", { noremap = true })
-- g~ mapped along with gu
-- LOW: Make a map of this in visual mode that uses the same syntax but without %
-- Credit ThePrimeagen
map("n", "g%", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

map("n", "gr", "<nop>")

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

for _, m in pairs(cap_motions_norm) do
    map("n", m, function()
        local row, col = unpack(api.nvim_win_get_cursor(0))
        api.nvim_buf_set_mark(0, "z", row, col, {})
        return m .. "`z"
    end, { silent = true, expr = true })
end

local cap_motions_vis = {
    "~",
    "g~",
    "gu",
    "gU",
}

for _, m in pairs(cap_motions_vis) do
    map("x", m, function()
        local row, col = unpack(api.nvim_win_get_cursor(0))
        api.nvim_buf_set_mark(0, "z", row, col, {})
        return m .. "`z"
    end, { silent = true, expr = true })
end

apimap("n", "gI", "g^i", { noremap = true })

apimap("n", "g'", "g`", { noremap = true })

apimap("n", "gV", "`[v`]", { noremap = true })

apimap("n", "g?", "<nop>", { noremap = true })

--------------------
-- NORMAL z LAYER --
--------------------

map("n", "zT", function()
    vim.opt_local.scrolloff = 0
    vim.cmd("norm! zt")
    vim.opt_local.scrolloff = Scrolloff
end)

map("n", "zg", "<cmd>silent norm! zg<cr>", { silent = true })

map("n", "zB", function()
    vim.opt_local.scrolloff = 0
    vim.cmd("norm! zb")
    vim.opt_local.scrolloff = Scrolloff
end)

--------------------
-- NORMAL Z LAYER --
--------------------

-- LOW: More testing on lockmarks/conform behavior

map("n", "ZQ", "<cmd>qall!<cr>")
map("n", "ZR", "<cmd>lockmarks silent wa | restart<cr>")

map("n", "ZA", "<cmd>lockmarks silent wa<cr>")
map("n", "ZS", "<cmd>lockmarks silent up | so<cr>")

map("n", "ZZ", "<cmd>lockmarks silent up<cr>")
map("n", "ZC", "<cmd>lockmarks wqa<cr>")

------------
-- CTRL-W --
------------

for _, m in pairs({ "<C-w>q", "<C-w><C-q>" }) do
    map("n", m, function()
        -- TODO: Use wipeout when that logic is fixed
        -- https://github.com/neovim/neovim/pull/33402
        -- TODO: Suppress errors when buf is invalid. Needed for TS Tree buffers
        ut.pclose_and_rm(api.nvim_get_current_win(), false, false)
    end)
end

map("n", "<C-w>c", "<nop>")
map("n", "<C-w><C-c>", "<nop>")

-----------------
-- VISUAL MODE --
-----------------

apimap("x", "%", "<cmd>keepjumps norm! %<cr>", { noremap = true })
-- { and } remapped in normal mode section
-- Has to be literally opening the cmdline or else the visual selection goes haywire
local eval_cmd = ":s/\\%V.*\\%V./\\=eval(submatch(0))/<CR>"
map("x", "<C-=>", eval_cmd, { noremap = true, silent = true })

--- LOW: These can be re-written as functions. For omode, get the current line. For vmode,
--- can use getregionpos to get the boundaries and extend by count appropriately
map("x", "i_", function()
    local keys = "g_o^o" .. vim.v.count .. "g_"
    api.nvim_feedkeys(keys, "ni", false)
end, { silent = true })

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
    vim.api.nvim_set_option_value("lz", true, { scope = "global" })
    vim.api.nvim_cmd({ cmd = "norm", args = { "\27" }, bang = true }, {})
    api.nvim_buf_set_lines(0, row - 1, row - 1, false, new_lines)
    vim.api.nvim_cmd({ cmd = "norm", args = { "gv" }, bang = true }, {})
    vim.api.nvim_set_option_value("lz", false, { scope = "global" })
end

map("x", "[<space>", function()
    add_blank_visual(true)
end)

map("x", "]<space>", add_blank_visual)

apimap("x", "a_", "<cmd>norm! ggoVG<cr>", { noremap = true, silent = true })
apimap("x", "<M-s>", ":s/\\%V", { noremap = true })
-- go mapped in normal mode section

apimap("x", "H", "<cmd>keepjumps norm! H<cr>", { noremap = true })
-- j/k are mapped in normal mode section

---@param opts? {upward:boolean}
---@return nil
local visual_move = function(opts)
    if not require("mjm.utils").check_modifiable() then return end

    local cur_mode = api.nvim_get_mode().mode ---@type string
    if cur_mode ~= "V" and cur_mode ~= "Vs" then
        api.nvim_echo({ { "Not in visual line mode", "" } }, false, {})
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
    vim.api.nvim_set_option_value("lz", false, { scope = "global" })
end

map("x", "<C-j>", visual_move)
map("x", "<C-k>", function()
    visual_move({ upward = true })
end)

apimap("x", "L", "<cmd>keepjumps norm! L<cr>", { noremap = true })

-- x mapped in normal mode section
map("x", "X", 'ygvV"_d<cmd>put!<cr>=`]', { silent = true })
apimap("x", "<C-c>", "<esc>", { noremap = true })

apimap("x", "M", "<cmd>keepjumps norm! M<cr>", { noremap = true })

-- TODO: Do these as a spec-ops mapping, same in normal mode due to the nag there
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

map("x", "<", function()
    visual_indent({ back = true })
end, { silent = true })

map("x", ">", function()
    visual_indent()
end, { silent = true })

---------------------------
-- OPERATOR PENDING MODE --
---------------------------

map("o", "i_", function()
    vim.cmd("norm! _v" .. vim.v.count1 .. "g_")
end, { silent = true })

apimap("o", "a_", "<cmd>norm! ggVG<cr>", { noremap = true, silent = true })
map("o", "go", function()
    return vim.v.count < 1 and "gg" or "go"
end, { expr = true })

apimap("o", "<C-c>", "<esc>", { noremap = true })

-----------------
-- INSERT MODE --
-----------------

map("i", "<C-q>", "<C-S-v>")
map("i", "<C-e>", "<End>")
map("i", "<M-e>", "<C-o>ze")

map("i", "<C-a>", "<C-o>I")
map("i", "<C-d>", "<Del>")
map("i", "<M-d>", "<C-g>u<C-o>dw")
map("i", "<C-f>", "<right>")
map("i", "<M-f>", "<S-right>")

map("i", "<M-j>", "<down>")
map("i", "<C-k>", "<C-g>u<C-o>D")
map("i", "<M-k>", "<up>")
map("i", "<C-l>", "<esc><cmd>silent norm! u<cr>")

-- Deal with default behavior where you type just to the bound of a window, so Nvim scrolls to
-- the next column so you can see what you're typing, but then you exit insert mode, meaning
-- the character no longer can exist, but Neovim still has you scrolled to the side
-- NOTE: This also applies to replace mode, but not single replace char
map("i", "<C-c>", "<esc>ze")
map("i", "<C-b>", "<left>")
map("i", "<M-b>", "<S-left>")

map("i", "<C-m>", "<C-d>")

------------------
-- COMMAND MODE --
------------------

-- NOTE: Setting <C-c> in cmd mode causes <C-c> to accept commands rather than cancel them
-- LOW: How to do delete word in cmd mode

map("c", "<M-p>", "<up>")

map("c", "<C-a>", "<C-b>")
map("c", "<C-d>", "<Del>")
map("c", "<C-f>", "<right>")
map("c", "<M-f>", "<S-right>")

map("c", "<C-k>", "<c-\\>estrpart(getcmdline(), 0, getcmdpos()-1)<cr>")

map("c", "<C-b>", "<left>")

map("c", "<M-b>", "<S-left>")

map("c", "<M-n>", "<down>")

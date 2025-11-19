local api = vim.api
local di = Mjm_Defer_Require("mjm.diagnostics") ---@type MjmDiags
local fn = vim.fn
local set = vim.keymap.set
local ut = Mjm_Defer_Require("mjm.utils") ---@type MjmUtils

----------
-- TABS --
----------

set("n", "<tab>", "gt")
set("n", "<S-tab>", "gT")
set("n", "ZT", function()
    local args = vim.v.count > 0 and { tostring(vim.v.count) } or nil ---@type string[]|nil
    api.nvim_cmd({ cmd = "tabclose", args = args }, {})
end)

set("n", "ZB", function()
    local args = vim.v.count > 0 and { tostring(vim.v.count) } or nil ---@type string[]|nil
    api.nvim_cmd({ cmd = "tabonly", args = args }, {})
end)

set("n", "g<tab>", function()
    ---@type integer
    local range = vim.v.count == 0 and api.nvim_call_function("tabpagenr", { "$" }) or vim.v.count
    api.nvim_cmd({ cmd = "tabnew", range = { range } }, {})

    local buf = api.nvim_get_current_buf() ---@type integer
    if not ut.is_empty_noname_buf(buf) then return end
    api.nvim_create_autocmd("BufHidden", {
        buffer = buf,
        callback = function()
            if not ut.is_empty_noname_buf(buf) then return end
            vim.schedule(function()
                api.nvim_buf_delete(buf, { force = true })
            end)
        end,
    })
end)

-----------------
-- NORMAL MODE --
-----------------

set("n", "`", "<nop>")
-- ~ remapped in the g layer section
set("x", "%", "<cmd>keepjumps norm! %<cr>")

-- () used for swaps in multicursor and ts text objects
-- - and + are used for oil
-- I use this as a prefix for inserting boilerplate code. Don't want this falling back to other
-- behavior on timeout
set("n", "<leader>-", "<nop>")

set("n", "<C-r>", function()
    return "<cmd>silent norm! " .. vim.v.count1 .. "\18<cr>"
end, { expr = true })

-- NOTE: At least for now, keep the default gR mapping
set("n", "<M-r>", "gr")

set("n", "u", function()
    return "<cmd>silent norm! " .. vim.v.count1 .. "u<cr>"
end, { expr = true })

set("n", "U", "<nop>")
-- Address cursorline flickering
-- Purposefully does not implement the default count mechanic in <C-u>/<C-d>, as it is painful
-- to accidently hit
---@param cmd string
local function map_scroll(m, cmd)
    set({ "n", "x" }, m, function()
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
    set("n", m, function()
        if string.match(api.nvim_get_current_line(), "^%s*$") then return '"_S' end
        return m
    end, { expr = true })
end

-- LOW: Not sure what to map to M-i
set({ "n", "x" }, "go", function()
    -- gg Retains cursor position since I have startofline off
    return vim.v.count < 1 and "m'gg" or "m'" .. vim.v.count1 .. "go"
end, { expr = true })

set({ "n", "x" }, "{", function()
    local args = vim.v.count1 .. "{"
    local cmd = { cmd = "normal", args = { args }, bang = true, mods = { keepjumps = true } }
    api.nvim_cmd(cmd, {})
end)

set({ "n", "x" }, "}", function()
    local args = vim.v.count1 .. "}"
    local cmd = { cmd = "normal", args = { args }, bang = true, mods = { keepjumps = true } }
    api.nvim_cmd(cmd, {})
end)

map_scroll("<C-d>", "\4zz")
-- Create normal <bs> layer
set("n", "<bs>", "<nop>")

-- a/A remapped with i
-- s used for substitution maps
set("n", "<M-s>", ":'<,'>s/\\%V")

-- FUTURE: These should remove trailing whitespace from the original line. The == should handle
-- invalid leading whitespace on the new line
set("n", "dJ", "Do<esc>p==", { silent = true })
set("n", "dK", function()
    vim.api.nvim_set_option_value("lz", true, { scope = "global" })
    api.nvim_feedkeys("DO\27p==", "nix", false)
    vim.api.nvim_set_option_value("lz", false, { scope = "global" })
end)

set("n", "dm", "<cmd>delmarks!<cr>")
set("o", "gg", "<esc>")

local function map_vert(dir)
    set({ "n", "x" }, dir, function()
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
    set({ "n", "x" }, "<C-S-" .. k .. ">", function()
        win_move_tmux(k)
    end)
end

set("x", "H", "<cmd>keepjumps norm! H<cr>")
-- LOW: Find a viable keymap for this and make it more robust to edge cases:
-- map("n", "H", 'mzk_D"_ddA <esc>p`zze', { silent = true })
set("n", "J", function()
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

set("n", "<C-j>", mv_normal)
set("n", "<C-k>", function()
    mv_normal(true)
end)

set("x", "L", "<cmd>keepjumps norm! L<cr>")

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
    set("n", m[1], function()
        ---@diagnostic disable-next-line: missing-fields
        resize_win({ cmd = "resize", args = { m[2] }, mods = { silent = true, vertical = m[3] } })
    end)
end

set("n", "'", "`")
-- <cr> is used for Jump2D

set("n", "Z", "<nop>") -- Create normal Z layer
set({ "n", "x" }, "x", '"_x', { silent = true })
set("n", "X", '"_X', { silent = true })
-- NOTE: could not get set lmap "\3\27" to work
set("n", "<C-c>", function()
    print("")
    vim.api.nvim_cmd({ cmd = "noh" }, {})
    vim.lsp.buf.clear_references()

    -- Allows <C-c> to exit commands with a count. Also eliminates command line nag
    return "<esc>"
end, { expr = true, silent = true })

set("n", "v", "mvv")
set("n", "V", "mvV")
set("n", "<C-v>", "mv<C-v>")

-- Not silent so that the search prompting displays properly
set("n", "N", "Nzzzv")
set("n", "n", "nzzzv")
set("n", "/", "ms/")
set("n", "?", "ms?")
set("x", "M", "<cmd>keepjumps norm! M<cr>")

-----------------------------
-- NORMAL UNIMPAIRED LAYER --
-----------------------------

-- LOW: Why does [s]s navigation work in some buffers but not others?
set("n", "[w", "[s")
set("n", "]w", "]s")

set("n", "[;", "g;")
set("n", "];", "g,")
set("n", "['", "[`")
set("n", "]'", "]`")

-----------------------
-- NORMAL <BS> LAYER --
-----------------------

-- MAYBE: Use t to toggle the tabline, which would also de-activate/activate the harpoon state

set("n", "<bs>d", function()
    di.toggle_diags()
end)

set("n", "<bs>D", function()
    di.toggle_virt_lines()
end)

set("n", "<bs><M-d>", function()
    local enabled = tostring(vim.diagnostic.is_enabled())
    local cfg = vim.inspect(vim.diagnostic.config())
    print("Enabled: " .. enabled .. "\n\n" .. cfg)
end)

set("n", "<bs>s", function()
    local cur_spell = api.nvim_get_option_value("spell", { scope = "local" }) ---@type boolean
    vim.api.nvim_set_option_value("spell", not cur_spell, { scope = "local" })
end)

set("n", "<bs><M-s>", "<cmd>set spell?<cr>")

set("n", "<bs>w", function()
    local cur_wrap = api.nvim_get_option_value("wrap", { scope = "local" }) ---@type boolean
    vim.api.nvim_set_option_value("wrap", not cur_wrap, { scope = "local" })
end)

set("n", "<bs><M-w>", "<cmd>set wrap?<cr>")

--------------------
-- NORMAL g LAYER --
--------------------

set("n", "g`", "<nop>")
-- g~ mapped along with gu
-- LOW: Make a map of this in visual mode that uses the same syntax but without %
-- Credit ThePrimeagen
set("n", "g%", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

set("n", "gr", "<nop>")

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
    set("n", m, function()
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
    set("x", m, function()
        local row, col = unpack(api.nvim_win_get_cursor(0))
        api.nvim_buf_set_mark(0, "z", row, col, {})
        return m .. "`z"
    end, { silent = true, expr = true })
end

-- gi used for multicursor
set("n", "gI", "g^i")

set("n", "g'", "g`")

set("n", "gV", "`[v`]")

set("n", "g?", "<nop>")

--------------------
-- NORMAL z LAYER --
--------------------

set("n", "zT", function()
    api.nvim_set_option_value("scrolloff", 0, { scope = "local" })
    api.nvim_cmd({ cmd = "norm", args = { "zt" }, bang = true }, {})
    api.nvim_set_option_value("scrolloff", Mjm_Scrolloff, { scope = "local" })
end)

set("n", "zB", function()
    api.nvim_set_option_value("scrolloff", 0, { scope = "local" })
    api.nvim_cmd({ cmd = "norm", args = { "zb" }, bang = true }, {})
    api.nvim_set_option_value("scrolloff", Mjm_Scrolloff, { scope = "local" })
end)

set("n", "zg", "<cmd>silent norm! zg<cr>", { silent = true })

--------------------
-- NORMAL Z LAYER --
--------------------

-- LOW: More testing on lockmarks/conform behavior

set("n", "ZQ", "<cmd>qall!<cr>")
set("n", "ZR", "<cmd>lockmarks silent wa | restart<cr>")

set("n", "ZA", "<cmd>lockmarks silent wa<cr>")
set("n", "ZS", "<cmd>lockmarks silent up | so<cr>")

set("n", "ZZ", "<cmd>lockmarks silent up<cr>")
set("n", "ZC", "<cmd>lockmarks wqa<cr>")

------------
-- CTRL-W --
------------

for _, m in pairs({ "<C-w>q", "<C-w><C-q>" }) do
    set("n", m, function()
        -- TODO: Use wipeout when that logic is fixed
        -- https://github.com/neovim/neovim/pull/33402
        -- TODO: Suppress errors when buf is invalid. Needed for TS Tree buffers
        ut.pclose_and_rm(api.nvim_get_current_win(), false, false)
    end)
end

set("n", "<C-w>c", "<nop>")
set("n", "<C-w><C-c>", "<nop>")

-----------------
-- VISUAL MODE --
-----------------

set("x", "%", "<cmd>keepjumps norm! %<cr>")
-- { and } remapped in normal mode section
-- Has to be literally opening the cmdline or else the visual selection goes haywire
local eval_cmd = ":s/\\%V.*\\%V./\\=eval(submatch(0))/<CR>"
set("x", "<C-=>", eval_cmd, { noremap = true, silent = true })

--- LOW: These can be re-written as functions. For omode, get the current line. For vmode,
--- can use getregionpos to get the boundaries and extend by count appropriately
set("x", "i_", function()
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

set("x", "[<space>", function()
    add_blank_visual(true)
end)

set("x", "]<space>", add_blank_visual)

set("x", "a_", "<cmd>norm! ggoVG<cr>")
set("x", "<M-s>", ":s/\\%V")
-- go mapped in normal mode section

set("x", "H", "<cmd>keepjumps norm! H<cr>")
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

set("x", "<C-j>", visual_move)
set("x", "<C-k>", function()
    visual_move({ upward = true })
end)

set("x", "L", "<cmd>keepjumps norm! L<cr>")

-- x mapped in normal mode section
set("x", "X", 'ygvV"_d<cmd>put!<cr>=`]', { silent = true })
set("x", "<C-c>", "<esc>")

set("x", "M", "<cmd>keepjumps norm! M<cr>")

-- TODO: Do these as a spec-ops mapping, same in normal mode due to the nag there
-- Done as a function to suppress nag when shifting multiple lines
---@param opts? table
---@return nil
local visual_indent = function(opts)
    local old_lz = api.nvim_get_option_value("lz", {})
    local old_cc = api.nvim_get_option_value("cc", {})
    api.nvim_set_option_value("lz", true, {})
    api.nvim_set_option_value("cc", "", { scope = "local" })

    local shift = (opts or {}).back and "<" or ">" ---@type string
    vim.cmd("norm! \27")
    vim.cmd("silent '<,'> " .. string.rep(shift, vim.v.count1))
    vim.cmd("silent norm! gv")

    api.nvim_set_option_value("cc", old_cc, { scope = "local" })
    api.nvim_set_option_value("lz", old_lz, {})
end

set("x", "<", function()
    visual_indent({ back = true })
end, { silent = true })

set("x", ">", function()
    visual_indent()
end, { silent = true })

---------------------------
-- OPERATOR PENDING MODE --
---------------------------

set("o", "i_", function()
    vim.cmd("norm! _v" .. vim.v.count1 .. "g_")
end, { silent = true })

set("o", "a_", "<cmd>norm! ggVG<cr>")
set("o", "go", function()
    return vim.v.count < 1 and "gg" or "go"
end, { expr = true })

set("o", "<C-c>", "<esc>")

-----------------
-- INSERT MODE --
-----------------

-- Deal with default behavior where you type just to the bound of a window, so Nvim scrolls to
-- the next column so you can see what you're typing, but then you exit insert mode, meaning
-- the character no longer can exist, but Neovim still has you scrolled to the side
-- NOTE: This also applies to replace mode, but not single replace char
set("i", "<C-c>", "<esc>ze")

set("i", "<C-q>", "<C-S-v>") -- Seen unsimplified char literals. Avoid terminal paste

set("i", "<C-a>", "<C-o>I")
set("i", "<C-e>", "<End>")
set("i", "<C-f>", "<right>")
set("i", "<C-b>", "<left>")
set("i", "<M-f>", "<S-right>")
set("i", "<M-b>", "<S-left>")
set("i", "<M-j>", "<down>")
set("i", "<M-k>", "<up>")

set("i", "<M-e>", "<C-o>ze")

set("i", "<C-d>", "<Del>")
set("i", "<M-d>", "<C-g>u<C-o>dw")
set("i", "<C-k>", "<C-g>u<C-o>D")
set("i", "<C-l>", "<esc><cmd>silent norm! u<cr>")
_G.I_Dedent = "<C-m>"
set("i", I_Dedent, "<C-d>")

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

-- LOW: Visual mode mapping to trim whitespace from selection
-- LOW: ctrl-b/ctrl-f behavior is odd. Going up or down one "page" sometimes results in the same
-- line number when you go back
-- Obvious solution - get 'lines' option value, move by that and set a jump point
-- But would want to see if the page navigation has an underlying logic I'm not understanding
-- before going there. Could also add zz to the bespoke navigation
-- LOW: Re-organize these by topic

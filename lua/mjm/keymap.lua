local opts = { noremap = true, silent = true }

------------------------------
-- Better Window Management --
------------------------------

vim.keymap.set("n", "<leader>lv", "<cmd>vsplit<cr>", opts)
vim.keymap.set("n", "<leader>lh", "<cmd>split<cr>", opts)

-- Controlled through vim-tmux-navigator
-- vim.keymap.set("n", "<C-h>", "<C-w>h", opts)
-- vim.keymap.set("n", "<C-j>", "<C-w>j", opts)
-- vim.keymap.set("n", "<C-k>", "<C-w>k", opts)
-- vim.keymap.set("n", "<C-l>", "<C-w>l", opts)

vim.keymap.set("n", "<M-j>", "<cmd>resize -2<CR>", opts)
vim.keymap.set("n", "<M-k>", "<cmd>resize +2<CR>", opts)
vim.keymap.set("n", "<M-h>", "<cmd>vertical resize -2<CR>", opts)
vim.keymap.set("n", "<M-l>", "<cmd>vertical resize +2<CR>", opts)

-------------------------
-- Visual Improvements --
-------------------------

vim.keymap.set("n", "J", "mzJ`z", opts)

vim.keymap.set("n", "<C-d>", "<C-d>zz", opts)
vim.keymap.set("n", "<C-u>", "<C-u>zz", opts)

vim.keymap.set("n", "n", "nzzzv", opts)
vim.keymap.set("n", "N", "Nzzzv", opts)

---------------------
-- Yank Maps/Fixes --
---------------------

vim.keymap.set("v", "y", "mzy`z", opts)
vim.keymap.set("n", "Y", "y$", opts) -- Avoid inconsistent behavior

vim.keymap.set("n", "<leader>y", "\"+y", opts)
vim.keymap.set("v", "<leader>y", "mz\"+y`z", opts)
vim.keymap.set("n", "<leader>Y", "\"+y$", opts) -- Mapping to "+Y yanks the whole line
vim.keymap.set("v", "<leader>Y", "mz\"+Y`z", opts)

vim.keymap.set("n", "yiw", "mzyiw`z", opts)
vim.keymap.set("n", "yaw", "mzyaw`z", opts)
vim.keymap.set("n", "<leader>yiw", "mz\"+yiw`z", opts)
vim.keymap.set("n", "<leader>yaw", "mz\"+yaw`z", opts)
vim.keymap.set("n", "yiW", "mzyiW`z", opts)
vim.keymap.set("n", "yaW", "mzyaW`z", opts)
vim.keymap.set("n", "<leader>yiW", "mz\"+yiW`z", opts)
vim.keymap.set("n", "<leader>yaW", "mz\"+yaW`z", opts)

vim.keymap.set("n", "yi(", "mzyi(`z", opts)
vim.keymap.set("n", "ya(", "mzya(`z", opts)
vim.keymap.set("n", "<leader>yi(", "mz\"+yi(`z", opts)
vim.keymap.set("n", "<leader>ya(", "mz\"+ya(`z", opts)
vim.keymap.set("n", "yi[", "mzyi[`z", opts)
vim.keymap.set("n", "ya[", "mzya[`z", opts)
vim.keymap.set("n", "<leader>yi[", "mz\"+yi[`z", opts)
vim.keymap.set("n", "<leader>ya[", "mz\"+ya[`z", opts)
vim.keymap.set("n", "yi{", "mzyi{`z", opts)
vim.keymap.set("n", "ya{", "mzya{`z", opts)
vim.keymap.set("n", "<leader>yi{", "mz\"+yi{`z", opts)
vim.keymap.set("n", "<leader>ya{", "mz\"+ya{`z", opts)

vim.keymap.set("n", "yi\"", "mzyi\"`z", opts)
vim.keymap.set("n", "ya\"", "mzya\"`z", opts)
vim.keymap.set("n", "<leader>yi\"", "mz\"+yi\"`z", opts)
vim.keymap.set("n", "<leader>ya\"", "mz\"+ya\"`z", opts)
vim.keymap.set("n", "yi'", "mzyi'`z", opts)
vim.keymap.set("n", "ya'", "mzya'`z", opts)
vim.keymap.set("n", "<leader>yi'", "mz\"+yi'`z", opts)
vim.keymap.set("n", "<leader>ya'", "mz\"+ya'`z", opts)

vim.keymap.set("n", "yi<", "mzyi<`z", opts)
vim.keymap.set("n", "ya<", "mzya<`z", opts)
vim.keymap.set("n", "<leader>yi<", "mz\"+yi<`z", opts)
vim.keymap.set("n", "<leader>ya<", "mz\"+ya<`z", opts)
vim.keymap.set("n", "yit", "mzyit`z", opts)
vim.keymap.set("n", "yat", "mzyat`z", opts)
vim.keymap.set("n", "<leader>yit", "mz\"+yit`z", opts)
vim.keymap.set("n", "<leader>yat", "mz\"+yat`z", opts)

vim.keymap.set("n", "yip", "mzyip`z", opts)
vim.keymap.set("n", "yap", "mzyap`z", opts)
vim.keymap.set("n", "<leader>yip", "mz\"+yip`z", opts)
vim.keymap.set("n", "<leader>yap", "mz\"+yap`z", opts)

-----------------
-- Paste Fixes --
-----------------

vim.keymap.set("n", "<leader>p", "\"+p", opts)
vim.keymap.set("n", "<leader>P", "\"+P", opts)

local paste_linewise = function(paste_char, external)
    local cur_mode = vim.fn.mode()

    if cur_mode == "V" or cur_mode == "Vs" then -- Ensure that Visual Line Mode pastes are linewise
        if external then
            vim.cmd([[:execute "normal! \"_d" | put! +]])
        else
            vim.cmd([[:execute "normal! \"_d" | put! \"]])
        end

        vim.cmd([[:execute "normal! `[=`]`["]])
    else
        if external then
            vim.cmd("normal! \"_d\"+" .. paste_char)
        else
            vim.cmd("normal! \"_d" .. paste_char)
        end
    end
end

vim.keymap.set("v", "p", function()
    paste_linewise("P", false)
end, opts)

vim.keymap.set("v", "P", function()
    paste_linewise("p", false)
end, opts)

vim.keymap.set("v", "<leader>p", function()
    paste_linewise("P", true)
end, opts)

vim.keymap.set("v", "<leader>P", function()
    paste_linewise("p", true)
end, opts)

---------------------------------
-- Other Cursor Movement Fixes --
---------------------------------

vim.keymap.set("n", "~", "mz~`z", opts)

vim.keymap.set("n", "guu", "mzguu`z", opts)
vim.keymap.set("n", "guiw", "mzguiw`z", opts)
vim.keymap.set("n", "guiW", "mzguiW`z", opts)

vim.keymap.set("n", "gUU", "mzgUU`z", opts)
vim.keymap.set("n", "gUiw", "mzgUiw`z", opts)
vim.keymap.set("n", "gUiW", "mzgUiW`z", opts)

vim.keymap.set("v", "gu", "mzgu`z", opts)
vim.keymap.set("v", "gU", "mzgU`z", opts)

---------------------------------
-- Delete to the void register --
---------------------------------

vim.keymap.set({ "n", "v" }, "x", "\"_x", opts)
vim.keymap.set({ "n", "v" }, "X", "\"_X", opts)

vim.keymap.set({ "n", "v" }, "<leader>d", "\"_d", opts)
vim.keymap.set({ "n", "v" }, "<leader>c", "\"_c", opts)
vim.keymap.set({ "n", "v" }, "<leader>D", "\"_D", opts)
vim.keymap.set({ "n", "v" }, "<leader>C", "\"_C", opts)

-----------------------
-- Text Manipulation --
-----------------------

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", opts)
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", opts)

vim.keymap.set("v", "<", "<gv", opts)
vim.keymap.set("v", ">", ">gv", opts)

-- Take the text from the cursor to the end of the current line and move it to a new line above
vim.keymap.set("n", "<leader>=", "v$hd<cmd>s/\\s\\+$//e<cr>O<esc>0\"_Dp==", opts)

-- Same as J but with the line above. Keeps the cursor in the same place
-- Does not automatically reformat comment syntax
vim.keymap.set("n", "H",
    "mz<cmd>let @y = @\"<cr>k_\"zD\"_dd`zA<space><esc>\"zp<cmd>let@\" = @y<cr>`z", opts)

vim.keymap.set("n", "[ ", "mzO<esc>0\"_D`z", opts)
vim.keymap.set("n", "] ", "mzo<esc>0\"_D`z", opts)

vim.keymap.set("n", "<M-;>", function()
    vim.cmd([[s/\s\+$//e]])

    if vim.api.nvim_get_current_line():sub(-1) == ";" then
        vim.cmd([[silent! normal! mz$"_x`z]])
    else
        vim.cmd([[:execute "normal! mzA;" | normal! `z]])
    end
end, opts)

-- Title Case Maps
vim.keymap.set("n", "gllw", "mz<cmd> s/\\v<(.)(\\w*)/\\u\\1\\L\\2/ge<cr><cmd>noh<cr>`z", opts)
vim.keymap.set("n", "gllW", "mz<cmd> s/\\v<(.)(\\S*)/\\u\\1\\L\\2/ge<cr><cmd>noh<cr>`z", opts)
vim.keymap.set("n", "gliw", "mzguiw~`z", opts)
vim.keymap.set("n", "gliW", "mzguiW~`z", opts)

-- Create Undo Sequences on Punctuation
vim.keymap.set("i", ",", ",<C-g>u")
vim.keymap.set("i", ".", ".<C-g>u")
vim.keymap.set("i", "!", "!<C-g>u")
vim.keymap.set("i", "?", "?<C-g>u")

-------------------
-- Quickfix List --
-------------------

vim.keymap.set("n", "<leader>qt", function()
    local is_quickfix_open = false
    local win_info = vim.fn.getwininfo()

    for _, win in ipairs(win_info) do
        if win.quickfix == 1 then
            is_quickfix_open = true
            break
        end
    end

    if is_quickfix_open then
        vim.cmd "cclose"
    else
        vim.cmd "copen"
    end
end, opts)

vim.keymap.set("n", "<leader>qo", "<cmd>copen<cr>", opts)
vim.keymap.set("n", "<leader>qc", "<cmd>cclose<cr>", opts)

local grep_function = function(grep_cmd)
    local pattern = vim.fn.input('Enter pattern: ')

    if pattern ~= "" then
        vim.cmd("silent! " .. grep_cmd .. " " .. pattern .. " | copen")

        -- vim.cmd("wincmd p")
        -- vim.api.nvim_feedkeys(
        --     vim.api.nvim_replace_termcodes(
        --         '<C-O>', true, true, true
        --     ), 'n', {}
        -- )
    end
end

vim.keymap.set("n", "<leader>qgn", function()
    grep_function("grep")
end, opts)

vim.keymap.set("n", "<leader>qgi", function()
    grep_function("grep -i")
end, opts)

local convert_raw_diagnostic = function(raw_diagnostic)
    local diag_severity

    if raw_diagnostic.severity == vim.diagnostic.severity.ERROR then
        diag_severity = "E"
    elseif raw_diagnostic.severity == vim.diagnostic.severity.WARN then
        diag_severity = "W"
    elseif raw_diagnostic.severity == vim.diagnostic.severity.INFO then
        diag_severity = "I"
    elseif raw_diagnostic.severity == vim.diagnostic.severity.HINT then
        diag_severity = "H"
    else
        diag_severity = "U"
    end

    return {
        bufnr = raw_diagnostic.bufnr,
        filename = vim.fn.bufname(raw_diagnostic.bufnr),
        lnum = raw_diagnostic.lnum,
        end_lnum = raw_diagnostic.end_lnum,
        col = raw_diagnostic.col,
        end_col = raw_diagnostic.end_col,
        text = raw_diagnostic.source .. ": " .. "[" .. raw_diagnostic.code .. "] " ..
            raw_diagnostic.message,
        type = diag_severity,
    }
end

local diags_to_qf = function(min_warning)
    local raw_diagnostics = vim.diagnostic.get(nil)
    local diagnostics = {}

    if min_warning then
        for _, diagnostic in ipairs(raw_diagnostics) do
            if diagnostic.severity <= 2 then --ERROR or WARN
                table.insert(diagnostics, convert_raw_diagnostic(diagnostic))
            end
        end
    else
        for _, diagnostic in ipairs(raw_diagnostics) do
            table.insert(diagnostics, convert_raw_diagnostic(diagnostic))
        end
    end

    vim.fn.setqflist(diagnostics, "r")
    vim.cmd "copen"
end

vim.keymap.set("n", "<leader>qiq", function()
    diags_to_qf(false)
end, opts)

vim.keymap.set("n", "<leader>qii", function()
    diags_to_qf(true)
end, opts)

vim.keymap.set("n", "<leader>ql", function()
    local clients = vim.lsp.get_active_clients()
    local for_qf_list = {}

    for _, client in ipairs(clients) do
        local bufs_for_client = "( "

        for _, buf in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
            bufs_for_client = bufs_for_client .. buf .. " "
        end

        bufs_for_client = bufs_for_client .. ")"
        local lsp_entry = "LSP: " .. client.name .. ", ID: " .. client.id .. ", Buffer(s): " ..
            bufs_for_client

        table.insert(for_qf_list, { text = lsp_entry })
    end

    vim.fn.setqflist(for_qf_list, "r")
    vim.cmd("copen")
end, opts)

vim.keymap.set("n", "<leader>qk", function()
    local pattern = vim.fn.input('Pattern to keep: ')
    if pattern ~= "" then
        vim.cmd("Cfilter " .. pattern)
    end
end, opts)

vim.keymap.set("n", "<leader>qr", function()
    local pattern = vim.fn.input('Pattern to remove: ')
    if pattern ~= "" then
        vim.cmd("Cfilter! " .. pattern)
    end
end, opts)

vim.keymap.set("n", "<leader>qe", function()
    vim.fn.setqflist({})
    vim.cmd("cclose")
end, opts)

local qf_scroll = function(direction)
    local status, result = pcall(function()
        vim.cmd("c" .. direction)
    end)

    if not status then
        local backup_direction

        if direction == "prev" then
            backup_direction = "last"
        elseif direction == "next" then
            backup_direction = "first"
        else
            print("Invalid direction: " .. direction)
            return
        end

        if result and type(result) == "string" and string.find(result, "E553") then
            vim.cmd("c" .. backup_direction)
            vim.cmd("normal! zz")
        elseif result and type(result) == "string" and string.find(result, "E42") then
        elseif result then
            print(result)
        end
    else
        vim.cmd("normal! zz")
    end
end

vim.keymap.set("n", "[q", function()
    qf_scroll("prev")
end, opts)

vim.keymap.set("n", "]q", function()
    qf_scroll("next")
end, opts)

-----------
-- Other --
-----------

-- If <C-c> is rebound to <esc> explicitly in command mode,
-- in Wezterm it causes <C-c> to act like <cr>
vim.keymap.set({ "n", "i", "v" }, "<C-c>", "<esc>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<esc>", "<nop>", opts)

local jkOpts = { noremap = true, expr = true, silent = true }

vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", jkOpts)
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", jkOpts)

-- vim.keymap.set("i", "<C-l>", "<C-o>l", opts)

-- In Visual Mode, select the last changed text (includes writes)
vim.keymap.set("n", "gp", "`[v`]", opts)

vim.keymap.set("n", "<leader>/", "<cmd>noh<cr>", opts)

vim.keymap.set("n", "<leader>st", function()
    if vim.opt.spell:get() then
        vim.opt.spell = false
        vim.opt.spelllang = ""
    else
        vim.opt.spell = true
        vim.opt.spelllang = "en_us"
    end
end)

vim.keymap.set("n", "<leader>sn", function()
    vim.opt.spell = true
    vim.opt.spelllang = "en_us"
end)

vim.keymap.set("n", "<leader>sf", function()
    vim.opt.spell = false
    vim.opt.spelllang = ""
end)

----------------------------------
-- Disable Various Default Maps --
----------------------------------

vim.keymap.set("n", "Q", "<nop>", opts)
vim.keymap.set("n", "gh", "<nop>", opts)
vim.keymap.set("n", "gH", "<nop>", opts)

vim.keymap.set("n", "{", "<Nop>", opts)
vim.keymap.set("n", "}", "<Nop>", opts)
vim.keymap.set("n", "[m", "<Nop>", opts)
vim.keymap.set("n", "]m", "<Nop>", opts)
vim.keymap.set("n", "[M", "<Nop>", opts)
vim.keymap.set("n", "]M", "<Nop>", opts)

vim.keymap.set("n", "dib", "<Nop>", opts)
vim.keymap.set("n", "diB", "<Nop>", opts)
vim.keymap.set("n", "dab", "<Nop>", opts)
vim.keymap.set("n", "daB", "<Nop>", opts)
vim.keymap.set("n", "cib", "<Nop>", opts)
vim.keymap.set("n", "ciB", "<Nop>", opts)
vim.keymap.set("n", "cab", "<Nop>", opts)
vim.keymap.set("n", "caB", "<Nop>", opts)
vim.keymap.set("n", "yib", "<Nop>", opts)
vim.keymap.set("n", "yiB", "<Nop>", opts)
vim.keymap.set("n", "yab", "<Nop>", opts)
vim.keymap.set("n", "yaB", "<Nop>", opts)

-- vim.keymap.set("n", "H", "<Nop>", opts) -- For reference only. Used for a custom mapping
vim.keymap.set("n", "M", "<Nop>", opts)
vim.keymap.set("n", "L", "<Nop>", opts)

vim.keymap.set({ "n", "v" }, "s", "<Nop>", opts)
vim.keymap.set("n", "S", "<Nop>", opts) -- Used in visual mode by vim-surround

vim.keymap.set("n", "ZZ", "<Nop>", opts)
vim.keymap.set("n", "ZQ", "<Nop>", opts)

--Disable Non-Home Row Based Keys
vim.keymap.set({ "n", "i", "v", "c" }, "<up>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<down>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<left>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<right>", "<Nop>", opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<PageUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<PageDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<Home>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<End>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<Insert>", "<Nop>", opts)

-------------------
-- Disable Mouse --
-------------------

vim.opt.mouse = "a"           -- Otherwise, the terminal handles mouse functionality
vim.opt.mousemodel = "extend" -- Disables terminal right-click paste

vim.keymap.set({ "n", "i", "v", "c" }, "<LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<2-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<3-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<4-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-2-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-3-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-4-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-2-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-3-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-4-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-2-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-3-LeftMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-4-LeftMouse>", "<Nop>", opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<2-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<3-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<4-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<A-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<S-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-2-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-3-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-4-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-A-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-S-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-2-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-3-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-4-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-A-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-S-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-C-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-2-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-3-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-4-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-A-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-S-RightMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-C-RightMouse>", "<Nop>", opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<LeftDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<RightDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<LeftRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<RightRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-LeftDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-RightDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-LeftRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-RightRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-LeftDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-RightDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-LeftRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-RightRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-LeftDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-RightDrag>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-LeftRelease>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-RightRelease>", "<Nop>", opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<2-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<3-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<4-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-2-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-3-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-4-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-2-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-3-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-4-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-2-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-3-MiddleMouse>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-4-MiddleMouse>", "<Nop>", opts)

vim.keymap.set({ "n", "i", "v", "c" }, "<ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<S-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<S-ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-S-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-S-ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-S-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<M-S-ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-S-ScrollWheelUp>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-ScrollWheelDown>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "c" }, "<C-M-S-ScrollWheelDown>", "<Nop>", opts)

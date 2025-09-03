-- MAYBE: Make a convenience mapping for comment headings

-------------
-- Disable --
-------------

-- Cumbersome default functionality. Use for swaps as in Helix
Map("n", "(", "<nop>")
Map("n", ")", "<nop>")

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

-- Using lockmarks for saves has to suffice

-- Don't map ZQ. Running ZZ in vanilla Vim is a gaffe. ZQ not so much
Map("n", "ZQ", "<nop>")
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

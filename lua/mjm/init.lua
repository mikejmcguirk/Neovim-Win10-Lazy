-- TODO: Can copy the logic I need out of here: https://github.com/Shatur/neovim-session-manager

local start = vim.loop.hrtime()

-----------
-- Setup --
-----------

vim.g.loaded_2html_plugin = 1
vim.g.loaded_gzip = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1 -- MAYBE: Lazy load
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1
vim.g.loaded_remote_plugins = 1
vim.g.loaded_spellfile_plugin = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_tar = 1
vim.g.loaded_tutor_mode_plugin = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_zip = 1

vim.keymap.set({ "n", "x" }, "<Space>", "<Nop>")
vim.g.mapleader = " "
vim.g.maplocaleader = " "

require("mjm.global_vars")
require("mjm.set")
require("mjm.keymap")
require("mjm.custom_cmd")

require("mjm.colorscheme")

require("mjm.stl")

local env_setup = vim.loop.hrtime()

-------------------------------
-- Download/Register Plugins --
-------------------------------

require("mjm.pack")
vim.cmd.packadd({ vim.fn.escape("cfilter", " "), bang = true, magic = { file = false } })

local pack_finish = vim.loop.hrtime()

----------------------------
-- Plugin Dependent Setup --
----------------------------

require("mjm.tal") -- Requires Harpoon

local post_plugin_setup = vim.loop.hrtime()

--------------------------
-- Eager Initialization --
--------------------------

require("mjm.plugins.nvim-treesitter") -- Text Objects Sets Up Lazily

require("mjm.plugins.fzflua")
require("mjm.plugins.harpoon")
require("mjm.plugins.oil")

require("mjm.plugins.fugitive")

local eager_loaded = vim.loop.hrtime()

-------------------------
-- Lazy Initialization --
-------------------------

vim.g.db_ui_use_nerd_fonts = 1
vim.g.qs_highlight_on_keys = { "f", "F", "t", "T" }
vim.g.qs_max_chars = 9999
vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)

require("mjm.plugins.autopairs")
require("mjm.plugins.blink")
require("mjm.plugins.conform")
require("mjm.plugins.git_signs")
require("mjm.plugins.jump2d")
require("mjm.plugins.lazydev")
require("mjm.plugins.mini-operators")
require("mjm.plugins.nvim-surround")
require("mjm.plugins.obsidian")
require("mjm.plugins.spec-ops")
require("mjm.plugins.treesj")
require("mjm.plugins.ts-autotag")
require("mjm.plugins.zen")

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("mjm-lazy-load", { clear = true }),
    once = true,
    callback = function()
        require("mjm.lazy_keymaps")
        require("mjm.error-list")
        require("mjm.treesitter")

        require("mjm.diagnostic")
        require("mjm.lsp")
        require("mjm.color_coordination")

        vim.api.nvim_del_augroup_by_name("nvim.diagnostic.status")
        vim.api.nvim_del_augroup_by_name("mjm-lazy-load")
    end,
})

local lazy_loaded = vim.loop.hrtime()

local to_env_setup = math.floor((env_setup - start) / 1e6 * 100) / 100
local to_pack_finished = math.floor((pack_finish - start) / 1e6 * 100) / 100
local to_post_plugin_setup = math.floor((post_plugin_setup - start) / 1e6 * 100) / 100
local to_eager_loaded = math.floor((eager_loaded - start) / 1e6 * 100) / 100
local to_lazy_loaded = math.floor((lazy_loaded - start) / 1e6 * 100) / 100

vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("display-profile-info", { clear = true }),
    callback = function()
        local ui_enter = vim.loop.hrtime()
        local to_ui_enter = math.floor((ui_enter - start) / 1e6 * 100) / 100

        if vim.fn.argc() > 0 or vim.fn.line2byte("$") ~= -1 or vim.bo.modified then
            return
        end

        local headers = {
            { "Setup: ", to_env_setup },
            { "Download/Register Plugins: ", to_pack_finished },
            { "Post Plugin Setup: ", to_post_plugin_setup },
            { "Eager Plugin Init: ", to_eager_loaded },
            { "Lazy Plugin Init: ", to_lazy_loaded },
            { "UI Enter: ", to_ui_enter },
        }

        local max_header_len = 0
        for _, header in pairs(headers) do
            if #header[1] > max_header_len then
                max_header_len = #header[1]
            end
        end

        for i, header in pairs(headers) do
            headers[i][1] = header[1] .. string.rep(" ", max_header_len - #header[1] + 2)
        end

        local lines = {
            "",
            "=================",
            "==== STARTUP ====",
            "=================",
            "",
        }

        for _, header in pairs(headers) do
            table.insert(lines, header[1] .. header[2] .. "ms")
        end

        for i, line in ipairs(lines) do
            local padding = math.floor((vim.fn.winwidth(0) - #lines[i]) / 2)
            lines[i] = string.rep(" ", padding) .. line
        end

        local win = vim.api.nvim_get_current_win()
        local bufnr = vim.api.nvim_win_get_buf(win)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        local buf_opts = {
            { "buftype", "nofile" },
            { "bufhidden", "wipe" },
            { "swapfile", false },
            { "readonly", true },
            { "modifiable", false },
            { "modified", false },
            { "buflisted", false },
        }

        for _, option in pairs(buf_opts) do
            vim.api.nvim_set_option_value(option[1], option[2], { buf = bufnr })
        end

        vim.api.nvim_create_autocmd("BufLeave", {
            group = vim.api.nvim_create_augroup("leave-greeter", { clear = true }),
            buffer = bufnr,
            once = true,
            callback = function()
                -- Treesitter fails in the next buffer if not scheduled wrapped
                vim.schedule_wrap(function()
                    vim.api.nvim_buf_delete(bufnr, { force = true })
                end)
            end,
        })
    end,
})

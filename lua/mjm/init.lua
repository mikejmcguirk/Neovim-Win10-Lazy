local start = vim.uv.hrtime()

--- TODO: For loading efficiency:
--- - Setting up lazy loaded files here is the wrong choice. The purpose of this file is to setup
--- everything that is available once the load step is complete. Deferring here adds gotchas
--- - Every require adds startup time. Good to remove requires, or hide requires behind autocmds
--- - To look at keymaps for example, some stuff in there indeed does not to be set until
--- BufReadPre, but that decision needs to be made in the keymaps file, not here

-----------
-- Setup --
-----------

--- :h standard-plugin-list
--- Disabling these has a non-trivial effect on startup time

--- LOW: No need to change now, but the 2html plugin appears to have been re-written in Lua, and
--- on load only creates an autocmd. Might be useful
vim.api.nvim_set_var("loaded_2html_plugin", 1)
vim.api.nvim_set_var("did_install_default_menus", 1)
vim.api.nvim_set_var("loaded_gzip", 1)
vim.api.nvim_set_var("loaded_man", 1)
vim.api.nvim_set_var("loaded_matchit", 1)
vim.api.nvim_set_var("loaded_matchparen", 1)
vim.api.nvim_set_var("loaded_netrw", 1)
vim.api.nvim_set_var("loaded_netrwPlugin", 1)
vim.api.nvim_set_var("loaded_netrwSettings", 1)
vim.api.nvim_set_var("loaded_remote_plugins", 1)
vim.api.nvim_set_var("loaded_shada_plugin", 1)
vim.api.nvim_set_var("loaded_spellfile_plugin", 1)
vim.api.nvim_set_var("loaded_tar", 1)
vim.api.nvim_set_var("loaded_tarPlugin", 1)
vim.api.nvim_set_var("loaded_tutor_mode_plugin", 1)
vim.api.nvim_set_var("loaded_zip", 1)
vim.api.nvim_set_var("loaded_zipPlugin", 1)

-- I have xsel on my system
local termfeatures = vim.g.termfeatures or {}
termfeatures.osc52 = false
vim.api.nvim_set_var("termfeatures", termfeatures)

_G.Border = "single" ---@type string
_G.Has_Nerd_Font = true --- @type boolean
_G.Highlight_Time = 175 --- @type integer
_G.Scrolloff_Val = 6 ---@type integer
_G.SpellFile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add" ---@type string

_G.ApiMap = vim.api.nvim_set_keymap
_G.Cmd = vim.api.nvim_cmd
_G.Map = vim.keymap.set

Map({ "n", "x" }, "<Space>", "<Nop>")
vim.g.mapleader = " "
vim.g.maplocaleader = " "

-- TODO: I'm fine with keymap being its own file since that handles a specific concern, but then
-- I think as many files as possible should be rolled into set. The concerns are conceptually, but
-- not all that technically seperable. Will probably make easier to manage startup sequencing
-- Plus we want to get away from the "plugin" mentality as much as possible. a colorscheme is just
-- a list of settings, for example. It's not a "plugin" in the spiritual sense
require("mjm.set")
require("mjm.keymap")
require("mjm.custom_cmd")

require("mjm.colorscheme")

require("mjm.stl")
require("mjm.diagnostic")
-- Not being used, so no need for this to run in the background
-- Needs to be done here after diagnostics have actually been enabled
vim.api.nvim_del_augroup_by_name("nvim.diagnostic.status")

require("mjm.error-list") -- Do this first because it sets up g vars
require("mjm.error-list-open")
require("mjm.error-list-stack")
require("mjm.error-list-filter")
require("mjm.error-list-nav-action")
require("mjm.error-list-sort")
require("mjm.error-list-system")
require("mjm.error-list-grep")
require("mjm.error-list-diag")

local env_setup = vim.uv.hrtime()

-------------------------------
-- Download/Register Plugins --
-------------------------------

-- TODO: This should be as early in the setup as possible since all this does is bring
-- everything into the RTP
require("mjm.pack")

local pack_finish = vim.uv.hrtime()

---------------------------------
-- Eager Plugin Initialization --
---------------------------------

require("mjm.plugins.nvim-treesitter") -- Text Objects Sets Up Lazily

require("mjm.plugins.fzflua")

require("mjm.plugins.harpoon")
require("mjm.plugins.oil")

require("mjm.plugins.fugitive")
require("mjm.plugins.session_manager")

require("mjm.plugins.lightbulb")

vim.api.nvim_set_var("db_ui_use_nerd_fonts", 1)

vim.api.nvim_set_var("qs_highlight_on_keys", { "f", "F", "t", "T" })
vim.api.nvim_set_var("qs_max_chars", 9999)
vim.api.nvim_set_hl(0, "QuickScopePrimary", { reverse = true })
vim.api.nvim_set_hl(0, "QuickScopeSecondary", { undercurl = true })

vim.api.nvim_set_var("undotree_WindowLayout", 3)
-- This doesn't really need to be setup until BufReadPre, but Undotree itself autoloads well and
-- gating this map behind an autocmd would add more startup time than just setting it
ApiMap("n", "<leader>u", "<nop>", {
    noremap = true,
    callback = function()
        Cmd({ cmd = "UndotreeToggle" }, {})
    end,
})

local eager_loaded = vim.uv.hrtime()

-----------------------
-- Post-plugin Setup --
-----------------------

require("mjm.lsp")
require("mjm.treesitter") -- TODO: this probably doesn't need to be post-plugin
require("mjm.color_coordination") -- TODO: this probably doesn't need to be post-plugin
require("mjm.tal") -- Requires Harpoon

local post_plugin_setup = vim.uv.hrtime()

-------------------------
-- Lazy Initialization --
-------------------------

-- LOW: Want to unwind this, as this isn't really how the startup is supposed to work. In practice
-- though, it's going to be a question of impact on startup time. Something like jump2d is
-- probably fine to do during startup, because it only requires one file. Whereas if a plugin's
-- setup function recursively requires a bunch of files, then hack the startup we must
-- More specifically, for any plugin that's manually lazy loaded, there should be a commented
-- reason why, rather than lazy loading being the default assumption
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
require("mjm.plugins.specialist")
require("mjm.plugins.treesj")
require("mjm.plugins.ts-autotag")
require("mjm.plugins.zen")

local lazy_loaded = vim.uv.hrtime()

local to_env_setup = math.floor((env_setup - start) / 1e6 * 100) / 100
local to_pack_finish = math.floor((pack_finish - start) / 1e6 * 100) / 100
local to_eager_loaded = math.floor((eager_loaded - start) / 1e6 * 100) / 100
local to_post_plugin_setup = math.floor((post_plugin_setup - start) / 1e6 * 100) / 100
local to_lazy_loaded = math.floor((lazy_loaded - start) / 1e6 * 100) / 100

vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("display-profile-info", { clear = true }),
    callback = function()
        local ui_enter = vim.uv.hrtime()
        local to_ui_enter = math.floor((ui_enter - start) / 1e6 * 100) / 100

        if vim.fn.argc() > 0 or vim.fn.line2byte("$") ~= -1 or vim.bo.modified then
            return
        end

        local headers = {
            { "Setup: ", to_env_setup },
            { "Download/Register Plugins: ", to_pack_finish },
            { "Eager Plugin Init: ", to_eager_loaded },
            { "Post Plugin Setup: ", to_post_plugin_setup },
            { "Lazy Plugin Init: ", to_lazy_loaded },
            { "UI Enter: ", to_ui_enter },
        }

        local max_header_len = 0
        for _, header in ipairs(headers) do
            if #header[1] > max_header_len then
                max_header_len = #header[1]
            end
        end

        for i, header in ipairs(headers) do
            headers[i][1] = header[1] .. string.rep(" ", max_header_len - #header[1] + 2)
        end

        local lines = {
            "",
            "=================",
            "==== STARTUP ====",
            "=================",
            "",
        }

        for _, header in ipairs(headers) do
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

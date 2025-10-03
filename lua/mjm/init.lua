local start = vim.uv.hrtime()

-------------------
--- Before Pack ---
-------------------

_G.Border = "single" ---@type string
_G.GetOpt = vim.api.nvim_get_option_value
_G.Gset = vim.api.nvim_set_var
_G.Has_Nerd_Font = true --- @type boolean
_G.Highlight_Time = 175 --- @type integer
_G.Scrolloff_Val = 6 ---@type integer
_G.SetOpt = vim.api.nvim_set_option_value
_G.SpellFile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add" ---@type string

_G.ApiMap = vim.api.nvim_set_keymap
_G.Augroup = vim.api.nvim_create_augroup
_G.Autocmd = vim.api.nvim_create_autocmd
_G.Cmd = vim.api.nvim_cmd
_G.Map = vim.keymap.set
_G.SetHl = vim.api.nvim_set_hl
_G.GetHl = vim.api.nvim_get_hl

--- @param lhs string
--- @param rhs string
--- @param opts vim.api.keyset.keymap
function _G.NXMap(lhs, rhs, opts)
    vim.api.nvim_set_keymap("n", lhs, rhs, opts)
    vim.api.nvim_set_keymap("x", lhs, rhs, opts)
end

local pre_pack = vim.uv.hrtime()

-------------------------------
-- Download/Register Plugins --
-------------------------------

--- Only downloads plugins/adds them to RTP
require("mjm.pack")

local pack_finish = vim.uv.hrtime()

-----------
-- Setup --
-----------

require("mjm.set")
require("mjm.map")
require("mjm.stl")

require("mjm.error-list") -- Do this first because it sets up g vars
-- require("mjm.error-list-open")
-- require("mjm.error-list-stack")
-- require("mjm.error-list-filter")
-- require("mjm.error-list-nav-action")
require("mjm.error-list-sort")
require("mjm.error-list-system")
require("mjm.error-list-grep")
-- require("mjm.error-list-diag")

local env_setup = vim.uv.hrtime()

---------------------------------
-- Eager Plugin Initialization --
---------------------------------

require("mjm.plugins.nvim-treesitter") -- Text Objects Sets Up Lazily

require("mjm.plugins.fzflua")

require("mjm.plugins.harpoon")
--- LOW: This module requires harpoon to setup the tabline display. For some reason, if this is
--- done before the harpoon module, the setup funciton in the harpoon module will not run properly
--- Curious as to why
--- LOW: Re-add the post-plugin timer section
require("mjm.tal")

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

-------------------------
-- Lazy Initialization --
-------------------------

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

local to_pre_pack = math.floor((pre_pack - start) / 1e6 * 100) / 100
local to_pack_finish = math.floor((pack_finish - start) / 1e6 * 100) / 100
local to_env_setup = math.floor((env_setup - start) / 1e6 * 100) / 100
local to_eager_loaded = math.floor((eager_loaded - start) / 1e6 * 100) / 100
local to_lazy_loaded = math.floor((lazy_loaded - start) / 1e6 * 100) / 100

vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("display-profile-info", { clear = true }),
    callback = function()
        local ui_enter = vim.uv.hrtime()
        local to_ui_enter = math.floor((ui_enter - start) / 1e6 * 100) / 100

        local cur_buf = vim.api.nvim_get_current_buf()
        local modified = vim.api.nvim_get_option_value("modified", { buf = cur_buf })
        if vim.fn.argc() > 0 or vim.fn.line2byte("$") ~= -1 or modified then
            return
        end

        local headers = {
            { "Pre-Pack Setup: ", to_pre_pack },
            { "Download/Register Plugins: ", to_pack_finish },
            { "Setup: ", to_env_setup },
            { "Eager Plugin Init: ", to_eager_loaded },
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

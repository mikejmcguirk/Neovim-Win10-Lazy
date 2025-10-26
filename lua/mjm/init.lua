local start = vim.uv.hrtime() ---@type number

local api = vim.api

-------------------
--- Before Pack ---
-------------------

-- LOW: Create a more general defer require. Look at all of tj's funcs + vim._defer_require
-- To address here: Right now you need a type annotation for lua_ls to see the contents of the
-- module. I *think* vim._defer_require addresses this but haven't checked

--- https://github.com/tjdevries/lazy-require.nvim/blob/master/lua/lazy-require.lua
---@param require_path string
---@return table
function _G.Mjm_Defer_Require(require_path)
    return setmetatable({}, {
        __index = function(_, key)
            return require(require_path)[key]
        end,

        __newindex = function(_, key, value)
            require(require_path)[key] = value
        end,
    })
end

_G.Border = "single" ---@type string
_G.Scrolloff = 6 ---@type integer

vim.keymap.set({ "n", "x" }, "<Space>", "<Nop>")
api.nvim_set_var("mapleader", " ")
api.nvim_set_var("maplocalleader", " ")

local pre_pack = vim.uv.hrtime() ---@type number

-------------------------------
-- Download/Register Plugins --
-------------------------------

--- Only downloads plugins/adds them to RTP
require("mjm.pack")

local pack_finish = vim.uv.hrtime() ---@type number

-----------
-- Setup --
-----------

require("mjm.colorscheme")
require("mjm.set")
require("mjm.map")
require("mjm.custom-cmds")
require("mjm.stl")

-- require("mjm.error-list")

local env_setup = vim.uv.hrtime() ---@type number

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
require("mjm.plugins.misc")

require("mjm.plugins.spec-ops")
require("mjm.plugins.specialist")

local eager_loaded = vim.uv.hrtime() ---@type number

-------------------------
-- Lazy Initialization --
-------------------------

-- TODO: Rather than have each module setup an autocmd, set the autocmds here and gate the modules
-- behind them. More centralized behavior + less eager requires + config code still separate

require("mjm.plugins.blink")
require("mjm.plugins.conform")
require("mjm.plugins.obsidian")
require("mjm.plugins.lazydev")
require("mjm.plugins.ts-autotag")

-- This is fine as long as modules aren't divided into multiple pieces to do this
local buf_augroup_name = "mjm-buf-settings"
vim.api.nvim_create_autocmd({ "BufNew", "BufReadPre" }, {
    group = vim.api.nvim_create_augroup(buf_augroup_name, {}),
    once = true,
    callback = function()
        require("mjm.plugins.autopairs")
        require("mjm.plugins.gitsigns")
        require("mjm.plugins.jump2d")
        require("mjm.plugins.mini-operators")
        require("mjm.plugins.nvim-surround")
        require("mjm.plugins.treesj")
        require("mjm.plugins.zen")

        require("mjm.diagnostics")
        require("mjm.lsp")
        require("mjm.ts-tools")
        api.nvim_del_augroup_by_name(buf_augroup_name)
    end,
})

local lazy_loaded = vim.uv.hrtime() ---@type number

local to_pre_pack = math.floor((pre_pack - start) / 1e6 * 100) / 100 ---@type number
local to_pack_finish = math.floor((pack_finish - start) / 1e6 * 100) / 100 ---@type number
local to_env_setup = math.floor((env_setup - start) / 1e6 * 100) / 100 ---@type number
local to_eager_loaded = math.floor((eager_loaded - start) / 1e6 * 100) / 100 ---@type number
local to_lazy_loaded = math.floor((lazy_loaded - start) / 1e6 * 100) / 100 ---@type number

api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("display-profile-info", {}),
    callback = function()
        local ui_enter = vim.uv.hrtime() ---@type number
        local to_ui_enter = math.floor((ui_enter - start) / 1e6 * 100) / 100 ---@type number

        local buf = api.nvim_get_current_buf() ---@type integer
        local modified = api.nvim_get_option_value("modified", { buf = buf }) ---@type boolean
        if vim.fn.argc() > 0 or vim.fn.line2byte("$") ~= -1 or modified then return end

        local lines = {
            "",
            "=================",
            "==== STARTUP ====",
            "=================",
            "",
        } ---@type string[]

        local stats = {
            { "Pre-Pack Setup: ", to_pre_pack },
            { "Download/Register Plugins: ", to_pack_finish },
            { "Setup: ", to_env_setup },
            { "Eager Plugin Init: ", to_eager_loaded },
            { "Lazy Plugin Init: ", to_lazy_loaded },
            { "UI Enter: ", to_ui_enter },
        } ---@type { [1]:string, [2]:number }[]

        local max_stat_len = 0 ---@type integer
        for _, stat in ipairs(stats) do
            if #stat[1] > max_stat_len then max_stat_len = #stat[1] end
        end

        for _, stat in ipairs(stats) do
            stat[1] = stat[1] .. string.rep(" ", max_stat_len - #stat[1] + 2)
            lines[#lines + 1] = stat[1] .. stat[2] .. "ms"
        end

        local width = api.nvim_win_get_width(0) ---@type integer
        for i, line in ipairs(lines) do
            local padding = string.rep(" ", ((width - #line) * 0.5) - 2) ---@type string
            lines[i] = padding .. line .. padding
        end

        api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local buf_opts = {
            { "buftype", "nofile" },
            { "bufhidden", "wipe" },
            { "swapfile", false },
            { "readonly", true },
            { "modifiable", false },
            { "modified", false },
            { "buflisted", false },
        } ---@type { [1]:string, [2]:any }[]

        for _, opt in ipairs(buf_opts) do
            vim.api.nvim_set_option_value(opt[1], opt[2], { buf = buf })
        end

        vim.api.nvim_create_autocmd("BufLeave", {
            group = vim.api.nvim_create_augroup("leave-greeter", {}),
            buffer = buf,
            once = true,
            callback = function()
                -- Treesitter fails in the next buffer if not scheduled wrapped
                -- Needs to be schedule wrapped, not just vim.schedule
                vim.schedule_wrap(function()
                    api.nvim_buf_delete(buf, { force = true })
                end)
            end,
        })
    end,
})

-- TODO: Bisecting has become impractical due to how config elements are spread out

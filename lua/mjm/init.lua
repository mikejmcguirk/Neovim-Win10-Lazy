local start = vim.uv.hrtime()

local api = vim.api

-------------------
--- Before Pack ---
-------------------

-- LOW: Create a more general defer require. Look at all of tj's funcs + vim._defer_require

--- https://github.com/tjdevries/lazy-require.nvim/blob/master/lua/lazy-require.lua
--- @param require_path string
--- @return table
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
_G.GetOpt = api.nvim_get_option_value
_G.Gset = api.nvim_set_var
_G.Has_Nerd_Font = true --- @type boolean
_G.Highlight_Time = 175 --- @type integer
_G.Scrolloff_Val = 6 ---@type integer
_G.SetOpt = api.nvim_set_option_value
_G.SpellFile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add" ---@type string

_G.Augroup = api.nvim_create_augroup
_G.Autocmd = api.nvim_create_autocmd
_G.Cmd = api.nvim_cmd
_G.Map = vim.keymap.set
_G.SetHl = api.nvim_set_hl
_G.GetHl = api.nvim_get_hl

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

require("mjm.colorscheme")
require("mjm.set")
require("mjm.map")
require("mjm.custom-cmds")
require("mjm.stl")

require("mjm.error-list")

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
require("mjm.plugins.misc")

require("mjm.plugins.spec-ops")
require("mjm.plugins.specialist")

local eager_loaded = vim.uv.hrtime()

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
Autocmd({ "BufNew", "BufReadPre" }, {
    group = Augroup(buf_augroup_name, {}),
    once = true,
    callback = function()
        require("mjm.plugins.autopairs")
        require("mjm.plugins.git_signs")
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

local lazy_loaded = vim.uv.hrtime()

local to_pre_pack = math.floor((pre_pack - start) / 1e6 * 100) / 100
local to_pack_finish = math.floor((pack_finish - start) / 1e6 * 100) / 100
local to_env_setup = math.floor((env_setup - start) / 1e6 * 100) / 100
local to_eager_loaded = math.floor((eager_loaded - start) / 1e6 * 100) / 100
local to_lazy_loaded = math.floor((lazy_loaded - start) / 1e6 * 100) / 100

api.nvim_create_autocmd("UIEnter", {
    group = api.nvim_create_augroup("display-profile-info", { clear = true }),
    callback = function()
        local ui_enter = vim.uv.hrtime()
        local to_ui_enter = math.floor((ui_enter - start) / 1e6 * 100) / 100

        local cur_buf = api.nvim_get_current_buf()
        local modified = api.nvim_get_option_value("modified", { buf = cur_buf })
        if vim.fn.argc() > 0 or vim.fn.line2byte("$") ~= -1 or modified then return end

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
            if #header[1] > max_header_len then max_header_len = #header[1] end
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

        local win = api.nvim_get_current_win()
        local bufnr = api.nvim_win_get_buf(win)
        api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
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
            api.nvim_set_option_value(option[1], option[2], { buf = bufnr })
        end

        api.nvim_create_autocmd("BufLeave", {
            group = api.nvim_create_augroup("leave-greeter", { clear = true }),
            buffer = bufnr,
            once = true,
            callback = function()
                -- Treesitter fails in the next buffer if not scheduled wrapped
                vim.schedule_wrap(function()
                    api.nvim_buf_delete(bufnr, { force = true })
                end)
            end,
        })
    end,
})

------------
--- TODO ---
------------

--- Bisecting has become impractical due to how config elements are spread out

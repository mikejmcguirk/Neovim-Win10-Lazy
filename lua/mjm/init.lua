local api = vim.api
local set = vim.keymap.set

_G.Mjm_Border = "single" ---@type string
_G.Mjm_Scrolloff = 6 ---@type integer
-- LOW: Create a more general defer require. Look at all of tj's funcs + vim._defer_require
-- Needs to work with LSP autocomplete. Maybe vim._defer_require addresses this
-- https://github.com/tjdevries/lazy-require.nvim/blob/master/lua/lazy-require.lua
---@param path string
---@return table
function _G.Mjm_Defer_Require(path)
    return setmetatable({}, {
        __index = function(_, key)
            return require(path)[key]
        end,
        __newindex = function(_, key, value)
            require(path)[key] = value
        end,
    })
end

---@param opt string
---@param out string
---@param scope vim.api.keyset.option
function _G.Mjm_Opt_Str_Remove(opt, out, scope)
    local old = api.nvim_get_option_value(opt, scope) ---@type string
    api.nvim_set_option_value(opt, string.gsub(old, out, ""), scope)
end

set({ "n", "x" }, "<Space>", "<Nop>")
set({ "n", "x" }, "\\", "<Nop>")
api.nvim_set_var("mapleader", " ")
api.nvim_set_var("maplocalleader", "\\")

-- See :h <tab> and https://github.com/neovim/neovim/pull/17932
set("n", "<C-i>", "<C-i>")
set("n", "<tab>", "<tab>")
set("n", "<C-m>", "<C-m>")
set("n", "<cr>", "<cr>")
set("n", "<C-[>", "<C-[>")
set("n", "<esc>", "<esc>")

require("mjm.colorscheme")

require("mjm.lazy")
require("mjm.undotree")
require("mjm.plugins.spec-ops")
require("mjm.plugins.specialist")

require("mjm.set")
require("mjm.autocmd")
require("mjm.map")
require("mjm.custom-cmds")
require("mjm.stl")
require("mjm.diagnostics")
require("mjm.ts-tools")
require("mjm.tal")

require("mjm.lsp")

api.nvim_create_autocmd("UIEnter", {
    once = true,
    callback = function()
        local win = api.nvim_get_current_win() ---@type integer
        if win ~= 1000 then return end
        for _, t_win in ipairs(api.nvim_tabpage_list_wins(0)) do
            if vim.fn.win_gettype(t_win) ~= "popup" and t_win ~= win then return end
        end

        local buf = api.nvim_get_current_buf() ---@type integer
        if buf ~= 1 then return end
        if #api.nvim_buf_get_name(1) > 0 then return end
        local lines = api.nvim_buf_get_lines(buf, 0, -1, false) ---@type string[]
        if #lines > 1 or #lines[1] > 0 then return end

        -- LOW: There's a more nuanced way to handle this where the buffer is re-checked on
        -- BufLeave to see if it's still empty, and wiped if so
        api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
        api.nvim_set_option_value("buftype", "nofile", { buf = buf })
        api.nvim_set_option_value("modifiable", false, { buf = buf })
        api.nvim_set_option_value("swapfile", false, { buf = buf })
        api.nvim_set_option_value("undofile", false, { buf = buf })
    end,
})

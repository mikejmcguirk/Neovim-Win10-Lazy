local start = vim.loop.hrtime()

-----------------------
-- Environment Setup --
-----------------------

-- Avoid race conditions with nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1

vim.g.loaded_2html_plugin = 1
vim.g.loaded_gzip = 1
vim.g.loaded_matchit = 1
-- vim.g.loaded_matchparen = 1 -- FUTURE: Lazy load
vim.g.loaded_remote_plugins = 1
vim.g.loaded_spellfile_plugin = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_tar = 1
vim.g.loaded_tutor_mode_plugin = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_zip = 1

require("mjm.global_vars")

vim.keymap.set({ "n", "x" }, "<Space>", "<Nop>")
vim.g.mapleader = " "
vim.g.maplocaleader = " "

local env_setup = vim.loop.hrtime()

require("mjm.pack")

local pack_finish = vim.loop.hrtime()

--------------------------
-- Eager Loaded Plugins --
--------------------------

require("mjm.plugins.plenary")
require("mjm.plugins.nvim-web-devicons")

require("mjm.plugins.colorscheme")
require("mjm.plugins.nvim-treesitter")

require("mjm.plugins.nvim-lspconfig")

require("mjm.plugins.fzflua")
require("mjm.plugins.harpoon")

require("mjm.plugins.blink") -- Setup is lazy, but add to path for LSP capabilities and compat

require("mjm.plugins.fugitive")

local eager_loaded = vim.loop.hrtime()

------------------------------
-- Standard Config Settings --
------------------------------

require("mjm.set")
require("mjm.keymap")
require("mjm.custom_cmd")
require("mjm.diagnostic")
require("mjm.error-list")
require("mjm.autocmd")
require("mjm.lsp")
require("mjm.stl")
require("mjm.tal")
require("mjm.spec-ops.yank")
require("mjm.spec-ops.delete")
require("mjm.spec-ops.paste")
require("mjm.spec-ops.change")
require("mjm.spec-ops.substitute")
require("mjm.spec-ops.substitute")

local config_set = vim.loop.hrtime()

-------------------------
-- Lazy Loaded Plugins --
-------------------------

require("mjm.plugins.abolish")
require("mjm.plugins.autopairs")
require("mjm.plugins.conform")
require("mjm.plugins.dadbod")
require("mjm.plugins.flash")
require("mjm.plugins.git_signs")
require("mjm.plugins.indent_highlight")
require("mjm.plugins.lazydev")
require("mjm.plugins.nvim-surround")
require("mjm.plugins.obsidian")
require("mjm.plugins.quickscope")
require("mjm.plugins.ts-autotag")
require("mjm.plugins.undotree")
require("mjm.plugins.zen")

local lazy_loaded = vim.loop.hrtime()

local to_env_setup = math.floor((env_setup - start) / 1e6 * 100) / 100
local to_pack_finished = math.floor((pack_finish - start) / 1e6 * 100) / 100
local to_eager_loaded = math.floor((eager_loaded - start) / 1e6 * 100) / 100
local to_config_set = math.floor((config_set - start) / 1e6 * 100) / 100
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
            { "Environment setup: ", to_env_setup },
            { "vim.pack: ", to_pack_finished },
            { "Eager Plugin Loading: ", to_eager_loaded },
            { "Setup Config: ", to_config_set },
            { "Setup Lazy Loading: ", to_lazy_loaded },
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
        vim.api.nvim_set_option_value("nu", true, { win = win })

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

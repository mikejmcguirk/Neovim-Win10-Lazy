local api = vim.api

require("mjm.mjm")

Mjm_Format_Lhs = "gW"

vim.keymap.set({ "n", "x" }, "<Space>", "<Nop>")
vim.keymap.set({ "n", "x" }, "\\", "<Nop>")
api.nvim_set_var("mapleader", " ")
api.nvim_set_var("maplocalleader", "\\")

-- See :h <tab> and https://github.com/neovim/neovim/pull/17932
vim.keymap.set("n", "<C-i>", "<C-i>")
vim.keymap.set("n", "<tab>", "<tab>")
vim.keymap.set("n", "<C-m>", "<C-m>")
vim.keymap.set("n", "<cr>", "<cr>")
vim.keymap.set("n", "<C-[>", "<C-[>")
vim.keymap.set("n", "<esc>", "<esc>")

-- :h standard-plugin-list
-- api.nvim_set_var("loaded_2html_plugin", 1)
api.nvim_set_var("did_install_default_menus", 1)
-- api.nvim_set_var("loaded_gzip", 1)
-- api.nvim_set_var("loaded_man", 1)
-- api.nvim_set_var("loaded_matchit", 1)
-- api.nvim_set_var("loaded_matchparen", 1)
-- api.nvim_set_var("loaded_netrw", 1)
-- api.nvim_set_var("loaded_netrwPlugin", 1)
-- api.nvim_set_var("loaded_netrwSettings", 1)
-- api.nvim_set_var("loaded_remote_plugins", 1)
-- api.nvim_set_var("loaded_spellfile_plugin", 1)
-- api.nvim_set_var("loaded_tar", 1)
-- api.nvim_set_var("loaded_tarPlugin", 1)
-- api.nvim_set_var("loaded_tutor_mode_plugin", 1)
-- api.nvim_set_var("loaded_zip", 1)
-- api.nvim_set_var("loaded_zipPlugin", 1)

local termfeatures = vim.g.termfeatures or {}
termfeatures.osc52 = false -- I use xsel
api.nvim_set_var("termfeatures", termfeatures)

api.nvim_cmd({ cmd = "colorscheme", args = { "simple_delta" } }, {})

require("mjm.lazy")
require("mjm.nvim-plugins")
require("mjm.internal")

require("mjm.set")
require("mjm.autocmd")
require("mjm.map")
require("mjm.custom-cmds")
require("mjm.stl")
require("mjm.diagnostics")
require("mjm.ts-tools")
require("mjm.tal")

require("mjm.lsp")

if
    not (
        vim.v.startreason == "normal"
        and api.nvim_buf_is_valid(1)
        and require("nvim-tools.buf").is_empty_noname(1)
    )
then
    return
end

api.nvim_create_autocmd("BufHidden", {
    buffer = 1,
    callback = function()
        -- AFAICT, the only function that triggers this event is close_buffer in buffer.c
        -- The BufHidden event is only meant to be fired when there are no plans to unload.
        -- Deleting the buffer within the BufHidden event creates unwinding behavior. This is
        -- not *un*-intended, but I have seen treesitter fail to properly attach to the next
        -- buffer if this is not scheduled.
        vim.schedule(function()
            local ntb = require("nvim-tools.buf")
            if ntb.is_empty_noname(1) and #vim.call("win_findbuf", 1) == 0 then
                ntb.protected_del(1, true, { force = true })
            end
        end)
    end,
})

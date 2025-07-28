-----------------------
-- Environment Setup --
-----------------------

-- To avoid race conditions with nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1

-- Have to do this before it's loaded
vim.g.qs_highlight_on_keys = { "f", "F", "t", "T" }
vim.g.qs_max_chars = 9999

-- Ensure nothing's missed
vim.keymap.set({ "n", "x" }, "<Space>", "<Nop>")
vim.g.mapleader = " "
vim.g.maplocaleader = " "

require("mjm.pack")
require("mjm.global_vars")

--------------------------
-- Eager Loaded Plugins --
--------------------------

require("mjm.plugins.colorscheme")
require("mjm.plugins.quickscope") -- For the highlight groups
require("mjm.plugins.nvim-treesitter")
vim.cmd("TSUpdate")
require("mjm.plugins.cmp") -- Since so many other plugins depend on it

require("mjm.plugins.harpoon")
require("mjm.plugins.lualine")

require("mjm.plugins.dadbod")
require("mjm.plugins.fugitive")
require("mjm.plugins.fzflua")
require("mjm.plugins.nvim-tree")

------------------------------
-- Standard Config Settings --
------------------------------

require("mjm.set")
require("mjm.keymap")
require("mjm.custom_cmd")
require("mjm.diagnostic")
require("mjm.error-list")
require("mjm.autocmd")

require("mjm.lsp") -- Requires LSPConfig Plugin

-------------------------
-- Lazy Loaded Plugins --
-------------------------

require("mjm.plugins.autopairs")
require("mjm.plugins.colorizer")
require("mjm.plugins.conform")
require("mjm.plugins.flash")
require("mjm.plugins.git_signs")
require("mjm.plugins.indent_highlight")
require("mjm.plugins.lazydev")
require("mjm.plugins.markdown-preview")
require("mjm.plugins.nvim-surround")
require("mjm.plugins.obsidian")
require("mjm.plugins.substitute")
require("mjm.plugins.ts-autotag")
require("mjm.plugins.undotree")
require("mjm.plugins.zen")

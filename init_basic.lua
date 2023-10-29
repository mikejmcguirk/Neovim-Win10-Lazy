vim.keymap.set("", "<Space>", "<Nop>", Opts)
vim.g.mapleader = " "
vim.g.maplocaleader = " "

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.shiftround = true

vim.opt.autoindent = true
vim.opt.smartindent = true

vim.opt.termguicolors = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.hlsearch = true
vim.opt.incsearch = true

local opts = { noremap = true, silent = true }
vim.keymap.set("n", "<C-h>", "<C-w>h", opts)
vim.keymap.set("n", "<C-j>", "<C-w>j", opts)
vim.keymap.set("n", "<C-k>", "<C-w>k", opts)
vim.keymap.set("n", "<C-l>", "<C-w>l", opts)

vim.keymap.set("n", "<C-u>", "<C-u>zz", opts)
vim.keymap.set("n", "<C-d>", "<C-d>zz", opts)

vim.keymap.set("n", "n", "nzzzv", opts)
vim.keymap.set("n", "N", "Nzzzv", opts)

vim.keymap.set("n", "J", "mzJ`z", opts)

vim.keymap.set("v", "<", "<gv", opts)
vim.keymap.set("v", ">", ">gv", opts)


vim.keymap.set({ "n", "v" }, "<leader>d", "\"_d", opts)
vim.keymap.set({ "n", "v" }, "<leader>D", "\"_D", opts)

vim.keymap.set({ "n", "v" }, "<leader>c", "\"_c", opts)
vim.keymap.set({ "n", "v" }, "<leader>C", "\"_C", opts)

vim.keymap.set("n", "Y", "y$", opts)

vim.keymap.set("n", "<leader>y", "\"+y", opts)
vim.keymap.set("n", "<leader>Y", "\"+y$", opts)

vim.keymap.set("n", "<leader>p", "\"+p", opts)
vim.keymap.set("n", "<leader>P", "\"+P", opts)

vim.keymap.set("v", "p", "\"_dP", opts)
vim.keymap.set("v", "<leacer>p", "\"_d\"+P", opts)

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", opts)
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", opts)

local exprOpts = { noremap = true, expr = true, silent = true }

vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", exprOpts)
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", exprOpts)

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        opts = {},
        config = function()
            vim.cmd("colorscheme tokyonight")
        end
    },
    {
        'tpope/vim-fugitive',
    },
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = { "nvim-lua/plenary.nvim",
            {
                "nvim-telescope/telescope-fzf-native.nvim",
                build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build " ..
                    "--config Release && cmake --install build --prefix build",
                cond = function()
                    return vim.fn.executable("cmake") == 1
                end,
            },
        },
        config = function()
            local telescope = require("telescope")

            telescope.setup {
                defaults = {
                    mappings = {
                        i = {
                            ['<C-u>'] = false,
                            ['<C-d>'] = false,
                        },
                    },
                },
            }

            pcall(telescope.load_extension("fzf"))

            local builtin = require("telescope.builtin")

            vim.keymap.set("n", "<leader>tb", builtin.buffers)
            vim.keymap.set("n", "<leader>te", builtin.live_grep)
            vim.keymap.set("n", "<leader>tf", builtin.find_files)
            vim.keymap.set("n", "<leader>tg", builtin.git_files)
            vim.keymap.set("n", "<leader>th", builtin.help_tags)
            vim.keymap.set("n", "<leader>tr", builtin.resume)
        end
    },
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
        config = function()
            local configs = require("nvim-treesitter.configs")

            configs.setup({
                modules = {},
                ignore_install = {},
                auto_install = false,
                ensure_installed = { "c", "lua", "vim", "vimdoc", "query" },
                sync_install = false,
                highlight = {
                    enable = true,
                    additional_vim_regex_highlighting = false,
                },
                indent = { enable = true },
                textobjects = {
                    select = {
                        enable = true,
                        lookahead = false,
                        keymaps = {
                            ["af"] = "@function.outer",
                            ["if"] = "@function.inner",
                        }
                    }
                }
            })
        end
    },
})

local yank_group = vim.api.nvim_create_augroup("HighlightYank", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
    group = yank_group,
    pattern = "*",
    callback = function()
        vim.highlight.on_yank({
            higroup = "IncSearch",
            timeout = 200,
        })
    end,
})

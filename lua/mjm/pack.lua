-- FUTURE:
-- https://github.com/kosayoda/nvim-lightbulb
-- Show icon where code actions are available, but would need more aesthetic icon

-- TODO: Re-install numToStr/Comment
-- DOn't like all of the default mappings, but it has some good motions built in

vim.pack.add({
    -- Multi-deps
    { src = "https://github.com/mike-jl/harpoonEx" },
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/nvim-lua/plenary.nvim" },

    { src = "https://github.com/stevearc/conform.nvim" },

    { src = "https://github.com/folke/flash.nvim" },

    { src = "https://github.com/maxmx03/fluoromachine.nvim", version = "a5dc2cd" },

    -- Requires nvim-tree-web-devicons
    { src = "https://github.com/ibhagwan/fzf-lua" },

    { src = "https://github.com/lewis6991/gitsigns.nvim" },

    { src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" },

    { src = "https://github.com/lukas-reineke/indent-blankline.nvim" },
    { src = "https://github.com/echasnovski/mini.indentscope" },

    -- { src = "https://github.com/folke/lazydev.nvim" },
    { src = "https://github.com/Jari27/lazydev.nvim" },

    -- Depends on nvim-web-devicons, Harpoon, and HarpoonEx
    { src = "https://github.com/nvim-lualine/lualine.nvim" },
    { src = "https://github.com/linrongbin16/lsp-progress.nvim" },

    { src = "https://github.com/iamcco/markdown-preview.nvim" },

    { src = "https://github.com/windwp/nvim-autopairs" },

    { src = "https://github.com/hrsh7th/nvim-cmp" },
    { src = "https://github.com/hrsh7th/vim-vsnip" },
    { src = "https://github.com/hrsh7th/cmp-vsnip" },
    { src = "https://github.com/rafamadriz/friendly-snippets" },
    { src = "https://github.com/hrsh7th/cmp-nvim-lsp" },
    -- Show current function signature
    { src = "https://github.com/hrsh7th/cmp-nvim-lsp-signature-help" },
    { src = "https://github.com/hrsh7th/cmp-buffer" },
    -- From Nvim's built-in spell check },
    { src = "https://github.com/f3fora/cmp-spell" },
    { src = "https://github.com/FelipeLema/cmp-async-path" },
    { src = "https://github.com/ray-x/cmp-sql" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-completion" },

    { src = "https://github.com/NvChad/nvim-colorizer.lua" },

    { src = "https://github.com/neovim/nvim-lspconfig" },

    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },

    { src = "https://github.com/kylechui/nvim-surround" },

    -- Depends on nvim-web-devicons
    { src = "https://github.com/nvim-tree/nvim-tree.lua" },

    { src = "https://github.com/windwp/nvim-ts-autotag" },

    -- Depends on plenary
    { src = "https://github.com/epwalsh/obsidian.nvim" },

    { src = "https://github.com/unblevable/quick-scope" },

    { src = "https://github.com/gbprod/substitute.nvim" },

    { src = "https://github.com/mbbill/undotree" },

    { src = "https://github.com/tpope/vim-abolish" },

    { src = "https://github.com/tpope/vim-dadbod" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-ui" },

    { src = "https://github.com/tpope/vim-fugitive" },

    { src = "https://github.com/folke/zen-mode.nvim" },
})

vim.keymap.set("n", "zqu", function()
    vim.pack.update()
end)

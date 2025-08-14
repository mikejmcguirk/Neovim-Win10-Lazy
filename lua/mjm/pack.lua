-- FUTURE:
-- https://github.com/kosayoda/nvim-lightbulb
-- Show icon where code actions are available, but would need more aesthetic icon
-- The nerd font lightbulb might suffice

local pack_spec = {
    -- Multi-deps
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/nvim-lua/plenary.nvim" },

    { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.*") },
    { src = "https://github.com/Saghen/blink.compat", version = vim.version.range("2.*") },
    { src = "https://github.com/rafamadriz/friendly-snippets" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-completion" },
    -- Requires plenary
    -- { src = "https://github.com/mikejmcguirk/blink-cmp-dictionary", version = "add-cancel" },
    -- { src = "https://github.com/Kaiser-Yang/blink-cmp-dictionary" },

    { src = "https://github.com/numToStr/Comment.nvim" },

    { src = "https://github.com/stevearc/conform.nvim" },

    { src = "https://github.com/folke/flash.nvim" },

    { src = "https://github.com/maxmx03/fluoromachine.nvim", version = "a5dc2cd" },

    -- Requires nvim-tree-web-devicons
    { src = "https://github.com/ibhagwan/fzf-lua" },

    { src = "https://github.com/lewis6991/gitsigns.nvim" },

    { src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" },

    { src = "https://github.com/lukas-reineke/indent-blankline.nvim" },

    -- LOW: Replace with custom config
    -- { src = "https://github.com/folke/lazydev.nvim" },
    { src = "https://github.com/Jari27/lazydev.nvim", version = "deprecate_client_notify" },

    { src = "https://github.com/windwp/nvim-autopairs" },

    { src = "https://github.com/NvChad/nvim-colorizer.lua" },

    { src = "https://github.com/neovim/nvim-lspconfig" },

    { src = "https://github.com/kylechui/nvim-surround", version = vim.version.range("^3.0.0") },

    -- Requires nvim-web-devicons
    { src = "https://github.com/nvim-tree/nvim-tree.lua", version = vim.version.range("*") },

    -- { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "master" },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },

    { src = "https://github.com/windwp/nvim-ts-autotag" },

    -- Depends on plenary
    { src = "https://github.com/epwalsh/obsidian.nvim" },

    { src = "https://github.com/unblevable/quick-scope" },

    { src = "https://github.com/gbprod/substitute.nvim" },

    { src = "https://github.com/mbbill/undotree" },

    { src = "https://github.com/tpope/vim-abolish" },

    { src = "https://github.com/tpope/vim-dadbod" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-ui" },

    -- NOTE: The FugitiveChanged event is used for statusline updates
    { src = "https://github.com/tpope/vim-fugitive" },

    { src = "https://github.com/tpope/vim-speeddating" },

    { src = "https://github.com/folke/zen-mode.nvim" },
}

--- @param ctx {spec: vim.pack.Spec, path: string}
local function load(ctx)
    vim.cmd.packadd({
        vim.fn.escape(ctx.spec.name, " "),
        bang = true,
        magic = { file = false },
    })
end

vim.pack.add(pack_spec, { load = load })

vim.keymap.set("n", "zqu", function()
    local spec = vim.pack.get()

    local names = {}
    for _, p in ipairs(spec) do
        table.insert(names, p.spec.name)
    end

    vim.pack.update(names)
end)

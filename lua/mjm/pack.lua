-- FUTURE:
-- https://github.com/kosayoda/nvim-lightbulb
-- Show icon where code actions are available, but would need more aesthetic icon
-- The nerd font lightbulb might suffice

local M = {}

local pack_spec = {
    -- Multi-deps
    { name = "nvim-web-devicons", src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { name = "plenary.nvim", src = "https://github.com/nvim-lua/plenary.nvim" },

    {
        name = "blink.cmp",
        src = "https://github.com/saghen/blink.cmp",
        version = vim.version.range("1.*"),
    },
    {
        name = "blink.compat",
        src = "https://github.com/Saghen/blink.compat",
        version = vim.version.range("2.*"),
    },
    { name = "friendly-snippets", src = "https://github.com/rafamadriz/friendly-snippets" },
    {
        name = "vim-dadbod-completion",
        src = "https://github.com/kristijanhusak/vim-dadbod-completion",
    },
    -- Requires plenary
    -- { src = "https://github.com/mikejmcguirk/blink-cmp-dictionary", version = "add-cancel" },
    -- { src = "https://github.com/Kaiser-Yang/blink-cmp-dictionary" },

    { name = "Comment.nvim", src = "https://github.com/numToStr/Comment.nvim" },

    { name = "conform.nvim", src = "https://github.com/stevearc/conform.nvim" },

    { name = "flash.nvim", src = "https://github.com/folke/flash.nvim" },

    {
        name = "fluoromachine.nvim",
        src = "https://github.com/maxmx03/fluoromachine.nvim",
        version = "a5dc2cd",
    },

    -- Requires nvim-tree-web-devicons
    { name = "fzf-lua", src = "https://github.com/ibhagwan/fzf-lua" },

    { name = "gitsigns.nvim", src = "https://github.com/lewis6991/gitsigns.nvim" },

    { name = "harpoon", src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" },

    {
        name = "indent-blankline.nvim",
        src = "https://github.com/lukas-reineke/indent-blankline.nvim",
    },

    -- LOW: Replace with custom config
    -- { src = "https://github.com/folke/lazydev.nvim" },
    {
        name = "lazydev.nvim",
        src = "https://github.com/Jari27/lazydev.nvim",
        version = "deprecate_client_notify",
    },

    { name = "nvim-autopairs", src = "https://github.com/windwp/nvim-autopairs" },

    { name = "nvim-colorizer.lua", src = "https://github.com/NvChad/nvim-colorizer.lua" },

    { name = "nvim-lspconfig", src = "https://github.com/neovim/nvim-lspconfig" },

    {
        name = "nvim-surround",
        src = "https://github.com/kylechui/nvim-surround",
        version = vim.version.range("^3.0.0"),
    },

    -- Requires nvim-web-devicons
    {
        name = "nvim-tree.lua",
        src = "https://github.com/nvim-tree/nvim-tree.lua",
        version = vim.version.range("*"),
    },

    -- {
    --     name = "nvim-treesitter",
    --     src = "https://github.com/nvim-treesitter/nvim-treesitter",
    --     version = "main",
    -- },
    {
        name = "nvim-treesitter",
        src = "https://github.com/nvim-treesitter/nvim-treesitter",
        version = "master",
    },
    {
        name = "nvim-treesitter-textobjects",
        src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects",
    },

    { name = "nvim-ts-autotag", src = "https://github.com/windwp/nvim-ts-autotag" },

    -- Depends on plenary
    { name = "obsidian.nvim", src = "https://github.com/epwalsh/obsidian.nvim" },

    { name = "quick-scope", src = "https://github.com/unblevable/quick-scope" },

    { name = "substitute.nvim", src = "https://github.com/gbprod/substitute.nvim" },

    { name = "undotree", src = "https://github.com/mbbill/undotree" },

    { name = "vim-abolish", src = "https://github.com/tpope/vim-abolish" },

    { name = "vim-dadbod", src = "https://github.com/tpope/vim-dadbod" },
    { name = "vim-dadbod-ui", src = "https://github.com/kristijanhusak/vim-dadbod-ui" },

    -- NOTE: The FugitiveChanged event is used for statusline updates
    { name = "vim-fugitive", src = "https://github.com/tpope/vim-fugitive" },

    { name = "zen-mode.nvim", src = "https://github.com/folke/zen-mode.nvim" },
}

local paths = {}

vim.pack.add(pack_spec, {
    load = function(ctx)
        paths[ctx.spec.name] = ctx.path
    end,
})

function M.post_load(plug_name)
    vim.cmd.packadd({
        vim.fn.escape(plug_name, " "),
        bang = false,
        magic = { file = false },
    })

    local plugin_path = paths[plug_name]
    local after_paths = vim.fn.glob(plugin_path .. "/after/plugin/**/*.{vim,lua}", false, true)

    --- @param path string
    vim.tbl_map(function(path)
        vim.cmd.source({ path, magic = { file = false } })
    end, after_paths)
end

vim.keymap.set("n", "zqu", function()
    local spec = vim.pack.get()

    local names = {}
    for _, p in ipairs(spec) do
        table.insert(names, p.spec.name)
    end

    vim.pack.update(names)
end)

return M

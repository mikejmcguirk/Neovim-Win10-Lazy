-- TODO: Doing a lot of restarting Neovim to enter the same windows I was in before to refresh
-- code changes. Build or download a plugin for session management
-- FUTURE:
-- https://github.com/kosayoda/nvim-lightbulb
-- Show icon where code actions are available, but would need more aesthetic icon
-- The nerd font lightbulb might suffice
-- FUTURE: https://github.com/rockerBOO/awesome-neovim - So many plugins out there

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

    { name = "conform.nvim", src = "https://github.com/stevearc/conform.nvim" },

    { name = "flash.nvim", src = "https://github.com/folke/flash.nvim" },

    -- Requires nvim-tree-web-devicons
    { name = "fzf-lua", src = "https://github.com/ibhagwan/fzf-lua" },

    { name = "gitsigns.nvim", src = "https://github.com/lewis6991/gitsigns.nvim" },

    { name = "harpoon", src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" },

    -- LOW: Replace with custom config
    -- { src = "https://github.com/folke/lazydev.nvim" },
    {
        name = "lazydev.nvim",
        src = "https://github.com/Jari27/lazydev.nvim",
        version = "deprecate_client_notify",
    },

    { name = "nvim-autopairs", src = "https://github.com/windwp/nvim-autopairs" },

    { name = "nvim-lspconfig", src = "https://github.com/neovim/nvim-lspconfig" },

    {
        name = "nvim-surround",
        src = "https://github.com/kylechui/nvim-surround",
        version = vim.version.range("^3.0.0"),
    },

    {
        name = "nvim-treesitter",
        src = "https://github.com/nvim-treesitter/nvim-treesitter",
        version = "main",
    },
    {
        name = "nvim-treesitter-textobjects",
        src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects",
        version = "main",
    },

    { name = "nvim-ts-autotag", src = "https://github.com/windwp/nvim-ts-autotag" },

    -- Depends on plenary
    { name = "obsidian.nvim", src = "https://github.com/epwalsh/obsidian.nvim" },

    -- Depends on mini.icons or nvim-tree/nvim-web-devicons
    { name = "oil.nvim", src = "https://github.com/stevearc/oil.nvim" },

    { name = "quick-scope", src = "https://github.com/unblevable/quick-scope" },

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
    vim.cmd.packadd({ vim.fn.escape(plug_name, " "), bang = false, magic = { file = false } })

    local plugin_path = paths[plug_name]
    local after_paths = vim.fn.glob(plugin_path .. "/after/plugin/**/*.{vim,lua}", false, true)

    for _, path in pairs(after_paths) do
        vim.cmd.source({ path, magic = { file = false } })
    end
end

vim.keymap.set("n", "zqu", function()
    vim.pack.update()
end)

return M

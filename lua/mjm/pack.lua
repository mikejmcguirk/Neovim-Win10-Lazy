-- FUTURE: https://github.com/kosayoda/nvim-lightbulb
-- Show icon where code actions are available, but would need more aesthetic icon
-- The nerd font lightbulb might suffice
-- FUTURE: https://github.com/rockerBOO/awesome-neovim - So many plugins out there

local M = {}

local pack_spec = {
    -- Multi-deps
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/nvim-lua/plenary.nvim" },

    { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.*") },
    { src = "https://github.com/rafamadriz/friendly-snippets" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-completion" },
    -- Requires plenary
    -- { src = "https://github.com/mikejmcguirk/blink-cmp-dictionary", version = "add-cancel" },
    -- { src = "https://github.com/Kaiser-Yang/blink-cmp-dictionary" },

    { src = "https://github.com/stevearc/conform.nvim" },

    -- Requires nvim-tree-web-devicons
    { src = "https://github.com/ibhagwan/fzf-lua" },

    { src = "https://github.com/lewis6991/gitsigns.nvim" },

    { src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" },

    { src = "https://github.com/nvim-mini/mini.jump2d" },

    { src = "https://github.com/nvim-mini/mini.operators" },

    -- LOW: Replace with custom config
    -- { src = "https://github.com/folke/lazydev.nvim" },
    { src = "https://github.com/Jari27/lazydev.nvim", version = "deprecate_client_notify" },

    { src = "https://github.com/Shatur/neovim-session-manager" },

    { src = "https://github.com/windwp/nvim-autopairs" },

    { src = "https://github.com/neovim/nvim-lspconfig" },

    { src = "https://github.com/kylechui/nvim-surround", version = vim.version.range("^3.0.0") },

    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },

    { src = "https://github.com/windwp/nvim-ts-autotag" },

    { src = "https://github.com/obsidian-nvim/obsidian.nvim" },

    -- Depends on mini.icons or nvim-tree/nvim-web-devicons
    { src = "https://github.com/stevearc/oil.nvim" },

    { src = "https://github.com/unblevable/quick-scope" },

    { src = "https://github.com/Wansmer/treesj" },

    { src = "https://github.com/mbbill/undotree" },

    -- LOW: Nvim has a preview handler that would allow the Subvert command to be displayed like
    -- the built-in substitute command
    { src = "https://github.com/tpope/vim-abolish" },

    { src = "https://github.com/tpope/vim-dadbod" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-ui" },

    -- NOTE: The FugitiveChanged event is used for statusline updates
    { src = "https://github.com/tpope/vim-fugitive" },

    { src = "https://github.com/folke/zen-mode.nvim" },
}

vim.pack.add(pack_spec, {})

Map("n", "zqc", function()
    local inactive = vim.iter(pairs(vim.pack.get()))
        :map(function(_, s) return (not s.active) and s.spec.name or nil end)
        :totable() --- @type string[]

    vim.pack.del(inactive)
end)

Map("n", "zqd", function()
    local prompt = "Enter plugins to delete (space separated): " --- @type string
    local ok, result = require("mjm.utils").get_input(prompt) --- @type boolean, string
    if not ok then
        local msg = result or "Unknown error getting input" --- @type string
        vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        return
    elseif result == "" then
        return
    end

    vim.pack.del(vim.split(result, " "))
end)

Map("n", "zqp", function()
    if vim.fn.confirm("Purge all plugins?", "&Yes\n&No", 2) ~= 1 then return end

    local plugins = vim.iter(pairs(vim.pack.get()))
        :map(function(_, s) return s.spec.name end)
        :totable() --- @type string[]

    vim.pack.del(plugins)
end)

Map("n", "zqu", function() vim.pack.update() end)

return M

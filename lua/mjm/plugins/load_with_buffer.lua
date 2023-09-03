return {
    {
        'lukas-reineke/indent-blankline.nvim',
        event = "BufReadPre",
        config = function() require("indent_blankline").setup{
            show_current_context = true,
            show_current_context_start = false,
            show_trailing_blankline_indent = true,
        } end
    },
    {
        'nvim-treesitter/playground',
        event = "BufReadPre",
        dependencies = { 'nvim-treesitter' },
    },
    {
        'NvChad/nvim-colorizer.lua',
        lazy = false,
        event = "BufReadPre",
        config = function()
            require("colorizer").setup {
                filetypes = { "*" },
                user_default_options = {
                    RGB = false,
                    RRGGBB = true,
                    names = false,
                    RRGGBBAA = false,
                    AARRGGBB = false,
                    rgb_fn = false,
                    hsl_fn = false,
                    css = false,
                    css_fn = false,

                    mode = "background",

                    tailwind = false,

                    sass = { enable = false, parsers = { "css" }, },
                    virtualtext = "■",

                    always_update = false
                },
                buftypes = {},
            }
        end,
    },
    {
        'windwp/nvim-autopairs',
        event = "InsertEnter",
        opts = ({}) -- Blank explicitly specified as per the repo
    },
    {
        'nvim-treesitter/nvim-treesitter-context',
        event = "BufReadPre",
        config = function()
            require('treesitter-context').setup ({
                separator = '-'
            })
        end
    },
    {
        'iamcco/markdown-preview.nvim',
        ft = "markdown",
        config = function()
            vim.fn["mkdp#util#install"]()
        end
    },
    {
        'tpope/vim-surround',
        event = "BufReadPre"
    },
    {
        'dense-analysis/ale',
        -- event = "BufReadPre",
    },
    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        event = "BufReadPre",
        opts = {
            -- For such a simple plugin, tons of options on the repo
            height = 14, -- height of the trouble list when position is top or bottom
            padding = false, -- add an extra new line on top of the list
            action_keys = {
                -- jump to the diagnostic or open / close folds
                jump = { "<cr>", "<tab>" },
            },
            -- enabling this will use the signs defined in your lsp client
            use_diagnostic_signs = true
        },
    },
    {
        'rust-lang/rust.vim',
        ft = "rust",
    },
    {
        'numToStr/Comment.nvim',
        event = "BufReadPre",
        config = function()
            require('Comment').setup()
        end,
    },
}

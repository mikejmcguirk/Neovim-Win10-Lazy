return {
    {
        'dense-analysis/ale',
        event = "BufReadPre",
    },
    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        event = "BufReadPre",
        opts = {
            height = 12,
            padding = false, -- add an extra new line on top of the list
            action_keys = {
                -- jump to the diagnostic or open / close folds
                -- By default the mouse is enabled here
                jump = { "<cr>", "<tab>" },
            },
            -- enabling this will use the signs defined in your lsp client
            use_diagnostic_signs = true
        },
        config = function()
            vim.keymap.set("n", "<leader>b", "<cmd>TroubleToggle<cr>")
        end
    },
    {
        'iamcco/markdown-preview.nvim',
        ft = "markdown",
        config = function()
            vim.fn["mkdp#util#install"]()

            vim.keymap.set("n", "<leader>me", "<cmd>MarkdownPreview<cr>")
            vim.keymap.set("n", "<leader>ms", "<cmd>MarkdownPreviewStop<cr>")
            vim.keymap.set("n", "<leader>mt", "<cmd>MarkdownPreviewToggle<cr>")
        end
    },
    {
        'lukas-reineke/indent-blankline.nvim',
        event = "BufReadPre",
        config = function()
            require("indent_blankline").setup {
                show_current_context = true,
                show_current_context_start = false,
                show_trailing_blankline_indent = true,
            }
        end
    },
    {
        'numToStr/Comment.nvim',
        event = "BufReadPre",
        config = function()
            require('Comment').setup()
        end,
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

            vim.keymap.set("n", "<leader>ot", "<cmd>ColorizerToggle<cr>")
            vim.keymap.set("n", "<leader>oa", "<cmd>ColorizerAttachToBuffer<cr>")
            vim.keymap.set("n", "<leader>od", "<cmd>ColorizerDetachFromBuffer<cr>")
            vim.keymap.set("n", "<leader>or", "<cmd>ColorizerReloadAllBuffers<cr>")
        end,
    },
    {
        'nvim-treesitter/playground',
        event = "BufReadPre",
        dependencies = { 'nvim-treesitter' },
        config = function()
            vim.keymap.set("n", "<leader>it", "<cmd>TSPlaygroundToggle<cr>")
            vim.keymap.set("n", "<leader>ih", "<cmd>TSHighlightCapturesUnderCursor<cr>")
        end
    },
    {
        'nvim-treesitter/nvim-treesitter-context',
        event = "BufReadPre",
        config = function()
            require('treesitter-context').setup({
                separator = '-'
            })

            vim.keymap.set("n", "<leader>eo", "<cmd>TSContextToggle<cr>")
        end
    },
    {
        'rust-lang/rust.vim',
        ft = "rust",
    },
    {
        'tpope/vim-surround',
        event = "BufReadPre"
    },
    {
        'windwp/nvim-autopairs',
        event = "InsertEnter",
        opts = ({}) -- Blank explicitly specified as per the repo
    },
}

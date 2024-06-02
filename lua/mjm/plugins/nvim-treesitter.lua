return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        "nvim-treesitter/nvim-treesitter-textobjects",
        "windwp/nvim-ts-autotag",
    },
    config = function()
        local configs = require("nvim-treesitter.configs")

        configs.setup({
            modules = {},
            ignore_install = {},
            auto_install = false,
            ensure_installed = {
                "c",
                "lua",
                "vim",
                "vimdoc",
                "query",
                "elixir",
                "heex",
                "javascript",
                "html",
                "css",
                "rust",
                "sql",
                "c_sharp",
                "python",
                "json",
                "typescript",
                "dockerfile",
                "bash",
                "perl",
                "markdown",
                "markdown_inline",
            },
            sync_install = false,
            highlight = { enable = true, additional_vim_regex_highlighting = false },
            indent = { enable = true },
            autotag = { enable = true },
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true,
                    keymaps = {
                        ["a,"] = "@parameter.outer",
                        ["i,"] = "@parameter.inner",
                        ["af"] = "@function.outer",
                        ["if"] = "@function.inner",
                        ["ao"] = "@comment.outer",
                        ["io"] = "@comment.inner",
                    },
                },
                move = {
                    enable = true,
                    set_jumps = true,
                    goto_previous_start = {
                        ["[,"] = "@parameter.inner",
                        ["[c"] = "@comment.outer",
                        ["[f"] = "@function.outer",
                    },
                    goto_next_start = {
                        ["],"] = "@parameter.inner",
                        ["]c"] = "@comment.outer",
                        ["]f"] = "@function.outer",
                    },
                },
                swap = {
                    enable = true,
                    swap_previous = { ["<leader>[,"] = "@parameter.inner" },
                    swap_next = { ["<leader>],"] = "@parameter.inner" },
                },
                lsp_interop = {
                    enable = true,
                    border = "single",
                    floating_preview_opts = {},
                    peek_definition_code = {
                        ["<leader>glf"] = "@function.outer",
                        ["<leader>glc"] = "@class.outer",
                    },
                },
            },
        })
    end,
}

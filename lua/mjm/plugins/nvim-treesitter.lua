return {
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
            },
            sync_install = false,
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = false,
            },
            indent = { enable = true },
            autotag = {
                enable = true,
            },
            playground = {
                enable = true,
                disable = {},
                updatetime = 25,
                persist_queries = false,
                keybindings = {
                    toggle_query_editor = "o",
                    toggle_hl_groups = "i",
                    toggle_injected_languages = "t",
                    toggle_anonymous_nodes = "a",
                    toggle_language_display = "I",
                    focus_language = "f",
                    unfocus_language = "F",
                    update = "R",
                    goto_node = "<cr>",
                    show_help = "?",
                },
            },
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
                        ["[o"] = "@comment.outer",
                        ["[f"] = "@function.outer",
                    },
                    goto_next_start = {
                        ["],"] = "@parameter.inner",
                        ["]o"] = "@comment.outer",
                        ["]f"] = "@function.outer",
                    },
                },
                swap = {
                    enable = true,
                    swap_previous = {
                        ["<leader>[,"] = "@parameter.inner",
                    },
                    swap_next = {
                        ["<leader>],"] = "@parameter.inner",
                    },
                },
            },
        })
    end,
}

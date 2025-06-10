return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    -- TODO: This will be replaced by a new version. Holding for now because it is not
    -- compatible with text objects
    branch = "master",
    dependencies = {
        "nvim-treesitter/nvim-treesitter-textobjects",
    },
    config = function()
        local configs = require("nvim-treesitter.configs")

        -- Default keys are listed as required by the LSP
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
                "markdown_inline",
                "javascript",
                "html",
                "css",
                "rust",
                "sql",
                -- "c_sharp",
                "python",
                "json",
                "typescript",
                -- "dockerfile",
                "bash",
                -- "perl",
                "markdown",
                "go",
            },
            sync_install = false,
            highlight = { enable = true, additional_vim_regex_highlighting = false },
            indent = { enable = true },
            -- TODO: How can we define | | as a surround?
            textobjects = {
                select = {
                    enable = true,
                    lookahead = false, -- Don't jump to next text object
                    keymaps = {
                        ["a,"] = "@parameter.outer",
                        ["i,"] = "@parameter.inner",
                        ["af"] = "@function.outer",
                        ["if"] = "@function.inner",
                    },
                },
                move = {
                    enable = true,
                    set_jumps = true,
                    goto_previous_start = {
                        ["[,"] = "@parameter.inner",
                    },
                    goto_next_start = {
                        ["],"] = "@parameter.inner",
                    },
                },
                swap = {
                    enable = true,
                    swap_previous = { ["<leader>[,"] = "@parameter.inner" },
                    swap_next = { ["<leader>],"] = "@parameter.inner" },
                },
            },
        })
    end,
}

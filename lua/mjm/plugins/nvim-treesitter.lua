return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
        local configs = require("nvim-treesitter.configs")

        configs.setup({
            modules = {},
            ignore_install = {},
            auto_install = false,
            ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "elixir", "heex",
                "javascript", "html", "css", "rust", "sql", "c_sharp", "perl", "python",
                "json", "typescript", "dockerfile", "bash"
            },
            sync_install = false,
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = false,
            },
            indent = { enable = true },
            playground = {
                enable = true,
                disable = {},
                updatetime = 25,
                persist_queries = false,
                keybindings = {
                    toggle_query_editor = 'o',
                    toggle_hl_groups = 'i',
                    toggle_injected_languages = 't',
                    toggle_anonymous_nodes = 'a',
                    toggle_language_display = 'I',
                    focus_language = 'f',
                    unfocus_language = 'F',
                    update = 'R',
                    goto_node = '<cr>',
                    show_help = '?',
                },
            },
        })
    end
}
local function NvimTreeOnAttach(bufnr)
    local api = require("nvim-tree.api")

    api.config.mappings.default_on_attach(bufnr)

    vim.keymap.del("n", "<2-LeftMouse>", { buffer = bufnr })
    vim.keymap.del("n", "<2-RightMouse>", { buffer = bufnr })
end

return {
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        lazy = false,
        config = function ()
            local configs = require("nvim-treesitter.configs")

            configs.setup({
                modules = {},
                ignore_install = {},
                auto_install = false,
                ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "elixir", "heex",
                    "javascript", "html", "xml", "rust", "sql", "c_sharp", "perl", "python",
                    "json", "typescript"
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
    },
    {
        "nvim-tree/nvim-tree.lua",
        version = "*",
        lazy = false,
        dependencies = {
            "nvim-tree/nvim-web-devicons",
        },
        config = function()
            require("nvim-tree").setup {
                disable_netrw = true,
                hijack_netrw = true,

                hijack_unnamed_buffer_when_opening = false,

                sort_by = "case_sensitive",

                view = {
                    width = 35,
                    relativenumber = true,
                },

                renderer = {
                    group_empty = true,
                },

                filters = {
                    git_ignored = false,
                    dotfiles = false
                },

                diagnostics = {
                    enable = true,
                },

                on_attach = NvimTreeOnAttach
            }
        end,
    },
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.2', -- or branch = '0.1.x',
        dependencies = { 'nvim-lua/plenary.nvim' }
    },
    {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build ' ..
            '--config Release && cmake --install build --prefix build'
    },
    {
        'mbbill/undotree',
        lazy = false
    },
    {
        'tpope/vim-fugitive',
    },
    {
        'szw/vim-maximizer',
        config = function()
            vim.g.maximizer_set_default_mapping = 0
            vim.g.maximizer_set_mapping_with_bang = 0
        end,
    },
}

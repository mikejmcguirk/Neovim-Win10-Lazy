return {
    {
        'mbbill/undotree',
        lazy = false,
        config = function()
            vim.keymap.set("n", "<leader>ut", "<cmd>UndotreeToggle<cr>")
        end
    },
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.2', -- or branch = '0.1.x',
        dependencies = { 'nvim-lua/plenary.nvim' },
        config = function()
            local telescope = require('telescope')

            telescope.setup {
                defaults = {
                    mappings = {
                        n = {
                            ["<C-h>"] = "which_key",
                            ['<c-d>'] = require('telescope.actions').delete_buffer,
                            ['<up>'] = false,
                            ['<down>'] = false,
                            ['<left>'] = false,
                            ['<right>'] = false,
                            ['<PageUp>'] = false,
                            ['<PageDown>'] = false,
                            ['<Home>'] = false,
                            ['<End>'] = false,
                        },
                        i = {
                            ["<C-h>"] = "which_key",
                            ['<c-d>'] = require('telescope.actions').delete_buffer,
                            ['<up>'] = false,
                            ['<down>'] = false,
                            ['<left>'] = false,
                            ['<right>'] = false,
                            ['<PageUp>'] = false,
                            ['<PageDown>'] = false,
                            ['<Home>'] = false,
                            ['<End>'] = false,
                        }
                    }
                }
            }

            telescope.load_extension('fzf')
            telescope.load_extension('harpoon')

            local builtin = require("telescope.builtin")

            vim.keymap.set('n', '<leader>tb', function()
                builtin.buffers({ show_all_buffers = true })
            end)

            vim.keymap.set('n', '<leader>to', builtin.command_history)
            vim.keymap.set('n', '<leader>td', builtin.diagnostics)

            vim.keymap.set('n', '<leader>tf', function()
                builtin.find_files({ hidden = true, no_ignore = true })
            end)

            vim.keymap.set('n', '<leader>tg', builtin.git_files)

            vim.keymap.set('n', '<leader>ts', function()
                builtin.grep_string({ search = vim.fn.input("Grep > ") })
            end)

            vim.keymap.set('n', '<leader>ta', "<cmd>Telescope harpoon marks<cr>")
            vim.keymap.set('n', '<leader>th', builtin.help_tags)

            vim.keymap.set('n', '<leader>tl', function()
                builtin.grep_string({
                    prompt_title = "Help",
                    search = "",
                    search_dirs = vim.api.nvim_get_runtime_file("doc/*.txt", "all"),
                    only_sort_text = true,
                })
            end)

            vim.keymap.set('n', '<leader>tt', builtin.highlights)
            vim.keymap.set('n', '<leader>te', builtin.live_grep)
            vim.keymap.set('n', '<leader>tw', builtin.lsp_workspace_symbols)
            vim.keymap.set('n', '<leader>ti', builtin.registers)
            vim.keymap.set('n', '<leader>tr', builtin.resume)
        end
    },
    {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build ' ..
            '--config Release && cmake --install build --prefix build'
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

                on_attach = function(bufnr)
                    local api = require("nvim-tree.api")

                    api.config.mappings.default_on_attach(bufnr)

                    vim.keymap.del("n", "<2-LeftMouse>", { buffer = bufnr })
                    vim.keymap.del("n", "<2-RightMouse>", { buffer = bufnr })
                end,

                vim.keymap.set("n", "<leader>nt", "<cmd>NvimTreeToggle<cr>")
            }
        end,
    },
    {
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
                    "javascript", "html", "rust", "sql", "c_sharp", "perl", "python",
                    "json", "typescript", "dockerfile"
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
        'szw/vim-maximizer',
        config = function()
            vim.keymap.set("n", "<C-w>m", "<cmd>MaximizerToggle<cr>")
        end
    },
    {
        'tpope/vim-fugitive',
    },
}

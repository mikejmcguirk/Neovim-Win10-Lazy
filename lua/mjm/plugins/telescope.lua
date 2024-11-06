return {
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            -- {
            --     "nvim-telescope/telescope-fzf-native.nvim",
            --     build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build "
            --         .. "--config Release && cmake --install build --prefix build",
            --     cond = function()
            --         return vim.fn.executable("cmake") == 1
            --     end,
            -- },
            {
                "debugloop/telescope-undo.nvim",
                event = { "BufReadPre", "BufNewFile" },
            },
        },
        config = function()
            local telescope = require("telescope")
            local actions = require("telescope.actions")
            local undo_actions = require("telescope-undo.actions")
            -- telescope.load_extension("fzf")

            telescope.setup({
                defaults = {
                    mappings = {
                        n = {
                            ["<C-h>"] = "which_key",
                            ["<C-c>"] = actions.close,
                        },
                        i = {
                            ["<C-h>"] = "which_key",
                            ["<C-c>"] = false, --Reverts to default functionality
                            ["<esc>"] = actions.close,
                        },
                    },
                },
                pickers = {
                    buffers = {
                        mappings = {
                            n = {
                                ["dd"] = actions.delete_buffer,
                            },
                        },
                    },
                },
                extensions = {
                    undo = {
                        mappings = {
                            i = {
                                ["<cr>"] = undo_actions.yank_additions,
                                ["<C-y>"] = undo_actions.yank_deletions,
                                ["<C-r>"] = undo_actions.restore,
                            },
                            n = {
                                ["y"] = undo_actions.yank_additions,
                                ["Y"] = undo_actions.yank_deletions,
                                ["<cr>"] = undo_actions.restore,
                            },
                        },
                    },
                },
            })

            local builtin = require("telescope.builtin")

            vim.keymap.set("n", "<leader>tf", function()
                builtin.find_files({ hidden = true, no_ignore = true })
            end)
            vim.keymap.set("n", "<leader>tg", builtin.git_files)
            vim.keymap.set("n", "<leader>tb", function()
                builtin.buffers({ show_all_buffers = true })
            end)

            vim.keymap.set("n", "<leader>te", builtin.live_grep)
            vim.keymap.set("n", "<leader>ts", function()
                local ut = require("mjm.utils")
                local pattern = ut.get_user_input("Grep > ")
                if pattern == "" then
                    return
                end

                builtin.grep_string({ search = pattern })
            end)

            vim.keymap.set("n", "<leader>th", builtin.help_tags)
            vim.keymap.set("n", "<leader>tl", function()
                builtin.grep_string({
                    prompt_title = "Help",
                    search = "",
                    search_dirs = vim.api.nvim_get_runtime_file("doc/*.txt", true),
                    only_sort_text = true,
                })
            end)

            vim.keymap.set("n", "<leader>tt", builtin.highlights)
            vim.keymap.set("n", "<leader>tk", builtin.keymaps)

            vim.keymap.set("n", "<leader>to", builtin.command_history)
            vim.keymap.set("n", "<leader>ti", builtin.registers)
            telescope.load_extension("undo")
            vim.keymap.set("n", "<leader>tu", "<cmd>Telescope undo<cr>")

            vim.keymap.set("n", "<leader>td", builtin.diagnostics)
            vim.keymap.set("n", "<leader>tw", builtin.lsp_workspace_symbols)
            -- Disabled because of issue where picker tries to place cursor in an invalid position
            -- vim.keymap.set("n", "<leader>tq", builtin.quickfix)

            vim.keymap.set("n", "<leader>tr", builtin.resume)
        end,
    },
}

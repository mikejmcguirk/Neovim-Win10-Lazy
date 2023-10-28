return {
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = { "nvim-lua/plenary.nvim",
            {
                "nvim-telescope/telescope-fzf-native.nvim",
                build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build " ..
                    "--config Release && cmake --install build --prefix build",
                cond = function()
                    return vim.fn.executable("cmake") == 1
                end,
            },
        },
        config = function()
            local telescope = require("telescope")

            telescope.setup({
                defaults = {
                    mappings = {
                        n = {
                            ["<C-h>"] = "which_key",
                            ["<c-d>"] = require("telescope.actions").delete_buffer,
                            ["<C-c>"] = require("telescope.actions").close,
                            ["<esc>"] = false,
                            ["<up>"] = false,
                            ["<down>"] = false,
                            ["<left>"] = false,
                            ["<right>"] = false,
                            ["<PageUp>"] = false,
                            ["<PageDown>"] = false,
                            ["<Home>"] = false,
                            ["<End>"] = false,
                        },
                        i = {
                            ["<C-h>"] = "which_key",
                            ["<c-d>"] = require("telescope.actions").delete_buffer,
                            ["<C-c>"] = false,
                            ["<up>"] = false,
                            ["<down>"] = false,
                            ["<left>"] = false,
                            ["<right>"] = false,
                            ["<PageUp>"] = false,
                            ["<PageDown>"] = false,
                            ["<Home>"] = false,
                            ["<End>"] = false,
                        }
                    }
                }
            })

            telescope.load_extension("fzf")
            telescope.load_extension("harpoon")

            local builtin = require("telescope.builtin")

            vim.keymap.set("n", "<leader>tb", function()
                builtin.buffers({ show_all_buffers = true })
            end)

            vim.keymap.set("n", "<leader>to", builtin.command_history)
            vim.keymap.set("n", "<leader>td", builtin.diagnostics)

            vim.keymap.set("n", "<leader>tf", function()
                builtin.find_files({ hidden = true, no_ignore = true })
            end)

            vim.keymap.set("n", "<leader>tg", builtin.git_files)

            vim.keymap.set("n", "<leader>ts", function()
                builtin.grep_string({ search = vim.fn.input("Grep > ") })
            end)

            vim.keymap.set("n", "<leader>ta", "<cmd>Telescope harpoon marks<cr>")
            vim.keymap.set("n", "<leader>th", builtin.help_tags)

            vim.keymap.set("n", "<leader>tl", function()
                builtin.grep_string({
                    prompt_title = "Help",
                    search = "",
                    search_dirs = vim.api.nvim_get_runtime_file("doc/*.txt", "all"),
                    only_sort_text = true,
                })
            end)

            vim.keymap.set("n", "<leader>tt", builtin.highlights)
            vim.keymap.set("n", "<leader>te", builtin.live_grep)
            vim.keymap.set("n", "<leader>tw", builtin.lsp_workspace_symbols)
            vim.keymap.set("n", "<leader>tq", builtin.quickfix)
            vim.keymap.set("n", "<leader>ti", builtin.registers)
            vim.keymap.set("n", "<leader>tr", builtin.resume)
        end
    },
}

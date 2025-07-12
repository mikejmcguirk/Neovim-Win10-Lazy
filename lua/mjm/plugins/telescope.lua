-- TODO: https://github.com/ibhagwan/fzf-lua
-- Give this a try

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

            telescope.setup({
                defaults = {
                    mappings = {
                        n = {
                            ["<C-w>"] = "which_key",
                            ["<C-c>"] = actions.close,
                        },
                        i = {
                            ["<C-w>"] = "which_key",
                            ["<C-c>"] = false, --Reverts to default functionality
                            ["<esc>"] = actions.close,
                        },
                    },
                },
            })

            -- vim.keymap.set("n", "<leader>tl", function()
            --     builtin.grep_string({
            --         prompt_title = "Help",
            --         search = "",
            --         search_dirs = vim.api.nvim_get_runtime_file("doc/*.txt", true),
            --         only_sort_text = true,
            --     })
            -- end)
            --
            -- vim.keymap.set("n", "<leader>to", builtin.command_history)
        end,
    },
}

return {
    {
        "nvim-tree/nvim-tree.lua",
        version = "*",
        lazy = false,
        dependencies = {
            "nvim-tree/nvim-web-devicons",
        },
        config = function()
            require("nvim-tree").setup({
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
                    dotfiles = false,
                },
                diagnostics = {
                    enable = true,
                },
                notify = {
                    threshold = vim.log.levels.WARN,
                    absolute_path = true,
                },
                on_attach = function(bufnr)
                    local api = require("nvim-tree.api")

                    api.config.mappings.default_on_attach(bufnr)

                    vim.keymap.del("n", "<2-LeftMouse>", { buffer = bufnr })
                    vim.keymap.del("n", "<2-RightMouse>", { buffer = bufnr })
                end,
            })

            vim.keymap.set("n", "<leader>nt", "<cmd>NvimTreeToggle<cr>")
        end,
    },
}

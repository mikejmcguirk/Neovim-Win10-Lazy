-- FUTURE: https://github.com/MariaSolOs/dotfiles/blob/main/.config/nvim/lua/statusline.lua
-- Code for adding an LSP progress module is in here

return {
    {
        "nvim-lualine/lualine.nvim",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
            "ThePrimeagen/harpoon", -- For harpoon tab info
            "mike-jl/harpoonEx",
            "linrongbin16/lsp-progress.nvim",
        },
        config = function()
            local theme = "fluoromachine"

            require("lsp-progress").setup()
            vim.api.nvim_create_augroup("lualine_augroup", { clear = true })
            vim.api.nvim_create_autocmd("User", {
                group = "lualine_augroup",
                pattern = "LspProgressStatusUpdated",
                callback = require("lualine").refresh,
            })

            require("lualine").setup({
                options = {
                    component_separators = { left = "", right = "" },
                    section_separators = { left = "", right = "" },
                    theme = theme,
                },
                sections = {
                    lualine_a = { "branch", "diff" },
                    -- :help statusline
                    lualine_b = { "%m %f" },
                    lualine_c = {
                        "diagnostics",
                        function()
                            return require("lsp-progress").progress()
                        end,
                    },
                    lualine_x = { "encoding", "fileformat", "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = { "%l/%L : %c : %o" },
                },
                inactive_sections = {
                    lualine_a = {},
                    lualine_b = { "%m %f" },
                    lualine_c = { "diagnostics" },
                    lualine_x = { "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = {},
                },
                tabline = {
                    lualine_a = {
                        {
                            "harpoons",
                            separator = nil, -- Must explicitly specify
                            padding = 1,

                            show_filename_only = true,
                            hide_filename_extension = false,
                            show_modified_status = true,

                            mode = 2,

                            max_length = vim.o.columns,

                            harpoons_color = {
                                active = "lualine_b_normal",
                                inactive = "lualine_a_normal",
                            },

                            symbols = {
                                modified = "[+]",
                                alternate_file = "",
                                directory = "",
                            },
                        },
                    },
                    lualine_z = {
                        {
                            "tabs",
                            tabs_color = {
                                active = "lualine_b_normal",
                                inactive = "lualine_a_normal",
                            },
                        },
                    },
                },
            })

            local normal_a = vim.api.nvim_get_hl(0, { name = "lualine_a_normal" })
            local new_normal_a = vim.tbl_extend("force", normal_a, { bold = false })
            vim.api.nvim_set_hl(0, "lualine_a_normal", new_normal_a)
        end,
    },
}

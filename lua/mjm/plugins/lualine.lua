return {
    {
        "nvim-lualine/lualine.nvim",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
            "ThePrimeagen/harpoon", -- For harpoon tab info
            "mike-jl/harpoonEx",
            -- "mikejmcguirk/harpoonEx",
        },
        config = function()
            local theme

            if Env_Theme == "blue" then
                local c = {
                    fg = "#EFEFFD",
                    alt_bg = "#2f3f4d",
                    comment = "#3c778c",
                    orange = "#FF98B3",
                    purple = "#FFB924",
                    red = "#6CF3CA",
                }
                local f_utils = require("fluoromachine.utils")
                local darken = f_utils.darken
                local custom_auto = require("lualine.themes.auto")

                -- TODO: Should be turned into some kind of global
                custom_auto.normal.a.bg = c.alt_bg
                custom_auto.normal.a.fg = c.fg
                custom_auto.normal.a.gui = "bold"
                custom_auto.normal.b.bg = c.comment
                custom_auto.normal.b.fg = c.fg
                custom_auto.normal.c.bg = c.alt_bg
                custom_auto.normal.c.fg = c.fg

                custom_auto.visual.a.bg = darken(c.red, 75)
                custom_auto.visual.a.fg = c.fg
                custom_auto.visual.a.gui = "bold"
                custom_auto.visual.b.bg = darken(c.red, 50)
                custom_auto.visual.b.fg = c.fg

                custom_auto.command.a.bg = darken(c.purple, 75)
                custom_auto.command.a.fg = c.fg
                custom_auto.command.a.gui = "bold"
                custom_auto.command.b.bg = darken(c.purple, 50)
                custom_auto.command.b.fg = c.fg

                custom_auto.replace.a.bg = darken(c.orange, 75)
                custom_auto.replace.a.fg = c.fg
                custom_auto.replace.a.gui = "bold"
                custom_auto.replace.b.bg = darken(c.orange, 50)
                custom_auto.replace.b.fg = c.fg

                theme = custom_auto
            else
                theme = "fluoromachine"
            end

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
                    lualine_c = { "diagnostics" },
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

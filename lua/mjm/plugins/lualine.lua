return {
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        lazy = false,
        priority = 996,
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
                sections = {
                    lualine_a = { "branch" },
                    -- :help statusline
                    lualine_b = { "%m %F" },
                    lualine_c = { "diagnostics" },
                    lualine_x = { "encoding", "fileformat", "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = { "%l/%L : %c : %o" },
                },
                inactive_sections = {
                    lualine_a = {},
                    lualine_b = { "%m %F" },
                    lualine_c = { "diagnostics" },
                    lualine_x = { "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = {},
                },
                options = {
                    section_separators = { "", "" },
                    component_separators = { "", "" },
                    theme = theme,
                },
            })
        end,
    },
}

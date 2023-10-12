return {
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        lazy = false,
        priority = 996,
        config = function()
            local theme

            if Env_Theme == "blue" then
                local old_auto = require 'lualine.themes.auto'
                local custom_auto = require 'lualine.themes.auto'

                local old_auto_visual_a_bg = old_auto.visual.a.bg
                local old_auto_visual_b_bg = old_auto.visual.b.bg
                -- local old_auto_visual_c_bg = old_auto.visual.c.bg

                local old_auto_normal_a_bg = old_auto.normal.a.bg
                local old_auto_normal_b_bg = old_auto.normal.b.bg
                -- local old_auto_normal_c_bg = old_auto.normal.c.bg

                local old_auto_visual_a_fg = old_auto.visual.a.fg
                local old_auto_visual_b_fg = old_auto.visual.b.fg
                -- local olllluto_visual_c_fg = old_auto.visual.c.fg

                local old_auto_normal_a_fg = old_auto.normal.a.fg
                local old_auto_normal_b_fg = old_auto.normal.b.fg
                -- local old_auto_normal_c_fg = old_auto.normal.c.fg

                custom_auto.visual.a.bg = old_auto_normal_a_bg
                custom_auto.visual.b.bg = old_auto_normal_b_bg
                --custom_auto.visual.c.bg = old_auto_normal_c_bg

                custom_auto.normal.a.bg = old_auto_visual_a_bg
                custom_auto.normal.b.bg = old_auto_visual_b_bg
                --custom_auto.normal.c.bg = old_auto_visual_c_bg

                custom_auto.visual.a.fg = old_auto_normal_a_fg
                custom_auto.visual.b.fg = old_auto_normal_b_fg
                --custom_auto.visual.c.fg = old_auto_normal_c_fg

                custom_auto.normal.a.fg = old_auto_visual_a_fg
                custom_auto.normal.b.fg = old_auto_visual_b_fg

                theme = custom_auto
            elseif Env_Theme == "green" then
                theme = "zenburn"
            else
                theme = "fluoromachine"
            end

            require('lualine').setup {
                sections = {
                    lualine_a = { 'branch' },
                    lualine_b = { '%h %F %m' },
                    lualine_c = { 'diagnostics' },
                    lualine_x = { 'encoding', 'fileformat', 'filetype' },
                    lualine_y = { 'progress' },
                    lualine_z = { '%l/%L : %c : %o' }
                },
                inactive_sections = {
                    lualine_a = {},
                    lualine_b = { 'filename' },
                    lualine_c = { 'diagnostics' },
                    lualine_x = { 'filetype' },
                    lualine_y = { 'progress' },
                    lualine_z = {}
                },
                options = {
                    -- section_separators = { '', '' },
                    -- component_separators = { '', '' },
                    section_separators = { '', '' },
                    component_separators = { '', '' },
                    theme = theme
                },
            }
        end
    },
}

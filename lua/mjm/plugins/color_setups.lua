return {
    {
        "maxmx03/fluoromachine.nvim",
        lazy = false, -- Does not work with lazy loading
        priority = 1000, -- Still must be top priority for colors to properly load
        config = function()
            local fm = require "fluoromachine"

            fm.setup {
                glow = false,
                brightness = 0.05,
                theme = "delta",
                transparent = true,
            }

            vim.cmd.colorscheme "fluoromachine"

            vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
            vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })

            vim.api.nvim_set_hl(
                0,
                "Cursorline",
                {bg = vim.api.nvim_get_hl(0, {name = "ColorColumn"}).bg}
            )
        end
    },
    {
        "ThePrimeagen/harpoon",
        lazy = false,
        priority = 999,
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("harpoon").setup({
                tabline = true,
                tabline_prefix = "   ",
                tabline_suffix = "   ",

                save_on_change = true
            })

            vim.api.nvim_set_hl(0,
                "HarpoonInactive", {
                    fg = vim.api.nvim_get_hl(0, {name = "String"}).fg,
                    bg = vim.api.nvim_get_hl(0, {name = "ColorColumn"}).bg
                }
            )
            vim.api.nvim_set_hl(0,
                "HarpoonNumberInactive", {
                    fg = vim.api.nvim_get_hl(0, {name = "Type"}).fg,
                    bg = vim.api.nvim_get_hl(0, {name = "ColorColumn"}).bg
                }
            )
            vim.api.nvim_set_hl(0,
                "HarpoonActive", {
                    fg = vim.api.nvim_get_hl(0, {name = "String"}).fg,
                    bg = "#6A4C7F"
                }
            )
            vim.api.nvim_set_hl(0,
                "HarpoonNumberActive", {
                    fg = vim.api.nvim_get_hl(0, {name = "Type"}).fg,
                    bg = "#6A4C7F"
                }
            )
            vim.api.nvim_set_hl(0,
                "TabLineFill", {
                    fg = vim.api.nvim_get_hl(0, {name = "String"}).fg,
                    bg = vim.api.nvim_get_hl(0, {name = "ColorColumn"}).bg
                }
            )
        end
    },
    {
        "unblevable/quick-scope",
        lazy = false,
        priority = 998,
        config = function()
            vim.api.nvim_set_hl(0, "QuickScopePrimary",
                { bg="#98FFFB", fg="#000000", ctermbg=14, ctermfg=0 })
            vim.api.nvim_set_hl(0, "QuickScopeSecondary",
                { bg="#FF67D4", fg="#000000", ctermbg=207, ctermfg=0 })
            --Alternative Yellow Quickscope highlight color: #EDFF98, cterm fg 226
        end,
    },
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        lazy = false,
        priority = 997,
        config = function()
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
                    theme = 'fluoromachine'
                },
            }
        end
    },

}

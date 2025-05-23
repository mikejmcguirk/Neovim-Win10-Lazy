-- TODO: Use Zenburn again as a green theme?
return {
    {
        "maxmx03/fluoromachine.nvim",
        lazy = false, -- Does not work with lazy loading
        priority = 1000, -- Set top priority so highlight groups load
        commit = "a5dc2cd", -- TODO: Feels like this will break eventually. Better solution?
        config = function()
            local fm = require("fluoromachine")

            if Env_Theme == "blue" then
                fm.setup({
                    glow = false,
                    brightness = 0.05,
                    theme = "delta",
                    transparent = true,
                    colors = function(_, d)
                        return {
                            fg = "#EFEFFD",
                            bg = "#2f3f4d",
                            alt_bg = "#2f3f4d",
                            currentline = "#2f3f4d",
                            selection = "#3d5161",
                            comment = "#3c778c",
                            cyan = "#94F96E",
                            green = "#EDFF98",
                            yellow = "#DC75EA",
                            orange = "#FF98B3",
                            pink = "#6FE1FB",
                            purple = "#FFB924",
                            red = "#6CF3CA",
                            cursor_fg = "#2f3f4d",
                            cursor_bg = "#EFEFFD",
                            sign_add = "#94F96E",
                            sign_change = "#EDFF98",
                            sign_delete = "#FF98B3",
                            other = "#6FE1FB",
                            blankline = "#2f3f4d",
                            inlay_hint = "#94F96E",
                        }
                    end,
                })

                vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#6FE1FB" })
                vim.api.nvim_set_hl(
                    0,
                    "EolSpace",
                    { bg = "#94F96E", ctermbg = 10, fg = "#efeffd", ctermfg = 15 }
                )
            else
                fm.setup({
                    glow = false,
                    brightness = 0.05,
                    theme = "delta",
                    transparent = true,
                })

                vim.api.nvim_set_hl(
                    0,
                    "EolSpace",
                    { bg = "#ffd298", ctermbg = 14, fg = "#98fffb", ctermfg = 14 }
                )
            end

            vim.api.nvim_exec2("colorscheme fluoromachine", {})

            -- Still needed even with fluoromachine transparent = true
            vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })

            local old_float_border = vim.api.nvim_get_hl(0, { name = "FloatBorder" })
            local new_float_border = vim.tbl_extend("force", old_float_border, { bg = "none" })
            vim.api.nvim_set_hl(0, "FloatBorder", new_float_border)

            local old_win_border = vim.api.nvim_get_hl(0, { name = "WinSeparator" })
            local new_win_border = vim.tbl_extend("force", old_win_border, { bg = "none" })
            vim.api.nvim_set_hl(0, "WinSeparator", new_win_border)

            vim.api.nvim_set_hl(
                0,
                "Cursorline",
                { bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg }
            )

            local diag_text_groups = {
                ["DiagnosticError"] = "DiagnosticUnderlineError",
                ["DiagnosticWarn"] = "DiagnosticUnderlineWarn",
                ["DiagnosticInfo"] = "DiagnosticUnderlineInfo",
                ["DiagnosticHint"] = "DiagnosticUnderlineHint",
                ["DiagnosticOk"] = "DiagnosticUnderlineOk",
            }

            for base, uline in pairs(diag_text_groups) do
                local old = vim.api.nvim_get_hl(0, { name = uline })
                local new = vim.tbl_extend("force", old, {
                    fg = vim.api.nvim_get_hl(0, { name = base }).fg,
                    underline = true,
                })
                vim.api.nvim_set_hl(0, uline, new)
            end
        end,
    },
}

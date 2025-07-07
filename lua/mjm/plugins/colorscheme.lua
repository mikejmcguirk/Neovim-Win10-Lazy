return {
    {
        "maxmx03/fluoromachine.nvim",
        lazy = false, -- Does not work with lazy loading
        priority = 1000, -- Set top priority so highlight groups load
        commit = "a5dc2cd", -- TODO: Feels like this will break eventually. Better solution?
        config = function()
            local fm = require("fluoromachine")
            fm.setup({
                glow = false,
                brightness = 0.05,
                theme = "delta",
                transparent = true,
            })

            vim.api.nvim_exec2("colorscheme fluoromachine", {})
            vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
            local old_float_border = vim.api.nvim_get_hl(0, { name = "FloatBorder" })
            local new_float_border = vim.tbl_extend("force", old_float_border, { bg = "none" })
            vim.api.nvim_set_hl(0, "FloatBorder", new_float_border)
            local old_win_border = vim.api.nvim_get_hl(0, { name = "WinSeparator" })
            local new_win_border = vim.tbl_extend("force", old_win_border, { bg = "none" })
            vim.api.nvim_set_hl(0, "WinSeparator", new_win_border)

            vim.api.nvim_set_hl(
                0,
                "EolSpace",
                { bg = "#ffd298", ctermbg = 14, fg = "#98fffb", ctermfg = 14 }
            )

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

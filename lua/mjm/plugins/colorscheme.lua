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

            vim.cmd("colorscheme fluoromachine")

            vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })

            local old_float_border = vim.api.nvim_get_hl(0, { name = "FloatBorder" })
            local new_float_border = vim.tbl_extend("force", old_float_border, { bg = "none" })
            vim.api.nvim_set_hl(0, "FloatBorder", new_float_border)

            local old_win_border = vim.api.nvim_get_hl(0, { name = "WinSeparator" })
            local new_win_border = vim.tbl_extend("force", old_win_border, { bg = "none" })
            vim.api.nvim_set_hl(0, "WinSeparator", new_win_border)

            local number_hl = vim.api.nvim_get_hl(0, { name = "Number" })
            local cur_search = vim.api.nvim_get_hl(0, { name = "CurSearch" })
            vim.api.nvim_set_hl(0, "EolSpace", { bg = cur_search.bg, fg = number_hl.fg })

            local color_col = vim.api.nvim_get_hl(0, { name = "ColorColumn" })
            vim.api.nvim_set_hl(0, "Cursorline", { bg = color_col.bg })

            local diag_text_groups = {
                ["DiagnosticError"] = "DiagnosticUnderlineError",
                ["DiagnosticWarn"] = "DiagnosticUnderlineWarn",
                ["DiagnosticInfo"] = "DiagnosticUnderlineInfo",
                ["DiagnosticHint"] = "DiagnosticUnderlineHint",
                ["DiagnosticOk"] = "DiagnosticUnderlineOk",
            }

            for base, uline in pairs(diag_text_groups) do
                local old = vim.api.nvim_get_hl(0, { name = uline })
                local new_fg = vim.api.nvim_get_hl(0, { name = base }).fg
                local new = vim.tbl_extend("force", old, { fg = new_fg, underline = true })

                vim.api.nvim_set_hl(0, uline, new)
            end
        end,
    },
}

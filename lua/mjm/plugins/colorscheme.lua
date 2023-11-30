return {
    {
        "maxmx03/fluoromachine.nvim",
        lazy = false, -- Does not work with lazy loading
        priority = 1000, -- Set top priority so highlight groups load
    },
    {
        "phha/zenburn.nvim",
        lazy = false,
        priority = 999,
        config = function()
            local fm = require("fluoromachine")

            if Env_Theme == "blue" then
                local function overrides(c)
                    return {
                        --Keywords (cyan)

                        ["@keyword"] = { fg = c.cyan },
                        ["@include"] = { fg = c.cyan },
                        ["@tag"] = { fg = c.cyan },
                        ["@function.macro"] = { fg = c.cyan },

                        --Variable Types (purple)

                        ["@type"] = { fg = c.purple },
                        ["@type.builtin"] = { fg = c.purple },

                        ["@variable.lua"] = { fg = c.purple },
                        ["@parameter.lua"] = { fg = c.purple },

                        --Variable names (white/fg)

                        ["@variable.builtin"] = { fg = c.fg },
                        ["@parameter"] = { fg = c.fg },
                        ["@field"] = { fg = c.fg },

                        ["@field.sql"] = { fg = c.fg },

                        --Function Calls (Yellow)

                        ["@function"] = { fg = c.yellow },
                        ["@function.call"] = { fg = c.yellow },
                        ["@constructor"] = { fg = c.yellow },
                        ["@tag.attribute"] = { fg = c.yellow },

                        --Strings & Chars (orange)

                        --Number and boolean literals (red, playing neon green)

                        ["@number"] = { fg = c.red },
                        ["@float"] = { fg = c.red },
                        ["@boolean"] = { fg = c.red },

                        --Operators (pink)

                        ["@operator"] = { fg = c.pink },
                        ["@keyword.operator"] = { fg = c.pink },
                        ["xmlEqual"] = { fg = c.pink },

                        --Brackets, Braces, and Control Flow (green)

                        ["@punctuation.bracket"] = { fg = c.green },
                        ["@punctuation.delimiter"] = { fg = c.green },
                        ["@punctuation.special"] = { fg = c.green },
                        ["@keyword.return"] = { fg = c.green },
                        ["@tag.delimiter"] = { fg = c.green },

                        ["@constructor.lua"] = { fg = c.green },
                    }
                end

                fm.setup({
                    glow = false,
                    brightness = 0.05,
                    theme = "retrowave",
                    transparent = true,
                    colors = function(_, d)
                        return {
                            comment = "#3c778c",
                            yellow = "#ffee00",
                            purple = "#f03ea9",
                            pink = "#f17294",
                            alt_bg = "#2f3f4d",
                            currentline = "#2f3f4d",
                            selection = "#3d5161",
                            orange = "#fc7703",
                            red = "#05ed62", --Turn to neon green
                        }
                    end,

                    overrides = overrides,
                })

                vim.cmd.colorscheme("fluoromachine")
            elseif Env_Theme == "green" then
                require("zenburn").setup()

                vim.cmd.colorscheme("zenburn")
            else
                fm.setup({
                    glow = false,
                    brightness = 0.05,
                    theme = "delta",
                    transparent = true,
                })

                vim.cmd.colorscheme("fluoromachine")
            end

            if Env_Theme == "green" then
                vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
                vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
            end
            -- Still needed even with fluoromachine transparent = true
            vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })

            vim.api.nvim_set_hl(
                0,
                "Cursorline",
                { bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg }
            )

            -- vim.api.nvim_set_hl(0, "Whitespace", "ColorColumn")

            if Env_Theme == "blue" then
                vim.api.nvim_set_hl(0, "@lsp.type.function", {})
                for _, group in ipairs(vim.fn.getcompletion("@lsp", "highlight")) do
                    vim.api.nvim_set_hl(0, group, {})
                end
            end
        end,
    },
}

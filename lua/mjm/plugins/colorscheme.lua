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
                            green = "#DC75EA",
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

                vim.api.nvim_exec2("colorscheme fluoromachine", {})
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

                vim.api.nvim_exec2("colorscheme fluoromachine", {})

                vim.api.nvim_set_hl(
                    0,
                    "EolSpace",
                    { bg = "#ffd298", ctermbg = 14, fg = "#98fffb", ctermfg = 14 }
                )
            end

            vim.cmd([[match EolSpace /\s\+$/]])

            -- Still needed even with fluoromachine transparent = true
            vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
            vim.api.nvim_set_hl(
                0,
                "Cursorline",
                { bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg }
            )

            local match_control = vim.api.nvim_create_augroup("match_control", { clear = true })
            local get_match_id = function(match_group)
                for _, match in ipairs(vim.fn.getmatches()) do
                    if match.group == match_group then
                        return match.id
                    end
                end
            end

            vim.api.nvim_create_autocmd("InsertEnter", {
                group = match_control,
                pattern = "*",
                callback = function()
                    local match_id = get_match_id("EolSpace")
                    if not match_id then
                        return
                    end

                    vim.fn.matchdelete(match_id)
                end,
            })
            vim.api.nvim_create_autocmd("InsertLeave", {
                group = match_control,
                pattern = "*",
                callback = function()
                    if vim.bo.filetype ~= "TelescopePrompt" then
                        vim.cmd([[match EolSpace /\s\+$/]])
                    end
                end,
            })
        end,
    },
}

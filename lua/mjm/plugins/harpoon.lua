return {
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim", "jasonpanosso/harpoon-tabline.nvim" },
        config = function()
            local harpoon = require("harpoon")

            harpoon:setup({
                settings = {
                    save_on_toggle = true,
                    sync_on_ui_close = true,
                },
            })

            vim.keymap.set("n", "<leader>ad", function()
                harpoon:list():add()
            end)
            vim.keymap.set("n", "<leader>ar", "<nop>")
            -- Breaks Harpoon list if not run on last file
            -- vim.keymap.set("n", "<leader>ar", function()
            --     harpoon:list():remove()
            -- end)
            vim.keymap.set("n", "<leader>ae", function()
                harpoon.ui:toggle_quick_menu(harpoon:list())
            end)

            for i = 1, 9 do
                vim.keymap.set("n", string.format("<leader>%s", i), function()
                    if vim.bo.filetype == "qf" then
                        print("Currently in quickfix list")

                        return
                    end

                    harpoon:list():select(i)
                end)
            end

            require("harpoon-tabline").setup({
                use_editor_color_scheme = false,
                tab_prefix = "  ",
                tab_suffix = "  ",
            })

            if Env_Theme == "blue" then
                vim.api.nvim_set_hl(0, "HarpoonInactive", {
                    fg = vim.api.nvim_get_hl(0, { name = "CursorLineNr" }).fg,
                    bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
                })
                vim.api.nvim_set_hl(0, "HarpoonNumberInactive", {
                    fg = "#ffee00",
                    bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
                })
                vim.api.nvim_set_hl(0, "HarpoonActive", {
                    fg = vim.api.nvim_get_hl(0, { name = "CursorLineNr" }).fg,
                    bg = "#30717F",
                })
                vim.api.nvim_set_hl(0, "HarpoonNumberActive", {
                    fg = "#ffee00",
                    bg = "#30717F",
                })
                vim.api.nvim_set_hl(0, "TabLineFill", {
                    fg = vim.api.nvim_get_hl(0, { name = "CursorLineNr" }).fg,
                    bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
                })
            elseif Env_Theme == "green" then
                vim.api.nvim_set_hl(0, "HarpoonActive", {
                    fg = vim.api.nvim_get_hl(0, { name = "DevIconEditorConfig" }).fg,
                    bg = "#5D6262",
                })
                vim.api.nvim_set_hl(0, "HarpoonNumberActive", {
                    fg = vim.api.nvim_get_hl(0, { name = "DevIconEditorConfig" }).fg,
                    bg = "#5D6262",
                })
            else
                vim.api.nvim_set_hl(0, "HarpoonInactive", {
                    fg = vim.api.nvim_get_hl(0, { name = "String" }).fg,
                    bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
                })
                vim.api.nvim_set_hl(0, "HarpoonNumberInactive", {
                    fg = vim.api.nvim_get_hl(0, { name = "Type" }).fg,
                    bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
                })
                vim.api.nvim_set_hl(0, "HarpoonActive", {
                    fg = vim.api.nvim_get_hl(0, { name = "String" }).fg,
                    bg = "#6A4C7F",
                })
                vim.api.nvim_set_hl(0, "HarpoonNumberActive", {
                    fg = vim.api.nvim_get_hl(0, { name = "Type" }).fg,
                    bg = "#6A4C7F",
                })
                vim.api.nvim_set_hl(0, "TabLineFill", {
                    fg = vim.api.nvim_get_hl(0, { name = "String" }).fg,
                    bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
                })
            end
        end,
    },
}

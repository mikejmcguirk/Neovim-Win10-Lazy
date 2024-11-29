return {
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = {
            "nvim-lua/plenary.nvim",
            -- "jasonpanosso/harpoon-tabline.nvim",
            "mike-jl/harpoonEx",
            -- "mikejmcguirk/harpoonEx",
        },
        config = function()
            local harpoon = require("harpoon")

            harpoon:setup({
                settings = {
                    save_on_toggle = true,
                    sync_on_ui_close = true,
                    menu = {
                        height = 10,
                    },
                },
            })

            vim.keymap.set("n", "<leader>ad", function()
                harpoon:list():add()
            end)
            vim.keymap.set("n", "<leader>ae", function()
                harpoon.ui:toggle_quick_menu(harpoon:list(), { height_in_lines = 10 })
            end)

            -- TODO: The way this is written is redundant
            for i = 1, 9 do
                vim.keymap.set("n", string.format("<leader>%s", i), function()
                    if vim.bo.filetype == "qf" then
                        print("Currently in quickfix list")
                        return
                    end

                    harpoon:list():select(i)
                end)
            end
            vim.keymap.set("n", string.format("<leader>%s", 0), function()
                if vim.bo.filetype == "qf" then
                    print("Currently in quickfix list")
                    return
                end

                harpoon:list():select(10)
            end)

            local harpoonEx = require("harpoonEx")
            local extensions = require("harpoon.extensions")
            harpoon:extend(extensions.builtins.navigate_with_number())
            harpoon:extend(harpoonEx.extend())

            vim.keymap.set("n", "<leader>ar", function()
                harpoonEx.delete(harpoon:list())
            end, { desc = "Delete current file from Harpoon List" })

            -- require("harpoon-tabline").setup({
            --     use_editor_color_scheme = false,
            --     tab_prefix = "  ",
            --     tab_suffix = "  ",
            -- })

            -- -- TODO: Should be a global
            -- local c = {
            --     fg = "#EFEFFD",
            --     comment = "#3c778c",
            --     yellow = "#EDFF98",
            -- }
            --
            -- if Env_Theme == "blue" then
            --     vim.api.nvim_set_hl(0, "HarpoonInactive", {
            --         fg = c.fg,
            --         bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
            --     })
            --     vim.api.nvim_set_hl(0, "HarpoonNumberInactive", {
            --         fg = c.yellow,
            --         bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
            --     })
            --     vim.api.nvim_set_hl(0, "HarpoonActive", {
            --         fg = c.fg,
            --         bg = c.comment,
            --     })
            --     vim.api.nvim_set_hl(0, "HarpoonNumberActive", {
            --         fg = c.yellow,
            --         bg = c.comment,
            --     })
            --     vim.api.nvim_set_hl(0, "TabLineFill", {
            --         fg = vim.api.nvim_get_hl(0, { name = "CursorLineNr" }).fg,
            --         bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
            --     })
            -- else
            --     vim.api.nvim_set_hl(0, "HarpoonInactive", {
            --         fg = vim.api.nvim_get_hl(0, { name = "String" }).fg,
            --         bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
            --     })
            --     vim.api.nvim_set_hl(0, "HarpoonNumberInactive", {
            --         fg = vim.api.nvim_get_hl(0, { name = "Type" }).fg,
            --         bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
            --     })
            --     vim.api.nvim_set_hl(0, "HarpoonActive", {
            --         fg = vim.api.nvim_get_hl(0, { name = "String" }).fg,
            --         bg = "#6A4C7F",
            --     })
            --     vim.api.nvim_set_hl(0, "HarpoonNumberActive", {
            --         fg = vim.api.nvim_get_hl(0, { name = "Type" }).fg,
            --         bg = "#6A4C7F",
            --     })
            --     vim.api.nvim_set_hl(0, "TabLineFill", {
            --         fg = vim.api.nvim_get_hl(0, { name = "String" }).fg,
            --         bg = vim.api.nvim_get_hl(0, { name = "ColorColumn" }).bg,
            --     })
            -- end
        end,
    },
}

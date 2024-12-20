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
            local logger = require("harpoon.logger")
            local extensions = require("harpoon.extensions")

            harpoon:setup({
                settings = {
                    save_on_toggle = true,
                    sync_on_ui_close = true,
                    menu = {
                        height = 10,
                    },
                },
                default = {
                    -- When using the in-build select function, ftplugin settings fail to load
                    -- Issue does not occur if we use edit instead
                    select = function(list_item, list, options)
                        logger:log("config_default#select", list_item, list.name, options)
                        if list_item == nil then
                            return
                        end

                        local bufnr = vim.fn.bufnr(list_item.value)
                        if vim.api.nvim_get_current_buf() == bufnr then
                            vim.notify("Already in buffer")
                            return
                        end

                        local set_position = false
                        if bufnr == -1 then
                            set_position = true
                        end

                        options = options or {}
                        if options.vsplit then
                            vim.cmd("vsplit")
                        elseif options.split then
                            vim.cmd("split")
                        elseif options.tabedit then
                            vim.cmd("tabedit")
                        end

                        vim.api.nvim_exec2("edit " .. list_item.value, {})
                        bufnr = vim.fn.bufnr(list_item.value)

                        if set_position then
                            local lines = vim.api.nvim_buf_line_count(bufnr)

                            local edited = false
                            if list_item.context.row > lines then
                                list_item.context.row = lines
                                edited = true
                            end

                            local row = list_item.context.row
                            local row_text = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
                            local col = #row_text[1]

                            if list_item.context.col > col then
                                list_item.context.col = col
                                edited = true
                            end

                            vim.api.nvim_win_set_cursor(0, {
                                list_item.context.row or 1,
                                list_item.context.col or 0,
                            })

                            if edited then
                                extensions.extensions:emit(
                                    extensions.event_names.POSITION_UPDATED,
                                    {
                                        list_item = list_item,
                                    }
                                )
                            end
                        end

                        extensions.extensions:emit(extensions.event_names.NAVIGATE, {
                            buffer = bufnr,
                        })
                    end,
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

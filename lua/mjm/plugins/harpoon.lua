return {
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "mike-jl/harpoonEx",
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
                    -- When using the built-in select function, ftplugin settings fail to load
                    -- Issue does not occur if we use edit instead of bufload
                    select = function(list_item, list, options)
                        logger:log("config_default#select", list_item, list.name, options)
                        if list_item == nil then
                            return
                        end

                        -- For some reason, the LSP does not recognize vim.uv
                        ---@diagnostic disable-next-line: undefined-field
                        if not vim.uv.fs_stat(list_item.value) then
                            vim.notify(
                                "File " .. list_item.value .. " Does not exist",
                                vim.log.levels.WARN
                            )
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

                        vim.cmd("edit " .. list_item.value)
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

            local mark = 10
            for _ = 1, 10 do
                -- Need to bring mark into this scope, or else final value of mark is
                -- used for all maps
                local this_mark = mark -- 10, 1, 2, 3, 4, 5, 6, 7, 8, 9
                local mod_mark = this_mark % 10 -- 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
                vim.keymap.set("n", string.format("<leader>%s", mod_mark), function()
                    if vim.bo.filetype == "qf" then
                        vim.notify("Currently in quickfix list", vim.log.levels.WARN)
                        return
                    end

                    harpoon:list():select(this_mark)
                end)

                mark = mod_mark + 1
            end

            local harpoonEx = require("harpoonEx")
            harpoon:extend(extensions.builtins.navigate_with_number())
            harpoon:extend(harpoonEx.extend())

            vim.keymap.set("n", "<leader>ar", function()
                harpoonEx.delete(harpoon:list())
            end, { desc = "Delete current file from Harpoon List" })
        end,
    },
}

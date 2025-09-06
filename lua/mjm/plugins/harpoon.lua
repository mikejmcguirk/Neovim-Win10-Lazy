local harpoon = require("harpoon")

-- NOTE: The navigation functionality has been removed from here. This should be done using the
-- " mark saved in the Shada file
harpoon:setup({
    settings = {
        save_on_toggle = true,
        sync_on_ui_close = true,
        menu = {
            height = 10,
        },
    },
    default = {
        -- The default select logic uses bufload(), which does not handle BufReadPost autocmds
        -- or opt_local context correctly. nvim_set_current_buf() without bufload handles the
        -- load step correctly if needed
        select = function(list_item, list, opts)
            local extensions = require("harpoon.extensions")
            require("harpoon.logger"):log("custom#select", list_item, list.name, opts)

            if not list_item then
                vim.notify("nil list_item")
                return
            end

            if not vim.uv.fs_stat(list_item.value) then
                vim.notify(list_item.value .. " not found", vim.log.levels.WARN)
                return
            end

            local buf = vim.fn.bufadd(list_item.value) --- @type integer
            if vim.api.nvim_get_current_buf() == buf then
                vim.notify("Already in buffer")
                return
            end

            opts = opts or {}
            if opts.vsplit then
                vim.api.nvim_cmd({ cmd = "vsplit" }, {})
            elseif opts.split then
                vim.api.nvim_cmd({ cmd = "split" }, {})
            elseif opts.tabedit then
                vim.api.nvim_cmd({ cmd = "tabedit" }, {})
            end

            vim.api.nvim_set_option_value("buflisted", true, { buf = buf })
            vim.api.nvim_set_current_buf(buf)

            extensions.extensions:emit(extensions.event_names.NAVIGATE, {
                buffer = buf,
            })
        end,
    },
})

Map("n", "<leader>ad", function() harpoon:list():add() end)

local t = function() harpoon.ui:toggle_quick_menu(harpoon:list(), { height_in_lines = 10 }) end
Map("n", "<leader>aa", t)

local mark = 10
for _ = 1, 10 do
    local this_mark = mark -- 10, 1, 2, 3, 4, 5, 6, 7, 8, 9
    local mod_mark = this_mark % 10 -- 0, 1, 2, 3, 4, 5, 6, 7, 8, 9

    Map("n", string.format("<leader>%s", mod_mark), function()
        if vim.api.nvim_get_option_value("filetype", { buf = 0 }) == "qf" then
            return vim.notify("Currently in qf buffer", vim.log.levels.WARN)
        end

        harpoon:list():select(this_mark)
    end)

    mark = mod_mark + 1
end

Map("n", "<leader>ar", function()
    local buf = vim.api.nvim_get_current_buf()
    require("mjm.utils").harpoon_rm_buf({ buf = buf })
end, { desc = "Delete current file from Harpoon List" })

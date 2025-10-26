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
    -- Using custom selection since the built-in uses bufload
    default = {
        select = function(list_item, list, opts)
            local extensions = require("harpoon.extensions")
            require("harpoon.logger"):log("custom#select", list_item, list.name, opts)

            if not list_item then
                vim.notify("nil list_item")
                return
            end

            if not vim.uv.fs_access(list_item.value, 4) then
                vim.notify(list_item.value .. " not found", vim.log.levels.WARN)
                return
            end

            local buf = vim.fn.bufadd(list_item.value) ---@type integer
            local success = require("mjm.utils").open_buf({ bufnr = buf }, {})

            if success then
                extensions.extensions:emit(extensions.event_names.NAVIGATE, {
                    buffer = buf,
                })
            end
        end,
    },
})

vim.keymap.set("n", "<leader>ad", function()
    harpoon:list():add()
end)

vim.keymap.set("n", "<leader>aa", function()
    harpoon.ui:toggle_quick_menu(harpoon:list(), { height_in_lines = 10 })
end)

local mark = 10
for _ = 1, 10 do
    local this_mark = mark -- 10, 1, 2, 3, 4, 5, 6, 7, 8, 9
    local mod_mark = this_mark % 10 -- 0, 1, 2, 3, 4, 5, 6, 7, 8, 9

    vim.keymap.set("n", string.format("<leader>%s", mod_mark), function()
        local open_mark = function()
            harpoon:list():select(this_mark)
        end

        local ok, result = pcall(open_mark)
        if not ok then
            local chunk = { result or "Unknown error opening harpoon mark", "ErrorMsg" }
            vim.api.nvim_echo({ chunk }, true, { err = true })
        end
    end)

    mark = mod_mark + 1
end

vim.keymap.set("n", "<leader>ar", function()
    local buf = vim.api.nvim_get_current_buf()
    require("mjm.utils").harpoon_rm_buf({ buf = buf })
end, { desc = "Delete current file from Harpoon List" })

-- https://github.com/neovim/neovim/issues/32546 - Data storage

-- LOW: How to open marks from a list in a vsplit

local api = vim.api
local fn = vim.fn
local set = vim.keymap.set
local uv = vim.uv

local function setup_harpoon()
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
                local logger = require("harpoon.logger")
                logger:log("custom#select", list_item, list.name, opts)

                local echo_err = require("nvim-tools.ui").echo_err
                if not list_item then
                    echo_err(false, "nil list_item", "ErrorMsg")
                    return
                end

                local ntb = require("nvim-tools.buf")
                local bufname = list_item.value
                local ok, bufnr, err, hl = ntb.bufname_to_bufnr(bufname)
                if not ok then
                    echo_err(false, err, hl)
                    return
                end

                -- Get here since open_buf resolves 0 win numbers
                local cur_win = api.nvim_get_current_win()
                local cur_buf = api.nvim_win_get_buf(cur_win)
                if cur_buf == bufnr then
                    echo_err(false, "Already in " .. bufname, "")
                    return
                end

                -- Don't navigate to a cursor position because I use the " mark
                ntb.open_buf(cur_win, bufnr, {
                    buftype = "",
                    fold_cmd = "zv",
                    force = "hide",
                })

                local extensions = require("harpoon.extensions")
                extensions.extensions:emit(extensions.event_names.NAVIGATE, {
                    buffer = bufnr,
                })
            end,
        },
    })

    set("n", "<leader>ad", function()
        harpoon:list():add()
    end)

    set("n", "<leader>aa", function()
        harpoon.ui:toggle_quick_menu(harpoon:list(), { height_in_lines = 10 })
    end)

    local mark = 10
    for _ = 1, 10 do
        local this_mark = mark -- 10, 1, 2, 3, 4, 5, 6, 7, 8, 9
        local mod_mark = this_mark % 10 -- 0, 1, 2, 3, 4, 5, 6, 7, 8, 9

        set("n", string.format("<leader>%s", mod_mark), function()
            local open_mark = function()
                harpoon:list():select(this_mark)
            end

            local ok, result = pcall(open_mark)
            if not ok then
                local chunk = { result or "Unknown error opening harpoon mark", "ErrorMsg" }
                api.nvim_echo({ chunk }, true, { err = true })
            end
        end)

        mark = mod_mark + 1
    end

    vim.keymap.set("n", "<leader>ar", function()
        local buf = api.nvim_get_current_buf()
        require("mjm.utils").harpoon_rm_buf({ buf = buf })
    end)
end

return {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    lazy = false,
    config = function()
        setup_harpoon()
    end,
}

-- FUTURE: No work on this unless it is a significant blocker
-- https://github.com/neovim/neovim/issues/32546 - Data storage

vim.cmd.packadd({ vim.fn.escape("harpoon", " "), bang = true, magic = { file = false } })

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
        -- The default select function uses bufload > nvim_set_current_buf
        -- Per Fzflua's comments this "messes up" BufReadPost autocmds. This lines up with my
        -- own observations. opt_locals that require buf and win context do not set
        -- Use nvim_win_set_buf instead, which loads the buf if needed
        select = function(list_item, list, opts)
            logger:log("custom#select", list_item, list.name, opts)

            if not list_item then
                vim.notify("nil list_item")
                return
            end

            if not vim.uv.fs_stat(list_item.value) then
                vim.notify(list_item.value .. " not found", vim.log.levels.WARN)
                return
            end

            local prev_bufs = vim.api.nvim_list_bufs() --- @type integer[]
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
            vim.api.nvim_win_set_buf(0, buf)

            if not vim.tbl_contains(prev_bufs, buf) then
                list_item.context.row = list_item.context.row or 1
                list_item.context.col = list_item.context.col or 0

                local line_count = vim.api.nvim_buf_line_count(buf) --- @type integer
                local updated = false --- @type boolean
                if list_item.context.row > line_count then
                    list_item.context.row = line_count
                    updated = true
                end

                local row = list_item.context.row --- @type integer
                --- @type integer
                local col = #vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]

                if list_item.context.col > col then
                    list_item.context.col = col
                    updated = true
                end

                --- @type {[1]:integer, [2]:integer}
                local cur_pos = { list_item.context.row, list_item.context.col }
                vim.api.nvim_win_set_cursor(0, cur_pos)

                if updated then
                    extensions.extensions:emit(extensions.event_names.POSITION_UPDATED, {
                        list_item = list_item,
                    })
                end
            end

            extensions.extensions:emit(extensions.event_names.NAVIGATE, {
                buffer = buf,
            })
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
        if vim.api.nvim_get_option_value("filetype", { buf = 0 }) == "qf" then
            return vim.notify("Currently in qf buffer", vim.log.levels.WARN)
        end

        harpoon:list():select(this_mark)
    end)

    mark = mod_mark + 1
end

-- Adapted from mike-jl/harpoonEx
local function rm_cur_buf()
    local list = harpoon:list()
    if not list then
        return
    end
    local items = list.items

    local buf = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
    local idx = nil
    for i, t in pairs(items) do
        local item = vim.fn.fnamemodify(t.value, ":p")
        if buf == item then
            idx = i
            break
        end
    end

    if not idx then
        return
    end

    table.remove(list.items, idx)
    list._length = list._length - 1

    extensions.extensions:emit(extensions.event_names.REMOVE)
end

vim.keymap.set("n", "<leader>ar", function()
    rm_cur_buf()
end, { desc = "Delete current file from Harpoon List" })

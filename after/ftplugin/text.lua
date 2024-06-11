vim.opt_local.wrap = true
vim.opt_local.spell = true
vim.opt_local.colorcolumn = ""
vim.opt_local.sidescrolloff = 12

local km = require("mjm.keymap_mod")
vim.keymap.set("i", "<backspace>", function()
    km.insert_backspace_fix({ allow_blank = true })
end, { silent = true, buffer = true })

vim.keymap.set("i", "<cr>", function()
    local cur_line = vim.api.nvim_get_current_line()
    local start_idx, end_idx = string.find(cur_line, "%S")
    if not start_idx then
        return "<cr>"
    end
    local first_two = string.sub(cur_line, start_idx, end_idx + 1)
    if first_two ~= "- " then
        return "<cr>"
    end
    if #cur_line == end_idx + 1 then
        return "<bs><bs><cr>"
    end

    return "<cr>- "
end, { silent = true, expr = true, buffer = true })

vim.keymap.set("i", "<tab>", function()
    local cur_line = vim.api.nvim_get_current_line()
    local start_idx, end_idx = string.find(cur_line, "%S")
    if not start_idx then
        return "<tab>"
    end
    local first_char = string.sub(cur_line, start_idx, end_idx)
    if first_char == "-" and #cur_line == end_idx then
        return "<space>"
    end
    local first_two = string.sub(cur_line, start_idx, end_idx + 1)
    if first_two ~= "- " then
        return "<tab>"
    end

    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    print(cur_col, start_idx)
    if cur_col == start_idx then
        return "<left><tab><right><right>"
    end
    if cur_col - 1 == start_idx then
        return "<left><left><tab><right><right>"
    end

    return "<tab>"
end, { silent = true, expr = true, buffer = true })

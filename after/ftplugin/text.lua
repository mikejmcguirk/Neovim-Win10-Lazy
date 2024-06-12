vim.opt_local.wrap = true
vim.opt_local.spell = true
vim.opt_local.colorcolumn = ""
vim.opt_local.sidescrolloff = 12

local bp = require("mjm.backplacer")
vim.keymap.set("i", "<backspace>", function()
    local cur_line = vim.api.nvim_get_current_line()
    local start_idx, end_idx = string.find(cur_line, "%S")
    if not start_idx then
        bp.insert_backspace_fix({ allow_blank = true })
        return
    end

    local first_two = string.sub(cur_line, start_idx, end_idx + 1)
    local start_row, start_col = unpack(vim.api.nvim_win_get_cursor(0))
    local is_list = first_two == "- " or first_two == "-"
    local is_at_end = #cur_line == end_idx or #cur_line == end_idx + 1
    local beginning_case = start_idx == 1
    local on_or_after = (start_col >= start_idx) or beginning_case
    if not (is_list and is_at_end and on_or_after) then
        bp.insert_backspace_fix({ allow_blank = true })
        return
    end

    local whitespace = start_idx - 1
    local edit_row = start_row - 1
    if whitespace == 0 then
        vim.api.nvim_buf_set_text(0, edit_row, 0, edit_row, #cur_line, { "" })
        return
    end

    local shiftwidth = vim.fn.shiftwidth()
    if whitespace <= shiftwidth then
        vim.api.nvim_buf_set_text(0, edit_row, 0, edit_row, whitespace, { "" })
        if string.len(first_two) == 2 and start_col == start_idx then
            local key = vim.api.nvim_replace_termcodes("<right>", true, false, true)
            vim.api.nvim_feedkeys(key, "n", false)
        end
        return
    end

    local extra_spaces = whitespace % shiftwidth
    local to_remove = nil
    if extra_spaces == 0 then
        to_remove = shiftwidth
    else
        to_remove = extra_spaces
    end

    vim.api.nvim_buf_set_text(0, edit_row, 0, edit_row, to_remove, { "" })
    if first_two == "-" then
        local key = vim.api.nvim_replace_termcodes("<space>", true, false, true)
        vim.api.nvim_feedkeys(key, "n", false)
        return
    end
    if string.len(first_two) == 2 and start_col == start_idx then
        local key = vim.api.nvim_replace_termcodes("<right>", true, false, true)
        vim.api.nvim_feedkeys(key, "n", false)
    end
end, { silent = true, buffer = true })

vim.keymap.set("i", "<cr>", function()
    local cur_line = vim.api.nvim_get_current_line()
    local start_idx, end_idx = string.find(cur_line, "%S")
    if not start_idx then
        return "<cr>"
    end

    local first_two = string.sub(cur_line, start_idx, end_idx + 1)
    if first_two == "-" then
        return "<bs><cr>"
    end
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

    local first_two = string.sub(cur_line, start_idx, end_idx + 1)
    if first_two == "-" then
        return "<space>"
    end
    if first_two ~= "- " then
        return "<tab>"
    end

    local cur_col = vim.api.nvim_win_get_cursor(0)[2]
    if cur_col == start_idx then
        return "<left><tab><right><right>"
    end
    if cur_col - 1 == start_idx then
        return "<left><left><tab><right><right>"
    end
    return "<tab>"
end, { silent = true, expr = true, buffer = true })

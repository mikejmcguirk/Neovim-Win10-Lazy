local bp = require("mjm.backplacer")

vim.opt_local.wrap = true
vim.opt_local.spell = true
vim.opt_local.colorcolumn = ""
vim.opt_local.sidescrolloff = 12

vim.keymap.set("i", "<backspace>", function()
    -- Add case where there is text after the bullet but you are on or right after the bullet
    -- This should push the bullet back
    -- shouldn't we also be able to handle the case where we have extra spaces after the bullet
    -- Should just be able to hit <bs> once to remove them
    local cur_line = vim.api.nvim_get_current_line()
    local start_idx, end_idx = string.find(cur_line, "%S")
    if not start_idx then
        bp.insert_backspace_fix({ allow_blank = true })
        return
    end

    local first_two = string.sub(cur_line, start_idx, end_idx + 1)
    local is_list = first_two == "- " or first_two == "-"
    if not is_list then
        bp.insert_backspace_fix({ allow_blank = true })
        return
    end

    local start_row, start_col = unpack(vim.api.nvim_win_get_cursor(0))
    if start_col < start_idx and start_idx > 1 then
        bp.insert_backspace_fix({ allow_blank = true })
        return
    end

    local is_at_end = #cur_line == end_idx or #cur_line == end_idx + 1
    if not is_at_end then
        bp.insert_backspace_fix({ allow_blank = true })
        return
    end

    local whitespace = start_idx - 1
    local edit_row = start_row - 1
    if whitespace and is_at_end == 0 then
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
    -- Add case where there is text after the bullet but you are on or right after the bullet
    -- This should return to the next line and remove the bullet
    -- Or maybe not because there's not a good way to handle inserting a bullet between
    -- two lines that are already bulleted
    -- Or I don't know maybe the it's fine
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

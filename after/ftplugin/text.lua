local bp = require("mjm.backplacer")

vim.opt_local.wrap = true
vim.opt_local.spell = true
vim.opt_local.colorcolumn = ""
vim.opt_local.sidescrolloff = 12

vim.keymap.set("i", "<backspace>", function()
    local cur_line = vim.api.nvim_get_current_line()
    local start_idx, end_idx = string.find(cur_line, "%S")
    if not start_idx then
        bp.insert_backspace_fix({ allow_blank = true })
        return
    end

    -- Are we in a bulleted list?
    local first_one = string.sub(cur_line, start_idx, start_idx)
    if first_one ~= "-" then
        bp.insert_backspace_fix({ allow_blank = true })
        return
    end

    local start_row, start_col = unpack(vim.api.nvim_win_get_cursor(0))
    if start_col >= start_idx + 2 then
        bp.insert_backspace_fix({ allow_blank = true })
        return
    end

    local edit_row = start_row - 1
    local second_one = string.sub(cur_line, start_idx + 1, start_idx + 1)
    -- Better to handle this case separately and early
    -- Addressing it within the rest of the logic gets convoluted
    if (#cur_line == 2 and second_one == " ") or #cur_line == 1 then
        vim.api.nvim_buf_set_text(0, edit_row, 0, edit_row, #cur_line, { "" })
        return
    end

    -- Avoid edge case where there is no leading whitespace and you backspace twice into
    -- the previous line
    if start_col == 0 then
        bp.insert_backspace_fix({ allow_blank = true })
        return
    end

    -- These feedkeys are not theoretically necessary in cases where leading whitespace is zero
    -- However, by doing them anyway, we avoid creating special logic to handle one case
    -- And I see no performance issue with the extra feedkey
    if start_col == start_idx and (not second_one or second_one ~= " ") then
        local key = vim.api.nvim_replace_termcodes("<space>", true, false, true)
        vim.api.nvim_feedkeys(key, "n", false)
    elseif start_col == start_idx and second_one == " " then
        local key = vim.api.nvim_replace_termcodes("<right>", true, false, true)
        vim.api.nvim_feedkeys(key, "n", false)
    end

    local whitespace = start_idx - 1
    local shiftwidth = vim.fn.shiftwidth()
    if whitespace == 0 then
        local key = vim.api.nvim_replace_termcodes("<bs><bs>", true, false, true)
        vim.api.nvim_feedkeys(key, "n", false)
        return
    end

    if whitespace <= shiftwidth then
        vim.api.nvim_buf_set_text(0, edit_row, 0, edit_row, whitespace, { "" })
        return
    end

    local to_remove = nil
    local extra_spaces = whitespace % shiftwidth
    if extra_spaces == 0 then
        to_remove = shiftwidth
    else
        to_remove = extra_spaces
    end
    vim.api.nvim_buf_set_text(0, edit_row, 0, edit_row, to_remove, { "" })
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

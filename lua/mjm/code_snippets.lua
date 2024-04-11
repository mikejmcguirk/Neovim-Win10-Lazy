---@param chars string
---@return nil
local put_at_end = function(chars)
    if not km.check_modifiable() then
        return
    end

    local orig_line = vim.api.nvim_get_current_line()
    local cur_row = vim.api.nvim_win_get_cursor(0)[1]
    local set_row = cur_row - 1

    if orig_line == "" then
        vim.api.nvim_buf_set_text(0, set_row, 0, set_row, 0, { chars })

        return
    end

    local trim_line = orig_line:gsub("%s+$", "")
    local chars_len = #chars
    local end_chars = trim_line:sub(-chars_len)

    local orig_len = #orig_line
    local trim_len = #trim_line

    if end_chars == chars then
        local set_col = trim_len - chars_len
        vim.api.nvim_buf_set_text(0, set_row, set_col, set_row, orig_len, {})
    else
        local set_col = trim_len
        vim.api.nvim_buf_set_text(0, set_row, set_col, set_row, orig_len, { chars })
    end
end

vim.keymap.set("n", "<M-;>", function()
    put_at_end(";")
end, { silent = true })

vim.keymap.set("v", "H", function()
    local cur_mode = vim.api.nvim_get_mode().mode
    local is_visual_line = cur_mode == "V" or cur_mode == "Vs"

    if km.check_modifiable() and is_visual_line then
        return "d<cmd>wincmd h<cr>P`[v`]V"
    else
        return "<Nop>"
    end
end, { silent = true, expr = true })

vim.keymap.set("v", "L", function()
    local cur_mode = vim.api.nvim_get_mode().mode
    local is_visual_line = cur_mode == "V" or cur_mode == "Vs"

    if km.check_modifiable() and is_visual_line then
        return "d<cmd>wincmd l<cr>P`[v`]V"
    else
        return "<Nop>"
    end
end, { silent = true, expr = true })

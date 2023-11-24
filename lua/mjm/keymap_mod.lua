local M = {}

M.opts = { silent = true }
M.expr_opts = vim.tbl_extend("force", { expr = true }, M.opts)

---@return boolean
M.check_modifiable = function()
    if vim.api.nvim_buf_get_option(0, "modifiable") then
        return true
    end

    vim.api.nvim_err_writeln("E21: Cannot make changes, 'modifiable' is off")

    return false
end

---@param map string
---@return nil
M.restorecursor = function(map)
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.cmd("normal! " .. map)
    vim.api.nvim_win_set_cursor(0, { cur_row, cur_col })
end

---@param map string
---@return nil
M.restorecursor_writeonly = function(map)
    if M.check_modifiable() then
        M.restorecursor(map)
    end
end

---@param map string
---@return nil
M.restorecursor_writeonly_restoreview = function(map)
    local cur_view = vim.fn.winsaveview()
    M.restorecursor_writeonly(map)
    vim.fn.winrestview(cur_view)
end

---@param visual string
---@param linewise string
---@return string
M.vertical_motion_fix = function(visual, linewise)
    if vim.v.count == 0 then
        return visual
    else
        return linewise
    end
end

---@return string
M.dd_fix = function()
    if vim.v.count1 <= 1 and vim.api.nvim_get_current_line() == "" then
        return '"_dd'
    else
        return "dd"
    end
end

---@param backward_objects string[]
---@return nil
M.fix_backward_yanks = function(backward_objects)
    for _, object in ipairs(backward_objects) do
        local main_map = "y" .. object

        vim.keymap.set("n", main_map, function()
            local main_cmd = vim.v.count1 .. main_map
            M.restorecursor(main_cmd)
        end, M.default_opts)

        local ext_map = "<leader>y" .. object

        vim.keymap.set("n", ext_map, function()
            local ext_cmd = vim.v.count1 .. '"+' .. main_map
            M.restorecursor(ext_cmd)
        end, M.default_opts)
    end
end

---@param motions string[]
---@param text_objects string[]
---@param inner_outer string[]
---@return nil
M.demap_text_objects_inout = function(motions, text_objects, inner_outer)
    for _, motion in pairs(motions) do
        for _, object in pairs(text_objects) do
            for _, in_out in pairs(inner_outer) do
                local normal_map = motion .. in_out .. object
                vim.keymap.set("n", normal_map, "<nop>", M.default_opts)

                local ext_map = "<leader>" .. motion .. in_out .. object
                vim.keymap.set("n", ext_map, "<nop>", M.default_opts)
            end
        end
    end
end

---@param motions string[]
---@param text_objects string[]
---@return nil
M.demap_text_objects = function(motions, text_objects)
    for _, motion in pairs(motions) do
        for _, object in pairs(text_objects) do
            vim.keymap.set("n", motion .. object, "<nop>", M.default_opts)
            vim.keymap.set("n", "<leader>" .. motion .. object, "<nop>", M.default_opts)
        end
    end
end

---@param text_objects string[]
---@param inner_outer string[]
---@return nil
M.yank_cursor_fixes = function(text_objects, inner_outer)
    for _, object in pairs(text_objects) do
        for _, in_out in pairs(inner_outer) do
            local main_cmd = "y" .. in_out .. object

            vim.keymap.set("n", main_cmd, function()
                M.restorecursor(main_cmd)
            end, M.default_opts)

            local ext_map = "<leader>y" .. in_out .. object
            local ext_cmd = '"+' .. main_cmd

            vim.keymap.set("n", ext_map, function()
                M.restorecursor(ext_cmd)
            end, M.default_opts)
        end
    end
end

---@param paste_char string
---@return string
M.visual_paste = function(paste_char)
    if not M.check_modifiable() then
        return "<Nop>"
    end

    local cur_mode = vim.fn.mode()
    local count = vim.v.count1

    if cur_mode == "V" or cur_mode == "Vs" then
        return count .. paste_char .. "=`]"
    else
        return "mz" .. count .. paste_char .. "`z"
    end
end

---@param put_cmd string
---@return nil
M.create_blank_line = function(put_cmd)
    if not M.check_modifiable() then
        return
    end

    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    -- Uses a mark so that the cursor sticks with the text the map is called from
    vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})

    vim.cmd(put_cmd .. " =repeat(nr2char(10), v:count1)")
    vim.cmd("normal! `z")
end

---@param vcount1 number
---@param min_count number
---@param pos_1 string
---@param pos_2 string
---@param fix_num number
---@param cmd_start string
---@return nil
M.visual_move = function(vcount1, min_count, pos_1, pos_2, fix_num, cmd_start)
    if not M.check_modifiable() then
        return
    end

    -- '< and '> are not updated until after leaving Visual Mode
    -- This also updates vim.v.count1, which is why it's passed as a parameter
    vim.cmd([[execute "normal! \<esc>"]])

    local get_to_move = function()
        if vcount1 <= min_count then
            return min_count
        else
            return vcount1 - (vim.fn.line(pos_1) - vim.fn.line(pos_2)) + fix_num
        end
    end

    local cmd = cmd_start .. get_to_move()
    vim.cmd(cmd)

    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))

    vim.cmd("normal! `]")
    local end_cursor_pos = vim.api.nvim_win_get_cursor(0)
    local end_row = end_cursor_pos[1]
    local end_line = vim.api.nvim_get_current_line()
    local end_col = #end_line
    vim.api.nvim_buf_set_mark(0, "z", end_row, end_col, {})

    vim.cmd("normal! `[")
    local start_cursor_pos = vim.api.nvim_win_get_cursor(0)
    local start_row = start_cursor_pos[1]
    vim.api.nvim_win_set_cursor(0, { start_row, 0 })

    vim.cmd("normal! =`z")
    vim.api.nvim_win_set_cursor(0, { cur_row, cur_col })
    vim.cmd("normal! gv")
end

---@return nil
M.bump_up = function()
    if not M.check_modifiable() then
        return
    end

    local orig_line = vim.api.nvim_get_current_line()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local modified_line = orig_line:sub(1, cursor[2]):gsub("%s+$", "")
    vim.api.nvim_set_current_line(modified_line)

    local orig_line_len = #orig_line
    local to_move = orig_line:sub(cursor[2] + 1, orig_line_len):gsub("^%s+", ""):gsub("%s+$", "")
    vim.cmd("put! =''")
    local row = cursor[1] - 1
    vim.api.nvim_buf_set_text(0, row, 0, row, 0, { to_move })
    vim.cmd("normal! ==")
end

---@param chars string
---@return nil
M.put_at_beginning = function(chars)
    if not M.check_modifiable() then
        return
    end

    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local row = cursor_pos[1] - 1

    local current_line = vim.api.nvim_get_current_line()
    local chars_len = #chars
    local start_chars = current_line:sub(1, chars_len)

    if start_chars ~= chars then
        vim.api.nvim_buf_set_text(0, row, 0, row, 0, { chars })
    else
        local new_line = current_line:sub((chars_len + 1), current_line:len())
        vim.api.nvim_set_current_line(new_line)
    end
end

---@param chars string
---@return nil
M.put_at_end = function(chars)
    if not M.check_modifiable() then
        return
    end

    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local row = cursor_pos[1] - 1
    local current_line = vim.api.nvim_get_current_line()
    local cline_cleaned = current_line:gsub("%s+$", "")
    local col = #cline_cleaned

    local chars_len = #chars
    local end_chars = cline_cleaned:sub(-chars_len)

    if end_chars ~= chars then
        vim.api.nvim_buf_set_text(0, row, col, row, col, { chars })
    else
        local new_line = cline_cleaned:sub(1, cline_cleaned:len() - chars_len)
        vim.api.nvim_set_current_line(new_line)
    end
end

return M

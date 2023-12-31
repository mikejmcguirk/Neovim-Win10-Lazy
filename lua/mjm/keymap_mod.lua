local M = {}

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
M.rest_cursor = function(map, options)
    local opts = vim.deepcopy(options or {})

    if opts.mod_check and not M.check_modifiable() then
        return
    end

    local cur_view = nil

    if opts.rest_view then
        cur_view = vim.fn.winsaveview()
    end

    local orig_row, orig_col = unpack(vim.api.nvim_win_get_cursor(0))

    local status, result = pcall(function()
        vim.api.nvim_exec2("silent normal! " .. map, {})
    end)

    if (not status) and result then
        vim.api.nvim_err_writeln(result)

        return
    end

    vim.api.nvim_win_set_cursor(0, { orig_row, orig_col })

    if cur_view ~= nil then
        vim.fn.winrestview(cur_view)
    end
end

---@return boolean
local find_pairs = function()
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))

    if cur_col == 0 then
        return false
    end

    local cur_line = vim.api.nvim_get_current_line()
    local cur_char = cur_line:sub(cur_col, cur_col)

    local pairs = {
        { "{", "}" },
        { "[", "]" },
        { "(", ")" },
        { "<", ">" },
        { "'", "'" },
        { '"', '"' },
        { "`", "`" },
    }

    local check_pairs = function(char, to_find, to_return)
        for _, pair in ipairs(pairs) do
            if pair[to_find] == char then
                return pair[to_return]
            end
        end

        return nil
    end

    -- Check if we are in a pair
    local close_char = check_pairs(cur_char, 1, 2)
    local next_col = cur_col + 1
    local next_char = cur_line:sub(next_col, next_col)

    if close_char == next_char then
        local line_to_set = cur_row - 1
        local start_col = cur_col - 1
        local end_col = cur_col + 1

        vim.api.nvim_buf_set_text(0, line_to_set, start_col, line_to_set, end_col, { "" })
        vim.api.nvim_win_set_cursor(0, { cur_row, start_col })

        return true
    end

    if cur_col == 1 then
        return false
    end

    -- Check if we are directly to the right of a pair
    local open_char = check_pairs(cur_char, 2, 1)

    if open_char == nil then
        return false
    end

    local prev_char = cur_line:sub(cur_col - 1, cur_col - 1)

    if open_char == prev_char then
        local line_to_set = cur_row - 1
        local start_col = cur_col - 2

        vim.api.nvim_buf_set_text(0, line_to_set, start_col, line_to_set, cur_col, { "" })
        vim.api.nvim_win_set_cursor(0, { cur_row, start_col })

        return true
    end

    return false
end

---@param line_num number
---@return number
local get_indent = function(line_num)
    -- If Treesitter indent is enabled, the indentexpr will be set to
    -- nvim_treesitter#indent(), so that will be captured here
    local indentexpr = vim.bo.indentexpr

    if indentexpr ~= "" then
        -- Most indent expressions in the Nvim runtime do not take an argument
        --
        -- However, a few of them do take v:lnum as an argument
        -- v:lnum is not updated when nvim_exec2 is called, so it must be updated here
        --
        -- A couple of the runtime expressions take '.' as an argument
        -- This is already updated before nvim_exec2 is called
        --
        -- Other indentexpr options are not guaranteed to be handled properly
        vim.v.lnum = line_num
        local expr_indent_tbl = vim.api.nvim_exec2("echo " .. indentexpr, { output = true })
        local expr_indent_str = expr_indent_tbl.output
        local expr_indent = tonumber(expr_indent_str) or 0

        return expr_indent
    end

    local prev_nonblank = vim.fn.prevnonblank(line_num - 1)
    local prev_nonblank_indent = vim.fn.indent(prev_nonblank)

    return prev_nonblank_indent
end

---@return nil
local backspace_blank_line = function(options)
    local opts = vim.deepcopy(options or {})
    local start_row, start_col = unpack(vim.api.nvim_win_get_cursor(0))
    local start_indent = get_indent(start_row)

    local snap_to_indent = start_col > start_indent
    local reduce_indent = start_col > 0 and opts.allow_blank

    if snap_to_indent or reduce_indent then
        local set_start

        if snap_to_indent then
            set_start = start_indent - 1
        else
            local shiftwidth = vim.fn.shiftwidth()
            local extra_spaces = start_col % shiftwidth

            local to_remove

            if extra_spaces == 0 then
                to_remove = shiftwidth
            else
                to_remove = extra_spaces
            end

            set_start = (start_col - 1) - to_remove
        end

        if set_start <= 0 then
            vim.api.nvim_set_current_line("")

            return
        end

        local start_line = vim.api.nvim_get_current_line()
        local start_line_length = #start_line - 1
        local set_row = start_row - 1

        vim.api.nvim_buf_set_text(0, set_row, set_start, set_row, start_line_length, {})

        return
    end

    vim.api.nvim_del_current_line()

    local cur_row = vim.fn.line(".")

    ---@return number
    local get_destination_row = function()
        local on_first_row = cur_row == 1
        local already_moved = cur_row ~= start_row -- If you delete the last line

        if on_first_row or already_moved then
            return cur_row
        end

        return cur_row - 1
    end

    local dest_row = get_destination_row()

    vim.api.nvim_win_set_cursor(0, { dest_row, 0 })

    local dest_line = vim.api.nvim_get_current_line()
    local dest_col = #dest_line
    local last_non_blank, _ = dest_line:find("(%S)%s*$")
    local set_row = dest_row - 1

    if dest_col > 0 and last_non_blank ~= nil then
        local trailing_whitespace = string.match(dest_line, "%s+$")

        if trailing_whitespace then
            vim.api.nvim_buf_set_text(0, set_row, last_non_blank, set_row, dest_col, { "" })

            dest_line = vim.api.nvim_get_current_line()
            dest_col = #dest_line
        end

        vim.api.nvim_win_set_cursor(0, { dest_row, dest_col })

        return
    end

    local dest_line_num = vim.fn.line(".")
    local indent = get_indent(dest_line_num)

    if indent <= 0 then
        return
    end

    vim.api.nvim_buf_set_lines(0, set_row, dest_row, false, { string.rep(" ", indent) })
    vim.api.nvim_win_set_cursor(0, { dest_row, indent })
end

---@return nil
M.insert_backspace_fix = function(options)
    local empty_string = string.match(vim.api.nvim_get_current_line(), "^%s*$")

    if not empty_string then
        -- windp/autopairs creates its own backspace mapping if map_bs is enabled
        -- Since map_bs must be disabled there, check for pairs here
        if find_pairs() then
            return
        end

        local key = vim.api.nvim_replace_termcodes("<backspace>", true, false, true)
        vim.api.nvim_feedkeys(key, "n", true)

        return
    end

    backspace_blank_line(options)
end

---@param backward_objects string[]
---@return nil
M.fix_backward_yanks = function(backward_objects)
    local back_objs = vim.deepcopy(backward_objects)

    for _, object in ipairs(back_objs) do
        local main_map = "y" .. object

        vim.keymap.set("n", main_map, function()
            local main_cmd = vim.v.count1 .. main_map
            M.rest_cursor(main_cmd)
        end, { silent = true })

        local ext_map = "<leader>y" .. object

        vim.keymap.set("n", ext_map, function()
            local ext_cmd = vim.v.count1 .. '"+' .. main_map
            M.rest_cursor(ext_cmd)
        end, { silent = true })
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
                vim.keymap.set("n", normal_map, "<nop>")

                local ext_map = "<leader>" .. normal_map
                vim.keymap.set("n", ext_map, "<nop>")
            end
        end
    end
end

---@param motions string[]
---@param objects string[]
---@return nil
M.fix_startline_motions = function(motions, objects)
    for _, motion in pairs(motions) do
        for _, object in pairs(objects) do
            local what_register = function()
                if motion == "y" then
                    return '"+'
                else
                    return '"_'
                end
            end

            local register = what_register()

            local map = motion .. object
            local ext_map = "<leader>" .. map

            local cmd = "v" .. object .. motion
            local cmd_mark = "mz" .. cmd .. "`z"

            local ext_cmd = "v" .. object .. register .. motion
            local ext_cmd_mark = "mz" .. ext_cmd .. "`z"

            if motion == "y" then
                vim.keymap.set("n", map, cmd_mark, { silent = true })
                vim.keymap.set("n", ext_map, ext_cmd_mark, { silent = true })
            else
                vim.keymap.set("n", map, cmd, { silent = true })
                vim.keymap.set("n", ext_map, ext_cmd, { silent = true })
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
            vim.keymap.set("n", motion .. object, "<nop>")
            vim.keymap.set("n", "<leader>" .. motion .. object, "<nop>")
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
            local ext_map = "<leader>" .. main_cmd
            local ext_cmd = '"+' .. main_cmd

            vim.keymap.set("n", main_cmd, function()
                M.rest_cursor(main_cmd)
            end, { silent = true })

            vim.keymap.set("n", ext_map, function()
                M.rest_cursor(ext_cmd)
            end, { silent = true })
        end
    end
end

---@param paste_char string
---@return string
M.visual_paste = function(paste_char)
    if not M.check_modifiable() then
        return "<Nop>"
    end

    local cur_mode = vim.api.nvim_get_mode().mode
    local count = vim.v.count1

    if cur_mode == "V" or cur_mode == "Vs" then
        return count .. paste_char .. "=`]"
    else
        return "mz" .. count .. paste_char .. "`z"
    end
end

---@param use_bang boolean
---@return nil
M.create_blank_line = function(use_bang)
    if not M.check_modifiable() then
        return
    end

    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    -- Uses a mark so that the cursor sticks with the text the map is called from
    vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})

    local put_cmd = "put"

    if use_bang then
        put_cmd = put_cmd .. "!"
    end

    put_cmd = put_cmd .. " =repeat(nr2char(10), v:count1)"

    vim.api.nvim_exec2(put_cmd, {})
    vim.api.nvim_exec2("normal! `z", {})
end

---@param vcount1 number
---@param direction string
---@return nil
M.visual_move = function(vcount1, direction)
    if not M.check_modifiable() then
        return
    end

    if not (direction == "u" or direction == "d") then
        vim.api.nvim_err_writeln("Invalid direction")

        return
    end

    -- We must leave visual mode to update '< and '>
    -- Because vim.v.count1 is updated when we do this, it is passed as a parameter
    vim.api.nvim_exec2('exec "silent normal! \\<esc>"', {})

    local min_count = 1
    local pos_1 = nil
    local pos_2 = nil
    local fix_num = nil
    local cmd_start = nil

    if direction == "d" then
        pos_1 = "'>"
        pos_2 = "."
        fix_num = 0
        cmd_start = "'<,'> m '>+"
    elseif direction == "u" then
        pos_1 = "."
        pos_2 = "'<"
        fix_num = 1
        cmd_start = "'<,'> m '<-"
    end

    local to_move = nil

    if vcount1 <= min_count then
        to_move = min_count + fix_num
    else
        local offset = vim.fn.line(pos_1) - vim.fn.line(pos_2)
        to_move = vcount1 - offset + fix_num
    end

    local move_cmd = cmd_start .. to_move

    local status, result = pcall(function()
        vim.api.nvim_exec2(move_cmd, {})
    end)

    if (not status) and result then
        vim.api.nvim_err_writeln(result)
        vim.api.nvim_exec2("normal! gv", {})

        return
    end

    local dest_row, dest_col = unpack(vim.api.nvim_win_get_cursor(0))

    -- After the move cmd, `] will be set to the beginning of the last line of the block
    -- To properly format the last line, we set the z mark to the end of the line
    vim.api.nvim_exec2("silent normal! `]", {})
    local end_cursor_pos = vim.api.nvim_win_get_cursor(0)
    local end_row = end_cursor_pos[1]
    local end_line = vim.api.nvim_get_current_line()
    local end_col = #end_line
    vim.api.nvim_buf_set_mark(0, "z", end_row, end_col, {})

    vim.api.nvim_exec2("silent normal! `[", {})
    vim.api.nvim_exec2("silent normal! =`z", {})
    vim.api.nvim_win_set_cursor(0, { dest_row, dest_col })
    vim.api.nvim_exec2("silent normal! gv", {})
end

---@return nil
M.bump_up = function()
    if not M.check_modifiable() then
        return
    end

    local orig_line = vim.api.nvim_get_current_line()
    local orig_row, orig_col = unpack(vim.api.nvim_win_get_cursor(0))
    local orig_line_len = #orig_line
    local orig_set_row = orig_row - 1
    local rem_line = orig_line:sub(1, orig_col)
    local trailing_whitespace = string.match(rem_line, "%s+$")

    if trailing_whitespace then
        local last_non_blank, _ = rem_line:find("(%S)%s*$")

        if last_non_blank == nil then
            last_non_blank = 1
        end

        local set_col = nil

        if last_non_blank >= 1 then
            set_col = last_non_blank - 1
        else
            set_col = 0
        end

        vim.api.nvim_buf_set_text(0, orig_set_row, set_col, orig_set_row, orig_line_len, {})
    else
        vim.api.nvim_buf_set_text(0, orig_set_row, orig_col, orig_set_row, orig_line_len, {})
    end

    local orig_col_lua = orig_col + 1
    local to_move = orig_line:sub(orig_col_lua, orig_line_len)
    local to_move_trim = to_move:gsub("^%s+", ""):gsub("%s+$", "")
    vim.api.nvim_exec2("put! =''", {})
    vim.api.nvim_buf_set_text(0, orig_set_row, 0, orig_set_row, 0, { to_move_trim })
    vim.api.nvim_exec2("normal! ==", {})
end

---@param chars string
---@return nil
M.put_at_end = function(chars)
    if not M.check_modifiable() then
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

return M

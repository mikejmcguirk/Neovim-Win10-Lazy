local M = {}

---@param cur_row number
---@param cur_col number
---@param cur_line string
---@return boolean
local find_pairs = function(cur_row, cur_col, cur_line)
    if cur_col == 0 or #cur_line < 2 then
        return false
    end

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

    local cur_char = cur_line:sub(cur_col, cur_col)
    -- Check if we are within a pair
    local close_char = check_pairs(cur_char, 1, 2)
    local next_col = cur_col + 1
    local next_char = cur_line:sub(next_col, next_col)

    local edit_row = cur_row - 1
    if close_char == next_char then
        local start_col = cur_col - 1
        local end_col = cur_col + 1
        vim.api.nvim_buf_set_text(0, edit_row, start_col, edit_row, end_col, { "" })
        vim.api.nvim_win_set_cursor(0, { cur_row, start_col })
        return true
    end

    -- Check if we are directly to the right of a pair
    if cur_col == 1 then
        return false
    end
    local open_char = check_pairs(cur_char, 2, 1)
    local prev_char = cur_line:sub(cur_col - 1, cur_col - 1)

    if open_char ~= prev_char then
        return false
    end
    local start_col = cur_col - 2
    vim.api.nvim_buf_set_text(0, edit_row, start_col, edit_row, cur_col, { "" })
    vim.api.nvim_win_set_cursor(0, { cur_row, start_col })
    return true
end

---@param line_num number -- One indexed
---@return number
local get_indent = function(line_num)
    local fix_indent = function(indent)
        if indent <= 0 then
            return 0
        else
            return indent
        end
    end

    -- If Treesitter indent is enabled, the indentexpr will be set to
    -- nvim_treesitter#indent(), so that will be captured here
    local indentexpr = vim.bo.indentexpr
    if indentexpr == "" then
        local prev_nonblank = vim.fn.prevnonblank(line_num - 1)
        local prev_nonblank_indent = vim.fn.indent(prev_nonblank)
        return fix_indent(prev_nonblank_indent)
    end

    -- Most indent expressions in the Nvim runtime do not take an argument
    --
    -- However, a few of them do take v:lnum
    -- v:lnum is not updated when nvim_exec2 is called, so it must be updated here
    --
    -- A couple of the runtime expressions take '.' as an argument
    -- This is already updated before nvim_exec2 is called
    --
    -- Other indentexpr arguments are not guaranteed to be handled properly
    vim.v.lnum = line_num
    local expr_indent_tbl = vim.api.nvim_exec2("echo " .. indentexpr, { output = true })
    local expr_indent = tonumber(expr_indent_tbl.output) or 0
    return fix_indent(expr_indent)
end

---@param start_row number
---@param start_col number
---@param cur_line string
---@param options? table
---@return nil
local backspace_blank_line = function(start_row, start_col, cur_line, options)
    --rename start_row and start_col to cur_row and cur_col
    local opts = vim.deepcopy(options or {})
    local start_indent = get_indent(start_row)

    if start_col > start_indent then
        local edit_row = start_row - 1
        vim.api.nvim_buf_set_text(0, edit_row, start_indent, edit_row, #cur_line, {})
        return
    end

    if start_col > 0 and opts.allow_blank then
        local shiftwidth = vim.fn.shiftwidth()
        local extra_spaces = start_col % shiftwidth
        local to_remove = (extra_spaces == 0) and shiftwidth or extra_spaces
        local edit_start = start_col - to_remove
        local edit_row = start_row - 1

        vim.api.nvim_buf_set_text(0, edit_row, edit_start, edit_row, #cur_line, {})
        return
    end

    vim.api.nvim_del_current_line()
    -- This is a hack meant to address the following scenario:
    --      - Enter insert mode on line b
    --      - Backspace enough to delete it and move to line a
    --      - Press backspace again on line a some number of times
    --      - Leave insert mode
    --      - Undo previous changes
    --      - The backspaces on line b will be undone, but the ones on line a will remain
    -- I think this happens because running nvim_del_current_line in insert mode does not
    -- update the line number tracking properly for the undo history
    -- Closing and reopening the undo sequence updates the line numbering
    local insert_key = vim.api.nvim_replace_termcodes("<C-g>u", true, false, true)
    vim.api.nvim_feedkeys(insert_key, "n", false)
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

---@param options? table
---@return nil
M.insert_backspace_fix = function(options)
    local cur_line = vim.api.nvim_get_current_line()
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    local start_idx, end_idx = string.find(cur_line, "%S")
    if not start_idx then
        backspace_blank_line(cur_row, cur_col, cur_line, options)
        return
    end

    -- windp/autopairs creates its own backspace mapping if map_bs is enabled
    -- Since map_bs must be disabled there, check for pairs here
    if find_pairs(cur_row, cur_col, cur_line) then
        return
    end

    local key = vim.api.nvim_replace_termcodes("<backspace>", true, false, true)
    vim.api.nvim_feedkeys(key, "n", false)
end

return M

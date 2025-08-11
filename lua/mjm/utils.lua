local M = {}

---@param prompt string
---@return string
M.get_input = function(prompt)
    local pattern = nil ---@type string
    local _, result = pcall(function()
        pattern = vim.fn.input(prompt)
    end) ---@type boolean, unknown|nil

    vim.cmd("echo ''")
    if pattern then
        return pattern
    end

    if result == "Keyboard interrupt" then
        return ""
    end

    local err_msg = result or "Failed to get user input, unknown error"
    vim.api.nvim_echo({ { err_msg } }, true, { err = true })
    return ""
end

---@param bufnr? integer
---@return boolean
M.check_modifiable = function(bufnr)
    if vim.api.nvim_get_option_value("modifiable", { buf = bufnr or 0 }) then
        return true
    else
        local err_msg = "E21: Cannot make changes, 'modifiable' is off" ---@type string
        vim.api.nvim_echo({ { err_msg } }, true, { err = true })
        return false
    end
end

---@param line_num number -- One indexed
---@return integer|nil
M.get_indent = function(line_num)
    -- Captures nvim_treesitter#indent() if enabled
    if vim.bo.indentexpr == "" then
        local prevnonblank = vim.fn.prevnonblank(line_num - 1) ---@type integer
        local prevnonblank_indent = vim.fn.indent(prevnonblank) ---@type integer
        return prevnonblank_indent <= 0 and 0 or prevnonblank_indent
    end

    -- Most Nvim runtime indent expressions do not take an argument
    -- A few, however, take v:lnum
    -- v:lnum is not updated when nvim_exec2 is called, so it must be updated here
    -- A couple of the runtime expressions take '.' as an argument
    -- This is already updated before nvim_exec2 is called
    -- Other indentexpr arguments are not guaranteed to be handled properly
    vim.v.lnum = line_num
    local indentexpr_out = vim.api.nvim_eval(vim.bo.indentexpr) --- @type any
    local indent = tonumber(indentexpr_out) ---@type number?
    return indent >= 0 and indent or nil
end

---@param buf number
---@param start_idx number
---@param end_idx number
---@return nil
local function fix_bookend_blanks(buf, start_idx, end_idx)
    local line = vim.api.nvim_buf_get_lines(buf, start_idx, end_idx, true)[1] ---@type string
    local blank_line = (line == "") or line:match("^%s*$") ---@type any
    local last_line = vim.api.nvim_buf_line_count(buf) == 1 ---@type boolean

    if last_line or not blank_line then
        return
    end

    vim.api.nvim_buf_set_lines(buf, start_idx, end_idx, false, {})
    fix_bookend_blanks(buf, start_idx, end_idx)
end

M.fallback_formatter = function(buf)
    local shiftwidth = vim.api.nvim_get_option_value("shiftwidth", { buf = buf }) ---@type any
    if shiftwidth == 0 then
        shiftwidth = vim.api.nvim_get_option_value("tabstop", { buf = buf })
    else
        vim.api.nvim_set_option_value("tabstop", shiftwidth, { buf = buf })
    end

    local expandtab = vim.api.nvim_get_option_value("expandtab", { buf = buf }) ---@type any
    if expandtab then
        vim.api.nvim_set_option_value("softtabstop", shiftwidth, { buf = buf })
        vim.cmd(buf .. "bufdo retab")
    end

    fix_bookend_blanks(buf, 0, 1)
    fix_bookend_blanks(buf, -2, -1)

    local total_lines = vim.api.nvim_buf_line_count(buf) ---@type integer
    local lines = vim.api.nvim_buf_get_lines(buf, 0, total_lines, true) ---@type string[]

    local consecutive_blanks = 0 ---@type integer
    local lines_removed = 0 ---@type integer

    ---@param iter number
    ---@param line string
    ---@return nil
    local format_line = function(iter, line)
        local row_0 = iter - lines_removed - 1 ---@type number
        local line_len = #line ---@type integer
        local empty_line = line == "" ---@type boolean
        local whitespace_line = line:match("^%s+$") ---@type any
        local blank_line = empty_line or whitespace_line ---@type any

        if blank_line then
            consecutive_blanks = consecutive_blanks + 1
        else
            consecutive_blanks = 0
        end

        if blank_line and consecutive_blanks > 1 then
            vim.api.nvim_buf_set_lines(buf, row_0, row_0 + 1, false, {})
            lines_removed = lines_removed + 1

            return
        end

        if whitespace_line then
            vim.api.nvim_buf_set_text(buf, row_0, 0, row_0, line_len, {})
            return
        end

        local last_non_blank, _ = line:find("(%S)%s*$") ---@type integer|nil
        if last_non_blank and last_non_blank ~= line_len then
            vim.api.nvim_buf_set_text(buf, row_0, last_non_blank, row_0, line_len, {})
        end

        local first_non_blank, _ = line:find("%S") or 1, nil ---@type integer, nil
        first_non_blank = first_non_blank - 1
        local extra_spaces = first_non_blank % shiftwidth ---@type unknown
        if extra_spaces == 0 or not expandtab then
            return
        end

        local half_shiftwidth = shiftwidth * 0.5 ---@type unknown
        local round_up = extra_spaces >= half_shiftwidth ---@type boolean
        if round_up then
            local new_spaces = shiftwidth - extra_spaces
            local spaces = string.rep(" ", new_spaces)
            vim.api.nvim_buf_set_text(buf, row_0, 0, row_0, 0, { spaces })
        else
            vim.api.nvim_buf_set_text(buf, row_0, 0, row_0, extra_spaces, {})
        end
    end

    for i, line in ipairs(lines) do
        format_line(i, line)
    end
end

---@return boolean
function M.close_all_loclists()
    local closed_loc_list = false ---@type boolean
    for _, win in ipairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 and win.loclist == 1 then
            vim.api.nvim_win_close(win.winid, false)
            closed_loc_list = true
        end
    end

    return closed_loc_list
end

-- Taken from nvim-overfly
-- FUTURE: If I understand the Neovim repo code right, at some point a "highest" filter will be
-- added to diagnostic jumping
---@param opts? table{buf:integer|nil}
---@return integer|nil
function M.get_top_severity(opts)
    opts = opts or {}
    local has_warn = false ---@type boolean
    local has_info = false ---@type boolean
    local has_hint = false ---@type boolean

    for _, d in ipairs(vim.diagnostic.get(opts.buf or nil)) do
        if d.severity == vim.diagnostic.severity.ERROR then
            return vim.diagnostic.severity.ERROR
        elseif d.severity == vim.diagnostic.severity.WARN then
            has_warn = true
        elseif d.severity == vim.diagnostic.severity.INFO then
            has_info = true
        elseif d.severity == vim.diagnostic.severity.HINT then
            has_hint = true
        end
    end

    if has_warn then
        return vim.diagnostic.severity.WARN
    elseif has_info then
        return vim.diagnostic.severity.INFO
    elseif has_hint then
        return vim.diagnostic.severity.HINT
    else
        return nil
    end
end

---@return nil
M.check_word_under_cursor = function()
    local word = vim.fn.expand("<cword>")
    if word == "" then
        return vim.notify("No word under cursor", vim.log.levels.INFO)
    end

    local cmd = "wn " .. vim.fn.shellescape(word) .. " -over"
    local output = vim.fn.system(cmd)
    if vim.v.shell_error == -1 then
        return vim.notify("Error running wn: " .. output, vim.log.levels.ERROR)
    end

    local lines = {}
    for line in output:gmatch("[^\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            table.insert(lines, line)
        end
    end

    if #lines == 0 then
        return vim.notify("No results from WordNet for '" .. word .. "'", vim.log.levels.INFO)
    end

    vim.lsp.util.open_floating_preview(lines, "markdown", { border = Border })
end

function M.write_to_scratch_buf(lines)
    local scratch = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = scratch })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = scratch })
    vim.api.nvim_set_option_value("swapfile", false, { buf = scratch })

    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, vim.split(lines, "\n"))
    vim.cmd.vsplit()
    vim.api.nvim_set_current_buf(scratch)
end

function M.is_comment()
    local ok, lang_tree = pcall(vim.treesitter.get_parser)
    if (not ok) or not lang_tree then
        if type(lang_tree) == "string" then
            vim.api.nvim_echo({ { lang_tree } }, true, { kind = "echoerr" })
        else
            vim.notify("Unknown error getting parser in is_comment", vim.log.levels.ERROR)
        end
        return false
    end
    lang_tree:parse()

    -- Include col before or a cursor at the very end of a comment will be a "chunk" node
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local start_col = col > 0 and col - 1 or col
    local node = lang_tree:node_for_range({ row - 1, start_col, row - 1, col })
    if not node then
        return false
    end

    local comment_nodes = { "comment", "line_comment", "block_comment", "comment_content" }
    if vim.tbl_contains(comment_nodes, node:type()) then
        return true
    else
        return false
    end
end

return M

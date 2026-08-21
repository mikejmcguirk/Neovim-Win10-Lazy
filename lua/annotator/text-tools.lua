local api = vim.api
local fn = vim.fn

local M = {}

local function get_comment_start()
    local ft = api.nvim_get_option_value("filetype", { buf = 0 })
    return ft == "lua" and "--" or "//"
end

function M.add_annotation()
    local row = fn.line(".")
    local row_0 = row - 1
    local cur_line = api.nvim_get_current_line()

    local is_blank = string.match(cur_line, "^%s*$")
    local fin_row = is_blank and row or row_0
    local indent = require("nvim-tools.buf").get_indent(0, row)
    local cstart = get_comment_start()
    local mark_text = table.concat({ string.rep(" ", indent), cstart .. " MARK:  " .. cstart })

    api.nvim_buf_set_lines(0, row_0, fin_row, false, { mark_text })
    local new_col = #mark_text - 3
    api.nvim_win_set_cursor(0, { row, new_col })

    api.nvim_cmd({ cmd = "startinsert" }, {})
end
-- TODO: This method of handling cstart does not work for enclosing comment strings like markdown

local function get_border_char()
    local ft = api.nvim_get_option_value("filetype", { buf = 0 })
    return ft == "lua" and "-" or "/"
end

function M.add_borders()
    local row = fn.line(".")
    local row_0 = row - 1

    local line_count = api.nvim_buf_line_count(0)
    local start_line = math.max(0, row_0 - 1)
    local fin_line = math.min(line_count, row + 1)
    local lines = api.nvim_buf_get_lines(0, start_line, fin_line, false)

    local start_offset = row_0 - start_line
    local line_above = (start_offset == 1) and lines[1] or nil
    local cur_line = lines[start_offset + 1]
    local line_below = row < fin_line and lines[#lines] or nil

    local len_cur_line = #cur_line
    local indent = require("nvim-tools.buf").get_indent(0, row)

    local trail_start = string.find(cur_line, "%s+$")
    local len_trail = trail_start and (len_cur_line - trail_start + 1) or 0
    local len_content = len_cur_line - indent - len_trail
    local bchar = get_border_char()
    local border = string.rep(" ", indent) .. string.rep(bchar, len_content)

    ---@param line string?
    ---@return boolean
    local function is_border(line)
        return line and line:match("^%s*" .. bchar .. "+$") ~= nil or false
    end

    if is_border(line_above) and is_border(line_below) then
        api.nvim_buf_set_lines(0, row_0 - 1, row_0, false, { border })
        api.nvim_buf_set_lines(0, row_0 + 1, row_0 + 2, false, { border })
    else
        api.nvim_buf_set_lines(0, row_0, row_0, false, { border })
        api.nvim_buf_set_lines(0, row + 1, row + 1, false, { border })
    end
end

return M

-- TODO: Rename to be an underline file.

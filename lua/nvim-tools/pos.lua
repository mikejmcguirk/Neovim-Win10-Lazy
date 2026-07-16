local api = vim.api

local M = {}

---@alias nvim-tools.Pos [uinteger, uinteger]

---Buf should be in position 3 for compatibilty with vim.Pos
---@alias nvim-tools.pos.BufPos [uinteger, uinteger, uinteger]

--------------------
-- MARK: Creation --
--------------------

---@param lnum integer 1 indexed
---@param col integer 0 for omitted, or 1 indexed, inclusive
---@param vcol 0|1
---@param bufnr integer
---@return integer, integer 1,0 indexed, end inclusive
function M.mark_from_raw_qf(lnum, col, vcol, bufnr)
    local line_count = api.nvim_buf_line_count(bufnr)
    local row_1 = math.min(lnum, line_count)

    local line = api.nvim_buf_get_lines(bufnr, row_1 - 1, row_1, false)[1]
    local col_0

    if col > 0 then
        if vcol == 0 then
            col_0 = math.min(col, #line) - 1
        else
            local charlen = vim.call("strcharlen", line)
            local ntv = require("nvim-tools.vcol")
            col_0, _, _ = ntv.vcol_to_byte_bounds(line, col, charlen)
        end
    else
        col_0 = 0
    end

    return row_1, col_0
end

-------------------------------
-- MARK: Position Comparison --
-------------------------------

---@audited 2026-07-03
---@param a_r integer
---@param a_c integer
---@param b_r integer
---@param b_c integer
---@return -1|0|1
function M.cmp(a_r, a_c, b_r, b_c)
    if a_r == b_r then
        if a_c < b_c then
            return -1
        elseif b_c < a_c then
            return 1
        else
            return 0
        end
    elseif a_r < b_r then
        return -1
    else
        return 1
    end
end

---@audited 2026-07-03
---@param row_a integer
---@param col_a integer
---@param row_b integer
---@param col_b integer
---@return number
function M.pythagorean_dist(row_a, col_a, row_b, col_b)
    local delta_row = row_b - row_a
    local delta_col = col_b - col_a
    return math.sqrt(delta_row * delta_row + delta_col * delta_col)
end

-------------------------------
-- MARK: Position Conversion --
-------------------------------

---@audited 2026-07-03
---@param row integer 1 indexed
---@param col integer 1 indexed, inclusive
---@return integer, integer 0,0 indexed, inclusive end
function M.eval_to_ext(row, col)
    return row - 1, col - 1
end

---@audited 2026-07-03
---@param row integer 1 indexed
---@param col integer 1 indexed, inclusive
---@return integer, integer 1,0 indexed, inclusive end
function M.eval_to_mark(row, col)
    return row, col - 1
end

---@audited 2026-07-03
---@param row integer 0 indexed
---@param col integer 0 indexed, inclusive
---@return integer, integer 1,1 indexed, inclusive end
function M.ext_to_eval(row, col)
    return row + 1, col + 1
end

---@audited 2026-07-03
---Bespoke version to avoid vim.pos conversion.
---@param pos nvim-tools.Pos
---@param buf uinteger
---@param encoding lsp.PositionEncodingKind
---@return lsp.Position
function M.ext_to_lsp(pos, buf, encoding)
    local row = pos[1]
    local col = pos[2]
    if encoding == "utf-8" then
        return { line = row, character = col }
    end

    if col > 0 then
        local line = require("nvim-tools.lsp").get_line(buf, row)
        ---@diagnostic disable-next-line: param-type-mismatch
        col = require("nvim-tools.str").str_utfindex(line, encoding, col)
        return { line = row, character = col }
    elseif col == -1 then
        local line = require("nvim-tools.lsp").get_line(buf, row)
        ---@diagnostic disable-next-line: param-type-mismatch
        col = require("nvim-tools.str").str_utfindex(line, encoding, #line - 1)
        return { line = row, character = col }
    end

    local on_last_line = row == api.nvim_buf_line_count(buf)
    if not (on_last_line and api.nvim_get_option_value("endofline", { buf = buf }) == false) then
        return { line = row, character = col }
    end

    row = row - 1
    ---@cast row uinteger
    local line = require("nvim-tools.lsp").get_line(buf, row)
    ---@diagnostic disable-next-line: param-type-mismatch
    col = require("nvim-tools.str").str_utfindex(line, encoding, col)
    return { line = row, character = col }
end
-- MID: Goofy edge case with -1 handling where if -1 col is the end of a range, how do we know
-- if it should be end-exclusive? Might be upstream data issue.

---@audited 2026-07-03
---@param row integer 0 indexed
---@param col integer 0 indexed, inclusive
---@return integer, integer 1,0 indexed, inclusive end
function M.ext_to_mark(row, col)
    return row + 1, col
end

---Convert an ext-based position (0,0 based) to a mark-based position (1,0 based).
---@audited 2026-07-13
---@param pos_ext [uinteger, uinteger] Modified in place!
---@return [uinteger, uinteger] Reference to `pos_ext`
function M.ext_to_mark_pos(pos_ext)
    pos_ext[1] = pos_ext[1] + 1
    return pos_ext
end

---@audited 2026-07-03
---@param row integer 1 indexed
---@param col integer 0 indexed, inclusive
---@return integer, integer 1,0 indexed, inclusive end
function M.mark_to_eval(row, col)
    return row, col + 1
end

---@audited 2026-07-03
---@param row integer 1 indexed
---@param col integer 0 indexed, inclusive
---@return integer, integer 0,0 indexed, inclusive end
function M.mark_to_ext(row, col)
    return row - 1, col
end

---@audited 2026-07-03
---@param pos nvim-tools.Pos Modified in place!
---@return nvim-tools.Pos Reference to `pos`.
function M.mark_to_ext_pos(pos)
    pos[1] = pos[1] - 1
    return pos
end

---@param buf uinteger
---@param row uinteger 0 indexed
---@param col uinteger 0 indexed
---@return uinteger
function M.utf_advance_col(buf, row, col)
    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local diff = vim.str_utf_end(line, col + 1)
    return col + diff + 1
end

---@param buf uinteger
---@param row uinteger 0 indexed
---@param col uinteger 0 indexed
---@return uinteger
function M.utf_decrease_col(buf, row, col)
    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local diff = vim.str_utf_start(line, col)
    return col - 1 + diff
end

-------------------------------
-- MARK: Position Adjustment --
-------------------------------

---@param row integer 1 indexed
---@param col integer 1 indexed, inclusive
---@param buf integer
---@return integer, integer 1,1 indexed, inclusive
function M.adj_eval_pos(row, col, buf)
    if not api.nvim_buf_is_valid(buf) then
        error("Buffer " .. buf .. " is not valid")
    end

    local row_1 = math.min(row, api.nvim_buf_line_count(buf))
    local line = api.nvim_buf_get_lines(buf, row_1 - 1, row_1, false)[1]
    local len_line = #line

    local col_1 = math.max(math.min(col, len_line), 1)
    local distance = len_line > 0 and vim.str_utf_start(line, col_1) or 0
    return row_1, col_1 + distance
end

---@param row integer 0 indexed
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 0,0 indexed, inclusive
function M.adj_ext_pos(row, col, buf)
    if not api.nvim_buf_is_valid(buf) then
        error("Buffer " .. buf .. " is not valid")
    end

    local row_0 = math.min(row, api.nvim_buf_line_count(buf) - 1)
    local line = api.nvim_buf_get_lines(buf, row_0, row_0 + 1, false)[1]
    local len_line = #line

    local col_0 = math.max(math.min(col, len_line - 1), 0)
    local distance = len_line > 0 and vim.str_utf_start(line, col_0 + 1) or 0
    return row_0, col_0 + distance
end

---@param row integer 1 indexed
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1,0 indexed, inclusive
function M.adj_mark_pos(row, col, buf)
    if not api.nvim_buf_is_valid(buf) then
        error("Buffer " .. buf .. " is not valid")
    end

    local row_1 = math.max(math.min(row, api.nvim_buf_line_count(buf)), 1)
    local line = api.nvim_buf_get_lines(buf, row_1 - 1, row_1, false)[1]
    if line == nil then
        local err = table.concat({ row, col, buf, row_1, tostring(line) }, ", ")
        error(err)
    end

    local len_line = #line
    local col_0 = math.max(math.min(col, len_line - 1), 0)
    local distance = len_line > 0 and vim.str_utf_start(line, col_0 + 1) or 0
    return row_1, col_0 + distance
end

return M

local api = vim.api
local fn = vim.fn

local M = {}

---Various functions to work with positions.
---
---The underlying presumption here is, since the future vim.pos/vim.range APIs wrap each tuple in
---a metatable, we would like to have snippets of code that can be adapted to procedural contexts
---where we want reduced overhead.

---@param pos_1 string
---@param pos_2 string
---@param mode string
---@return Range4
function M.get_regionpos4(pos_1, pos_2, mode)
    local cur = fn.getpos(pos_1)
    local fin = fn.getpos(pos_2)

    ---@type string
    local selection = api.nvim_get_option_value("selection", { scope = "global" })
    local region_opts = { type = mode, exclusive = selection == "exclusive" }
    local region = fn.getregionpos(cur, fin, region_opts)
    return {
        region[1][1][2],
        region[1][1][3],
        region[#region][2][2],
        region[#region][2][3],
    }
end
-- TODO: I think if getpos fails it returns 0, 0, 0, 0 or something. If we see that, we should
-- return nil
-- TODO: mode should fall back to charwise
-- TODO: should be able to specify exclusive (nil checks opt)
-- TODO: pass mode/selection as opts table?

-------------------------------
-- MARK: Position Conversion --
-------------------------------

---Functions to convert positions
---
---These functions are, to a degree, more demonstrative than meant to be used. If these functions
---are meant to be used in a hot path, vim.validate should almost certainly be removed. Or, if,
---for example, you were bulk converting 0 indexed rows to 1 indexed rows, you would want to get
---buf_line_count once and then pass it to the function.
---
---Because these functions might be used by callers, row and col are passed directly rather than
---as a table. This is more flexible and avoids allocating more heap.

-- TODO: Double check that vim.validate is not load bearing
-- TODO: Make sure that zero return for prev_char_len works properly

---@param row integer 0 indexed, inclusive
---@param col_ integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 1 indexed, inclusive end
function M.api_to_eval(row, col_, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col_, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = math.min(row + 1, api.nvim_buf_get_line_count(buf))

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col__1 = math.min(col_ + 1, #line)
    local col_1 = col__1 - M.get_prev_char_len(line, col__1)

    return row_1, col_1
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 0 indexed, inclusive end
function M.api_to_ext(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col_1 = math.min(col + 1, #line)
    local prev_char_len = M.get_prev_char_len(line, col_1)

    return row, col - prev_char_len
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, exclusive
---@param buf integer
---@return integer, integer 0 indexed, inclusive end
function M.api_to_mark(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = math.min(row + 1, api.nvim_buf_line_count(buf))

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col_1 = math.min(col + 1, #line)
    local prev_char_len = M.get_prev_char_len(line, col_1)

    return row_1, col - prev_char_len
end

---@param row integer 1 indexed, inclusive
---@param col integer 1 indexed, inclusive
---@param buf integer
---@return integer, integer 0 indexed, exclusive end
function M.eval_to_api(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local b1 = string.byte(line, col)
    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col)

    return math.max(row - 1, 0), math.max(col - 1, 0) + char_len
end

---@param row integer 1 indexed, inclusive
---@param col integer 1 indexed, inclusive
---@return integer, integer 0 indexed, exclusive end
function M.eval_to_ext(row, col)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)

    return math.max(row - 1, 0), math.max(col - 1, 0)
end

---@param row integer 1 indexed, inclusive
---@param col integer 1 indexed, inclusive
---@return integer, integer 0 indexed, exclusive end
function M.eval_to_mark(row, col)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)

    return row, math.max(col - 1, 0)
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 0 indexed, exclusive end
function M.ext_to_api(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col_1 = math.min(col + 1, #line)
    local b1 = string.byte(line, col_1)

    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col_1)
    return row, col + char_len
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1, 0 indexed, inclusive
function M.ext_to_eval(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_1 = math.min(row + 1, api.nvim_buf_line_count(buf))
    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]

    return row_1, math.min(col + 1, #line)
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1, 0 indexed, inclusive
function M.ext_to_mark(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)
    return math.min(row + 1, api.nvim_buf_line_count(buf)), col
end

---@param row integer 1 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@return integer, integer 0 indexed, exclusive end
function M.mark_to_api(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local row_0 = math.max(row - 1, 0)

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    local col_1 = math.min(col + 1, #line)
    local b1 = string.byte(line, col_1)

    local get_char_len = require("nvim-tools.char").get_char_len
    local char_len = get_char_len(line, b1, col_1)

    return row_0, col + char_len
end

---@param row integer 0 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@param buf integer
---@return integer, integer 1, 0 indexed, inclusive
function M.mark_to_eval(row, col, buf)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    vim.validate("buf", buf, is_uint)

    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    return row, math.min(col + 1, #line)
end

---@param row integer 1 indexed, inclusive
---@param col integer 0 indexed, inclusive
---@return integer, integer 0, 0 indexed, inclusive
function M.mark_to_ext(row, col)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("row", row, is_uint)
    vim.validate("col", col, is_uint)
    return math.max(row - 1, 0), col
end

return M

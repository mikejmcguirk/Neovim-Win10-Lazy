local M = {}

M.INDENT = 4
M.DBL_INDENT = M.INDENT * 2
M.TPL_INDENT = M.INDENT * 3
M.INDENT_STR = string.rep(" ", M.INDENT)

M.NBSP = string.char(160)

M.TEXT_WIDTH = 78

return M

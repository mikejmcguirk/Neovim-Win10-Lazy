local M = {}

M.INDENT = 4
M.INDENT_STR = string.rep(" ", M.INDENT)
M.DBL_INDENT = M.INDENT * 2
M.DBL_INDENT_STR = string.rep(" ", M.DBL_INDENT)
M.TPL_INDENT = M.INDENT * 3
M.TPL_INDENT_STR = string.rep(" ", M.TPL_INDENT)

M.NBSP = string.char(160)

M.TEXT_WIDTH = 78
M.TAB_WIDTH = 8

return M

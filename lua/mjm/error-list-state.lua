local M = {}

M.last_grep = nil
-- FUTURE: This could be tied to the window the last lgrep was run on as well, but that would
-- limit flexibility. Don't want to make that change unless re-lgrepping the wrong window
-- turns out to be a footgun
M.last_lgrep = nil

return M

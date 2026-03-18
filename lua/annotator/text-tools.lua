local api = vim.api
local fn = vim.fn

local M = {}

---@return boolean
local function check_ft()
    return api.nvim_get_option_value("filetype", { buf = 0 }) == "lua"
end
-- TODO: Delete once proper comment string checking is added.

function M.add_annotation()
    if not check_ft() then
        return
    end

    local row = fn.line(".")
    local row_0 = row - 1
    local cur_line = api.nvim_get_current_line()

    local is_blank = string.match(cur_line, "^%s*$")
    local fin_row = is_blank and row or row_0
    local indent = require("mjm.utils").get_indent(row)
    local mark_text = table.concat({ string.rep(" ", indent), "-- MARK:  --" })

    api.nvim_buf_set_lines(0, row_0, fin_row, false, { mark_text })
    local new_col = #mark_text - 3
    api.nvim_win_set_cursor(0, { row, new_col })

    api.nvim_cmd({ cmd = "startinsert" }, {})
end
-- TODO: The specific annotation should be an opt. So you can select MARK, TODO, and so on.
-- LOW: It should be possible for this function to automatically add borders afterwards. The
-- problem is that the user shouldn't be trapped in this behavior. For <esc> users, this is not
-- an issue, as exiting insert mode with <Esc> would trigger the border addition, whereas <C-c>
-- would cancel it. I'm not sure what the best key is for <C-c> users by default (though obviously
-- it should be mappable to whatever the user wants). I'm also not sure how you detect what key
-- is used to exit insert mode. Could be on_key. Could be a temp keymap.

function M.add_borders()
    if not check_ft() then
        return
    end

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
    local indent = require("mjm.utils").get_indent(row)

    local trail_start = string.find(cur_line, "%s+$")
    local len_trail = trail_start and (len_cur_line - trail_start + 1) or 0
    local len_content = len_cur_line - indent - len_trail
    local border = string.rep(" ", indent) .. string.rep("-", len_content)

    ---@param line string?
    ---@return boolean
    local function is_border(line)
        if not line then
            return false
        end
        return line:match("^%s*-+$") ~= nil
    end

    -- Set each border individually to avoid overwriting extmarks and moving the cursor
    if is_border(line_above) and is_border(line_below) then
        api.nvim_buf_set_lines(0, row_0 - 1, row_0, false, { border })
        api.nvim_buf_set_lines(0, row_0 + 1, row_0 + 2, false, { border })
    else
        api.nvim_buf_set_lines(0, row_0, row_0, false, { border })
        api.nvim_buf_set_lines(0, row + 1, row + 1, false, { border })
    end
end
-- MID: If a border is only found above or below, we can check to see if that border can be used
-- for the current line. Check the line after the border to see if it is also a comment. If not,
-- then we know it is not attached to some other comment item and can be re-used. Note that we are
-- checking if the whole line is a comment, not if it merely contains one.
-- MID: This function could also, optionally, detect if there is whitespace after the border and
-- add it if not.

return M

-- TODO: In line with what's planned for farsight, this should be a private file with the
-- interfaces in init.lua
-- TODO: All calls to my personal indent function need to be replaced.
-- - Need to re-look at all the ftplugin indentexprs to see what input variable cases I'm not
-- covering.
-- TODO: These should have <Plug> maps created but not be set by default.
-- - Handling different buffer types needs to be dealt with under the hood. The user should be
-- able to set these as global mappings and get correct behavior.
--   - If commentstring is found but cannot be parsed, should be a no-op. Maybe with an error.
--   - If no commentstring, use //?
-- TODO: These should be able to read commentstring to determine how they work. commentstring can
-- be cached per buffer.
-- TODO: Rename to be an underline file.

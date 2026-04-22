local api = vim.api

local M = {}

-- vim.call is used here to avoid the indirection cost of vim.fn in hot paths

---Cannot use virtcol2col because that function is based on the screen virtual column, not the
---virtual column relative to the physical line. This makes visual selections incorrect.
---@param line string
---@param vcol integer
---The result of strcharlen() on the line. Passed as a param in case callers need to re-use it.
---@param charlen integer
---Returns:
---- Start byte
---- Fin byte
---- Char idx
---@return integer, integer, integer
function M.vcol_to_byte_bounds(line, vcol, charlen)
    local is_uint = require("nvim-tools.types").is_uint
    vim.validate("line", line, "string")
    vim.validate("vcol", vcol, is_uint)
    vim.validate("charlen", charlen, is_uint)

    if #line == 0 then
        -- charidx 0 on a 0 length line returns 0
        return 0, 0, 0
    end

    if charlen <= 1 then
        return 0, #line - 1, 0
    end

    vcol = math.min(vcol, vim.call("strdisplaywidth", line))
    if vcol <= 0 then
        return 0, 0, 0
    end

    for charidx = 0, charlen - 1 do
        local fin_byte = vim.call("byteidx", line, charidx + 1)
        local prefix = string.sub(line, 1, fin_byte)
        local prefix_vcol = vim.call("strdisplaywidth", prefix)

        if prefix_vcol >= vcol then
            return vim.call("byteidx", line, charidx), fin_byte - 1, charidx
        end
    end

    error("Unable to get byte bounds for vcol " .. vcol .. ' on line "' .. line('"'))
end
-- MAYBE: Use binary search. Because characters can contain multiple vcols, binary searching can
-- fail or create additional logic in weird ways.
-- MAYBE: For characters with variable widths, such as tabs or characters controlled by ambiwidth,
-- strdisplaywidth uses the current window settings. In both of the use cases I can think of for
-- this function (visual selection and quickfix), this is correct. If a use case comes up, some
-- kind of context switching can be added.

return M

local api = vim.api
local fn = vim.fn

local M = {}

---@return string
local function get_comment_start()
    local ft = api.nvim_get_option_value("filetype", { buf = 0 })
    return ft == "lua" and "--" or "//"
end

function M.jump(dir)
    local flags = dir == -1 and "bws" or "zws"
    local cstart = get_comment_start()
    local match = fn.search("\\C^\\s*\\M" .. cstart .. " MARK:", flags, 0, 500)
    if match ~= 0 then
        api.nvim_cmd({ cmd = "norm", args = { "zz" }, bang = true }, {})
    end

    local fdo = api.nvim_get_option_value("fdo", { scope = "global" })
    local jump, _, _ = string.find(fdo, "jump", 1, true)
    local all, _, _ = string.find(fdo, "all", 1, true)
    if jump or all then
        api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
    end
end
-- TODO: Instead of manual cstart by filetype, use comment string. Difficulty comes from
-- generalizing spacing + enclosed strings like markdown.

return M

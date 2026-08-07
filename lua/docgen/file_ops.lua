DEFAULT_TIMEOUT = 1000

local M = {}

---@return string?
function M.get_debug_path()
    local debug_info = debug.getinfo(2, "S")
    if not debug_info then
        debug_info = debug.getinfo(1, "S")
    end

    if not debug_info then
        return nil
    end

    return vim.call("fnamemodify", debug_info.source:gsub("^@", ""), ":p:h")
end

return M

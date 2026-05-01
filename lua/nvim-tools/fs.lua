local fs = vim.fs

local M = {}

---@param path string
---@return string norm_abs_path
function M.get_norm_abs(path)
    -- vim.fs.abspath might be changed to use fnamemodify :p:h, so use this for stability
    return fs.normalize(vim.call("fnamemodify", path, ":p"))
end

return M

local fn = vim.fn

local M = {}

---@param min uinteger
function M.check_nvim_version(min)
    local minor = fn.api_info().version.minor
    if minor >= min then
        vim.health.ok(("Neovim 0.%d"):format(minor))
    elseif minor == min - 1 then
        vim.health.warn(("Neovim 0.%d (out of date)"):format(minor))
    else
        vim.health.error(("Neovim 0.%d (unsupported)"):format(minor))
    end
end

return M

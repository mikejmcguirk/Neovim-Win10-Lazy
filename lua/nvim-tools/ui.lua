local api = vim.api
local fn = vim.fn

local M = {}

---Credit echasnovski
---@param tab uinteger
---@return integer
function M.get_echospace(tab)
    ---@type uinteger
    local columns = api.nvim_get_option_value("columns", { scope = "global" })
    ---@type uinteger
    local cmdheight = api.nvim_get_option_value("cmdheight", { tab = tab })
    return columns * math.max(cmdheight - 1, 0) + vim.v.echospace
end
-- TODO: The tab option is a v0.13 thing I think, so we need a fallback.

---@audited 2026-07-03
---@param opts? vim.ui.input.Opts
---@return boolean, string
function M.input(opts)
    local ok, result = pcall(fn.input, opts)
    if (not ok) and result == "Keyboard interrupt" then
        return true, ""
    else
        return ok, result
    end
end

return M

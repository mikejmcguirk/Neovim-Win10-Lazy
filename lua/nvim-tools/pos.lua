local api = vim.api
local fn = vim.fn

local M = {}

---@param pos_1 string
---@param pos_2 string
---@param mode string
---@return Range4
function M.get_regionpos4(pos_1, pos_2, mode)
    local cur = fn.getpos(pos_1)
    local fin = fn.getpos(pos_2)

    ---@type string
    local selection = api.nvim_get_option_value("selection", { scope = "global" })
    local region_opts = { type = mode, exclusive = selection == "exclusive" }
    local region = fn.getregionpos(cur, fin, region_opts)
    return {
        region[1][1][2],
        region[1][1][3],
        region[#region][2][2],
        region[#region][2][3],
    }
end

return M

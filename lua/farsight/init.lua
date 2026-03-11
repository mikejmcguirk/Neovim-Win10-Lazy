local M = {}

local default_config = {
    all = {
        timeout = 500,
    },
    csearch = {},
    live = {},
    static = {},
}

local cur_config = vim.deepcopy(default_config, true)
local proxy = {}
setmetatable(proxy, {
    __index = function(_, key)
        return cur_config[key]
    end,
    __newindex = function(_, key, _)
        error("Attempt to write to read-only field '" .. key .. "'", 2)
    end,
    __pairs = function()
        return pairs(cur_config)
    end,
})

---@param buf integer|table|boolean|nil
---@param new_config table|boolean|nil
function M.config(buf, new_config)
    return proxy
end
-- TODO: It is ergonomic for M.config to always return the proxy table. But then, if an empty
-- table config arg is a no-op (intuitive), what do you pass to reset the config?
-- Possible solution: Pass boolean true. This is a distinct type and something the user has to do
-- on purpose.

function M.get_default_config()
    return vim.deepcopy(default_config, true)
end

return M

-- TODO: The types in here should be built such that, for the nvim-tools version, you can have
-- placeholder types like DefaultConfig, CurrentConfig, NewConfig and they'll interface with
-- eachother correctly.

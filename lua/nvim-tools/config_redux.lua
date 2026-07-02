local M = {}

---@class nvim-tools.ConfigRedux
---@field _config table
---@field _defaults table
---@field _validators table
local Config = {}

-- TODO: When you create, you need a way to set defaults to either the default table or empty.
-- We don't want to write duplicate data to buf configs and we don't want buf defaults to merge
-- over the actual config settings.

---@generic K, V
---@param self nvim-tools.ConfigRedux
---@param k K
---@return V
Config.__index = function(self, k)
    local data = rawget(self, "_config")
    local value = rawget(data, k)
    return value and value or rawget(Config, k)
end
-- TODO: This needs to work so that, for execution against config, you can pull sub-sections
-- for merging.
--
-- TODO: One problem that the recursive config was meant to address was that you could get
-- properly validated sub-sections. Maybe you just take input sub-configs and normalize them
-- to the whole structure? Stupid but works.
--
-- Would also like a more sensical solution for like, nested getting. The current one is
-- impossible to understand.

Config.__newindex = function(_, _, _)
    do
    end
end
-- TODO: This is the thing I'm specifically interested in blocking.

---@param self nvim-tools.ConfigRedux
---@param t? table|nil
---@return table
function Config.__call(self, t)
    local _config = rawget(self, "_config")
    if t == nil then
        return _config
    end

    -- TODO: On one hand, it's a missed opportunity for empty table to not do something. On the
    -- other hand, we do not want to promiscuously set non-passed keys to defaults. Too
    -- confusing.

    -- TODO: run inputs against validators, then merge force
    _config = t -- TODO: Obviously fake.
    return _config
end

---@param self nvim-tools.ConfigRedux
function Config.get_default(self)
    return vim.deepcopy(rawget(self, "_default"), true)
end

---@param self nvim-tools.ConfigRedux
function Config.set_default(self)
    rawset(self, "_config", vim.deepcopy(rawget(self, "_default"), true))
end

return M

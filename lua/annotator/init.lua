local M = {}

------------------
-- MARK: Config --
------------------

---@class annotator.Config
---@field create_plug_integrations? boolean
---@field set_default_maps? boolean

---@class annotator.ConfigMeta
local Config_Meta = {
    ---@class annotator.configmeta.CreatePlugIntegrations
    create_plug_integrations = {
        default = true,
        ---@param val any
        ---@return boolean
        validator = function(val)
            return type(val) == "boolean"
        end,
    },
    ---@class annotator.configmeta.SetDefaultMaps
    set_default_maps = {
        default = true,
        ---@param val any
        ---@return boolean
        validator = function(val)
            return type(val) == "boolean"
        end,
    },
}

---@type annotator.Config
local config

local function reset_config()
    config = {}

    for k, v in pairs(Config_Meta) do
        config[k] = v.default
    end
end

reset_config()

---@param new_config annotator.Config
local function merge_new_config(new_config)
    for k, v in pairs(new_config) do
        local meta = Config_Meta[k]
        if meta then
            if meta.validator(v) then
                config[k] = v
            end
        end
    end
end

----------------------
-- MARK: Config API --
----------------------

---@param new_config boolean|annotator.Config|nil
function M.config(new_config)
    if type(new_config) == "boolean" and new_config == true then
        reset_config()
    elseif type(new_config) == "table" then
        merge_new_config(new_config)
    end

    return vim.deepcopy(config, true)
end

--------------------
-- MARK: Map APIs --
--------------------

function M.add_annotation()
    require("annotator.text-tools").add_annotation()
end

function M.add_borders()
    require("annotator.text-tools").add_borders()
end

function M.jump(dir)
    require("annotator._navigator").jump(dir)
end

---@param cur_buf? boolean
function M.fzf_lua_grep(cur_buf)
    if cur_buf == nil then
        cur_buf = true
    end

    require("annotator._integrations").fzf_lua_grep(cur_buf)
end

---@param cur_buf? boolean
function M.rancher_grep(cur_buf)
    if cur_buf == nil then
        cur_buf = true
    end

    require("annotator._integrations").rancher_grep(cur_buf)
end

return M

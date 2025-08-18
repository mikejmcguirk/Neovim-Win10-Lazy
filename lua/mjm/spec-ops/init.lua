local reg_utils = require("mjm.spec-ops.reg-utils")

--- @class GlobalConfig
--- @field reg_handler fun( ctx: reg_ctx): string[]

--- @class GlobalConfigOpts
--- @field reg_handler nil|"default"|"target_only"|"ring"|fun( ctx: reg_ctx): string[]

--- @class OpConfig
--- @field reg_handler nil|fun( ctx: reg_ctx): string[]

--- @class OpConfigOpts
--- @field reg_handler nil|"default"|"target_only"|"ring"|fun( ctx: reg_ctx): string[]

--- @class OptsList
--- @field change OpConfig
--- @field delete OpConfig
--- @field paste OpConfig
--- @field substitute OpConfig
--- @field yank OpConfig

--- @class OptsListOpts
--- @field change OpConfigOpts|nil
--- @field delete OpConfigOpts|nil
--- @field paste OpConfigOpts|nil
--- @field substitute OpConfigOpts|nil
--- @field yank OpConfigOpts|nil

--- @class SpecOpsConfig
--- @field global GlobalConfig
--- @field operators OptsList

--- @class SpecOpsConfigOpts
--- @field global GlobalConfigOpts|nil
--- @field operators OptsListOpts|nil

local M = {}

--- @type SpecOpsConfig
local defaults = {
    global = {
        reg_handler = reg_utils.get_handler(),
    },
    operators = {
        change = {
            reg_handler = nil,
        },
        delete = {
            reg_handler = nil,
        },
        paste = {
            reg_handler = nil,
        },
        substitute = {
            reg_handler = nil,
        },
        yank = {
            reg_handler = nil,
        },
    },
}

local config = nil --- @type SpecOpsConfig

--- @param opts SpecOpsConfigOpts
--- @return SpecOpsConfig
function M.setup(opts)
    opts = opts or {}

    opts.global = opts.global or {}

    opts.global.reg_handler = opts.global.reg_handler or "default"
    local reg_handler_is_function = type(opts.global.reg_handler) == "function"
    local reg_handler_is_string = type(opts.global.reg_handler) == "string"
    if not (reg_handler_is_function or reg_handler_is_string) then
        opts.global.reg_handler = "default"
    end

    if type(opts.global.reg_handler) ~= "function" then
        -- Already checked for nil and that the type is not a function
        --- @diagnostic disable: param-type-mismatch
        opts.global.reg_handler = reg_utils.get_handler(opts.global.reg_handler)
    end

    opts.operators = opts.operators or {}
    for _, o in pairs(opts.operators) do
        local op_reg_handler_is_fun = type(opts.global.reg_handler) == "function"
        local op_reg_handler_is_string = type(opts.global.reg_handler) == "string"
        if not (op_reg_handler_is_fun or op_reg_handler_is_string) then
            o.reg_handler = nil
        end

        if o.reg_handler and type(o.reg_handler) ~= "function" then
            o.reg_handler = reg_utils.get_handler(o.reg_handler)
        end
    end

    config = vim.tbl_extend("force", defaults, opts)

    return config
end

return M

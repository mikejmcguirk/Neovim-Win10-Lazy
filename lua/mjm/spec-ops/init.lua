local reg_utils = require("mjm.spec-ops.reg-utils")

--- @class GlobalConfig
--- @field reg_handler fun( ctx: reg_ctx): string[]

--- @class GlobalConfigOpts
--- @field reg_handler nil|"default"|"target_only"|"ring"|fun( ctx: reg_ctx): string[]

--- @class OpConfig
--- @field enabled boolean
--- @field setup_fun fun(opts: OpConfig)
--- @field reg_handler nil|fun( ctx: reg_ctx): string[]

--- @class OpConfigOpts
--- @field enabled boolean|nil
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
            enabled = false,
            setup_fun = require("mjm.spec-ops.yank").setup,
            reg_handler = nil,
        },
        delete = {
            enabled = false,
            setup_fun = require("mjm.spec-ops.yank").setup,
            reg_handler = nil,
        },
        paste = {
            enabled = false,
            setup_fun = require("mjm.spec-ops.yank").setup,
            reg_handler = nil,
        },
        substitute = {
            enabled = false,
            setup_fun = require("mjm.spec-ops.yank").setup,
            reg_handler = nil,
        },
        yank = {
            enabled = true,
            setup_fun = require("mjm.spec-ops.yank").setup,
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
    for _, v in pairs(opts.operators) do
        if v.enabled == true or v.enabled == nil then
            if v.reg_handler then
                local op_reg_handler_is_fun = type(v.reg_handler) == "function"
                local op_reg_handler_is_string = type(v.reg_handler) == "string"
                if not (op_reg_handler_is_fun or op_reg_handler_is_string) then
                    v.reg_handler = nil
                end

                if v.reg_handler and type(v.reg_handler) ~= "function" then
                    v.reg_handler = reg_utils.get_handler(v.reg_handler)
                end
            end
        end

        if v.setup_fun then
            v.setup_fun = nil
        end
    end

    config = vim.tbl_deep_extend("force", defaults, opts)

    for _, o in pairs(config.operators) do
        if o.enabled then
            if not o.reg_handler then
                o.reg_handler = config.global.reg_handler
            end

            o.setup_fun(o)
        end
    end

    return config
end

return M

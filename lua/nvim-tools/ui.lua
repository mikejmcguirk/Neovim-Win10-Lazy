local api = vim.api
local fn = vim.fn

local M = {}

---@param silent boolean
---@param msg any
---@param hl any
function M.echo_err(silent, msg, hl)
    if silent then
        return
    end

    if type(msg) ~= "string" then
        msg = ""
    end

    if type(hl) ~= "string" then
        hl = ""
    end

    local history = hl == "ErrorMsg" or hl == "WarningMsg"
    api.nvim_echo({ { msg, hl } }, history, {})
end

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

---@param opts? vim.ui.input.Opts
---@return boolean, string
function M.input(opts)
    vim.validate("opts", opts, "table", true)

    local ok, result = pcall(fn.input, opts)
    if (not ok) and result == "Keyboard interrupt" then
        return true, ""
    else
        return ok, result
    end
end

return M

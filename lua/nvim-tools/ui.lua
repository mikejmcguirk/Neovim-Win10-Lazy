local api = vim.api

local M = {}

---@generic T
---@param silent boolean
---@param msg T
---@param hl T
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
---@return integer
function M.get_echospace()
    local columns = api.nvim_get_option_value("columns", { scope = "global" })
    local cmdheight = api.nvim_get_option_value("cmdheight", {})
    return columns * math.max(cmdheight - 1, 0) + vim.v.echospace
end
-- PR: cmdheight is local to tabpage, but get_option_value does not have a tab key

return M

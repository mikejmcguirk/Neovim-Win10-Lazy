local api = vim.api
local fn = vim.fn

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

---@param prompt string
---@return boolean, string
function M.get_input(prompt)
    local ok, result = pcall(fn.input, { prompt = prompt, cancelreturn = "" })
    if (not ok) and result == "Keyboard interrupt" then
        return true, ""
    else
        return ok, result
    end
end

return M

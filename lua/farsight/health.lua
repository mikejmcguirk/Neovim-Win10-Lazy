local M = {}

function M.check()
    vim.health.start("Farsight")

    local nth = require("nvim-tools._health")
    nth.check_nvim_version(12)
end

return M

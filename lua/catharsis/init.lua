local M = {}

---@param opts? catharsis.rename.Opts
M.rename = function(opts)
    require("catharsis.rename")._dispatcher(opts)
end

return M

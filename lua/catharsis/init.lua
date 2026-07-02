-- local api = vim.api

local M = {}

-- do
--     local group = "catharsis.init"
--     api.nvim_create_autocmd("LspAttach", {
--         group = api.nvim_create_augroup(group, {}),
--         once = true,
--         callback = function()
--             require("catharsis.document_highlight")
--         end,
--     })
-- end

-- TODO: Needs to be handled with config so modules can check it before creating
-- autocmds.

---@param opts? catharsis.rename.Opts
M.rename = function(opts)
    require("catharsis.rename")._dispatcher(opts)
end

return M

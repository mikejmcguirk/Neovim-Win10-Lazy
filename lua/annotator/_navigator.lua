local api = vim.api
local fn = vim.fn

local M = {}

---@return boolean
local function check_ft()
    return api.nvim_get_option_value("filetype", { buf = 0 }) == "lua"
end
-- TODO: Delete once proper comment string checking is added.

function M.jump(dir)
    if not check_ft() then
        return
    end

    local flags = dir == -1 and "bws" or "zws"
    local match = fn.search("\\C^\\s*\\M-- MARK:", flags, 0, 500)
    if match ~= 0 then
        api.nvim_cmd({ cmd = "norm", args = { "zz" }, bang = true }, {})
    end

    local fdo = api.nvim_get_option_value("fdo", { scope = "global" })
    local jump, _, _ = string.find(fdo, "jump", 1, true)
    local all, _, _ = string.find(fdo, "all", 1, true)
    if jump or all then
        api.nvim_cmd({ cmd = "norm", args = { "zv" }, bang = true }, {})
    end
end
-- TODO: Using backwards search is inadvisable due to its quirks and perf issues.
-- - How does gitsigns do its [c]c navigation?
-- - Whatever method used needs to properly handle results on the cursor
-- TODO: This needs to handle the combination of any parsed comment string as well as user-custom
-- annotations.
-- TODO: zz and fold handling behavior should be in an on_jump callback.
-- - Document this
--   - Call out that that this means, if the user makes their own on_jump callback, they would
--   need to re-define zz and fold handling

return M

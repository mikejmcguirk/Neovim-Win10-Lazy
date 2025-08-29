vim.keymap.set("n", "gtt", function()
    if vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] then
        vim.treesitter.stop()
    else
        vim.treesitter.start()
    end
end)

vim.keymap.set("n", "gti", function()
    vim.api.nvim_cmd({ cmd = "Inspect" }, {})
end)

vim.keymap.set("n", "gtI", function()
    vim.api.nvim_cmd({ cmd = "InspectTree" }, {})
end)

vim.keymap.set("n", "gtee", function()
    vim.api.nvim_cmd({ cmd = "EditQuery" }, {})
end)

-- TODO: Re-create these commands from the Treesitter master branch

-- vim.keymap.set("n", "gtei", function()
--     if #vim.api.nvim_tabpage_list_wins(0) == 1 then
--         --- @diagnostic disable: missing-fields
--         vim.api.nvim_cmd({ cmd = "vsplit", mods = { split = "botright" } }, {})
--         vim.api.nvim_cmd({ cmd = "TSEditQuery", args = { "highlights" } }, {})
--     else
--         vim.api.nvim_cmd({ cmd = "TSEditQuery", args = { "highlights" } }, {})
--     end
-- end)
--
-- vim.keymap.set("n", "gten", function()
--     if #vim.api.nvim_tabpage_list_wins(0) == 1 then
--         --- @diagnostic disable: missing-fields
--         vim.api.nvim_cmd({ cmd = "vsplit", mods = { split = "botright" } }, {})
--         vim.api.nvim_cmd({ cmd = "TSEditQuery", args = { "indents" } }, {})
--     else
--         vim.api.nvim_cmd({ cmd = "TSEditQuery", args = { "indents" } }, {})
--     end
-- end)
--
-- vim.keymap.set("n", "gtej", function()
--     if #vim.api.nvim_tabpage_list_wins(0) == 1 then
--         --- @diagnostic disable: missing-fields
--         vim.api.nvim_cmd({ cmd = "vsplit", mods = { split = "botright" } }, {})
--         vim.api.nvim_cmd({ cmd = "TSEditQuery", args = { "injections" } }, {})
--     else
--         vim.api.nvim_cmd({ cmd = "TSEditQuery", args = { "injections" } }, {})
--     end
-- end)
--
-- vim.keymap.set("n", "gteo", function()
--     if #vim.api.nvim_tabpage_list_wins(0) == 1 then
--         --- @diagnostic disable: missing-fields
--         vim.api.nvim_cmd({ cmd = "vsplit", mods = { split = "botright" } }, {})
--         vim.api.nvim_cmd({ cmd = "TSEditQuery", args = { "folds" } }, {})
--     else
--         vim.api.nvim_cmd({ cmd = "TSEditQuery", args = { "folds" } }, {})
--     end
-- end)

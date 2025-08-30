-- TODO: Implement Helix style Treesitter navigation. We would want
-- - vie - Select current node
-- - vae - Select parent node
-- - [e and ]e navigate to next sibling (with wrap)
-- - In visual, would add to select I think, but check Text Objects
-- - A selection for next parent or previous parent
-- - I think with ie, to start it would pull the lowest level node at the cursor, then ae would
-- go up a level and ie would do down a level, like how an/in work
-- https://github.com/drybalka/tree-climber.nvim
-- https://github.com/David-Kunz/treesitter-unit

vim.keymap.set("n", "gtt", function()
    if vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] then
        vim.treesitter.stop()
    else
        vim.treesitter.start()
    end
end)

vim.keymap.set("n", "gti", function()
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

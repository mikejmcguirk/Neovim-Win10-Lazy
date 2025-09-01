local ut = require("mjm.utils")

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

--- @param query_group string
--- @return nil
--- Lifted from the old TS Master Branch
local function edit_query_file(query_group)
    local lang = vim.api.nvim_get_option_value("filetype", { buf = 0 })
    local files = vim.treesitter.query.get_files(lang, query_group, nil)

    if #files == 0 then
        vim.api.nvim_echo({ { "No query file found", "" } }, false, {})
        return
    elseif #files == 1 then
        require("mjm.utils").open_buf(files[1], { open = "vsplit" })
    else
        vim.ui.select(files, { prompt = "Select a file:" }, function(file)
            if file then
                require("mjm.utils").open_buf(file, { open = "vsplit" })
            end
        end)
    end
end

vim.keymap.set("n", "gteo", function()
    edit_query_file("folds")
end)

vim.keymap.set("n", "gtei", function()
    edit_query_file("highlights")
end)

vim.keymap.set("n", "gten", function()
    edit_query_file("indents")
end)

vim.keymap.set("n", "gtej", function()
    edit_query_file("injections")
end)

vim.keymap.set("n", "gtex", function()
    edit_query_file("textobjects")
end)

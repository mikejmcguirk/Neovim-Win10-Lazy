local api = vim.api

-- MID: Might be an Arboreal thing too - Create syntactic sugar for mapping ft to parser name
-- I don't think the edit code below works for sh
-- LOW: Also maybe an Arboreal thing - Create syntactic sugar for disabling default hl groups
-- AFAIK, because of how query files work, it's not possible to overwrite hl group queries, but
-- worth investigating

vim.keymap.set("n", "gtt", function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.treesitter.highlighter.active[buf] then
        vim.treesitter.stop(buf)
        if vim.g.syntax_on == 1 then api.nvim_cmd({ cmd = "syntax", args = { "off" } }, {}) end
    else
        vim.treesitter.start(buf)
    end
end)

vim.keymap.set("n", "gti", function()
    vim.api.nvim_cmd({ cmd = "InspectTree" }, {})
end)

vim.keymap.set("n", "gtee", function()
    vim.api.nvim_cmd({ cmd = "EditQuery" }, {})
end)

---@param ts_file string
---@return nil
--- Lifted from the old TS Master Branch
local function edit_query_file(ts_file)
    local lang = vim.api.nvim_get_option_value("filetype", { buf = 0 })
    local files = vim.treesitter.query.get_files(lang, ts_file, nil)
    if #files == 0 then
        vim.api.nvim_echo({ { "No query file found", "" } }, false, {})
        return
    elseif #files == 1 then
        require("mjm.utils").open_buf({ file = files[1] }, { open = "vsplit" })
    else
        vim.ui.select(files, { prompt = "Select a file:" }, function(file)
            if file then require("mjm.utils").open_buf({ file = file }, { open = "vsplit" }) end
        end)
    end
end

vim.keymap.set("n", "gted", function()
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

vim.keymap.set("n", "gteo", function()
    edit_query_file("textobjects")
end)

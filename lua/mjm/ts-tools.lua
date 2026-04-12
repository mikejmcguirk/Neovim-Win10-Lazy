local api = vim.api

vim.keymap.set("n", "<leader>tt", function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.treesitter.highlighter.active[buf] then
        vim.treesitter.stop(buf)
        if vim.g.syntax_on == 1 then
            api.nvim_cmd({ cmd = "syntax", args = { "off" } }, {})
        end
    else
        vim.treesitter.start(buf)
    end
end)

vim.keymap.set("n", "<leader>ti", function()
    vim.api.nvim_cmd({ cmd = "InspectTree" }, {})
end)

vim.keymap.set("n", "<leader>tee", function()
    vim.api.nvim_cmd({ cmd = "EditQuery" }, {})
end)

---@param file string
local function open_file_in_vsplit(file)
    local ntb = require("nvim-tools.buf")
    local ok, bufnr, err, hl = ntb.bufname_to_bufnr(file)
    if not ok then
        require("nvim-tools.ui").echo_err(false, err, hl)
    end

    local create_split = require("nvim-tools.win").create_split
    local win = create_split(0, nil, true, "vsplit")
    ntb.open_buf(win, bufnr, {
        clearjumps = true,
        force = "force",
        fold_cmd = "zv",
    })
end

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
        open_file_in_vsplit(files[1])
    else
        vim.ui.select(files, { prompt = "Select a file:" }, function(file)
            if file then
                open_file_in_vsplit(file)
            end
        end)
    end
end

vim.keymap.set("n", "<leader>ted", function()
    edit_query_file("folds")
end)

vim.keymap.set("n", "<leader>tei", function()
    edit_query_file("highlights")
end)

vim.keymap.set("n", "<leader>ten", function()
    edit_query_file("indents")
end)

vim.keymap.set("n", "<leader>tej", function()
    edit_query_file("injections")
end)

vim.keymap.set("n", "<leader>teo", function()
    edit_query_file("textobjects")
end)

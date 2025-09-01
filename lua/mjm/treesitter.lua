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

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("lua-disable-captures", { clear = true }),
    pattern = "lua",
    once = true,
    callback = function()
        local hl_query = vim.treesitter.query.get("lua", "highlights")
        if not hl_query then
            return
        end

        hl_query.query:disable_capture("comment.documentation") -- Semantic tokens handle
        hl_query.query:disable_capture("function.builtin")
        hl_query.query:disable_capture("module.builtin")
        hl_query.query:disable_capture("property")
        hl_query.query:disable_capture("punctuation.bracket")
        hl_query.query:disable_capture("punctuation.delimiter")
        hl_query.query:disable_capture("spell")
        hl_query.query:disable_capture("variable")
        hl_query.query:disable_capture("variable.member")
        hl_query.query:disable_capture("variable.parameter")
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("rust-disable-captures", { clear = true }),
    pattern = "rust",
    once = true,
    callback = function()
        local hl_query = vim.treesitter.query.get("rust", "highlights")
        if not hl_query then
            return
        end

        hl_query.query:disable_capture("constant.builtin") -- Semantic Tokens handle
        hl_query.query:disable_capture("punctuation.delimiter")
        hl_query.query:disable_capture("spell")
        hl_query.query:disable_capture("variable")
        hl_query.query:disable_capture("variable.member")
        hl_query.query:disable_capture("variable.parameter")
        hl_query.query:disable_capture("type.builtin")
    end,
})

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("rust-disable-captures-lsp", { clear = true }),
    callback = function(ev)
        local ft = vim.api.nvim_get_option_value("filetype", { buf = ev.buf })

        if ft == "rust" then
            local hl_query = vim.treesitter.query.get("rust", "highlights")
            if not hl_query then
                return
            end

            hl_query.query:disable_capture("function")
            hl_query.query:disable_capture("function.call")
            hl_query.query:disable_capture("function.macro")
            hl_query.query:disable_capture("_identifier")
            hl_query.query:disable_capture("keyword.debug")
            hl_query.query:disable_capture("keyword.exception")
            hl_query.query:disable_capture("string")
            hl_query.query:disable_capture("type")

            vim.api.nvim_del_augroup_by_name("rust-disable-captures-lsp")
        end
    end,
})

local api = vim.api

require("farsight.plugin")

api.nvim_set_hl(0, "FarsightJump", { reverse = true })
api.nvim_set_hl(0, "FarsightJumpAhead", { underdouble = true })
api.nvim_set_hl(0, "FarsightJumpTarget", { reverse = true })

api.nvim_set_hl(0, "FarsightCsearch1st", { reverse = true })
api.nvim_set_hl(0, "FarsightCsearch2nd", { undercurl = true })
api.nvim_set_hl(0, "FarsightCsearch3rd", { underdouble = true })

api.nvim_set_var("farsight_csearch_all_tokens", true)

--------------

require("annotator.plugin")
vim.keymap.set("n", "<leader>-k", "<Plug>(annotator-add-mark)")
vim.keymap.set("n", "<leader>-K", "<Plug>(annotator-add-borders)")
vim.keymap.set("n", "<leader>fnk", "<Plug>(annotator-fzf-lua-grep-curbuf)")
vim.keymap.set("n", "<leader>fnK", "<Plug>(annotator-fzf-lua-grep-cwd)")
vim.keymap.set("n", "<leader>fnm", "<Plug>(annotator-fzf-lua-grep-curbuf-luacats)")
vim.keymap.set("n", "<leader>qgk", "<Plug>(annotator-rancher-grep-cwd)")
vim.keymap.set("n", "<leader>lgk", "<Plug>(annotator-rancher-grep-curbuf)")

--------------

vim.keymap.set({ "n", "x" }, "y", function()
    return require("specops").yank()
end, { expr = true })

vim.keymap.set({ "n", "x" }, "Y", function()
    return require("specops").yank() .. "$"
end, { expr = true })

vim.keymap.set({ "n", "x" }, "<M-y>", function()
    return '"+' .. require("specops").yank()
end, { expr = true })

vim.keymap.set({ "n", "x" }, "<M-Y>", function()
    return '"+' .. require("specops").yank() .. "$"
end, { expr = true })

vim.keymap.set("x", "p", "P")
vim.keymap.set("x", "P", "p")
vim.keymap.set("n", "<M-p>", '"+p')
vim.keymap.set("n", "<M-P>", '"+P')
vim.keymap.set("x", "<M-p>", '"+P')
vim.keymap.set("x", "<M-P>", '"+p')

vim.keymap.set("n", "[p", '<Cmd>exe "iput! " . v:register<CR>')
vim.keymap.set("n", "]p", '<Cmd>exe "iput "  . v:register<CR>')
vim.keymap.set("n", "[<M-p>", '<Cmd>exe "iput! " . "+"<CR>')
vim.keymap.set("n", "]<M-p>", '<Cmd>exe "iput "  . "+"<CR>')

vim.keymap.set({ "n", "x" }, "<M-d>", '"_d')
vim.keymap.set({ "n", "x" }, "<M-D>", '"_D')
vim.keymap.set({ "n", "x" }, "<M-c>", '"_c')
vim.keymap.set({ "n", "x" }, "<M-C>", '"_C')

----------------

require("catharsis.plugin")

---@type table<string, fun(client_id: integer, action: lsp.Command|lsp.CodeAction):boolean>
local action_filters = {
    ---@param _ integer
    ---@param action lsp.Command|lsp.CodeAction
    lua = function(_, action)
        if action.disabled then
            return false
        end

        local title = action.title ---@type string|nil
        if not title then
            return true
        end

        if string.find(title, "use cast to remove nil", 1, true) ~= nil then
            return false
        end

        return string.find(title, "Change to parameter", 1, true) == nil
    end,

    ---@param _ integer
    ---@param action lsp.Command|lsp.CodeAction
    python = function(_, action)
        if action.disabled then
            return false
        end

        local title = action.title ---@type string|nil
        if not title then
            return true
        end

        local fix_all_str = "Ruff: Fix all auto-fixable problems"
        local fix_all = string.find(title, fix_all_str, 1, true)
        if fix_all then
            return false
        end

        local organize_str = "Ruff: Organize imports"
        local organize = string.find(title, organize_str, 1, true)
        if organize then
            return false
        end

        return true
    end,
}

api.nvim_create_autocmd("LspAttach", {
    group = api.nvim_create_augroup("mjm.catharsis", {}),
    callback = function(ev)
        local buf = ev.buf
        local func = action_filters[api.nvim_get_option_value("filetype", { buf = buf })]
        if func ~= nil then
            local catharsis = require("catharsis")
            catharsis.buf_config[buf]({
                lampshade = {
                    action_filter = func,
                },
            })
        end
    end,
})

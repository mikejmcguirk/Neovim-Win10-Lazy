-- FUTURE: Worth exploring mrcjkb/rustaceanvim and rust-lang/rust.vim
-- The former unlocks more features of rust-analyzer, the latter does some basic formatting

vim.keymap.set("i", ";", ";<C-g>u", { silent = true })

---@param pragma string
---@return nil
local add_pragma = function(pragma)
    local line = vim.api.nvim_get_current_line() ---@type string
    if not line:match("^%s*$") then
        vim.api.nvim_echo({ { "Line is not blank" } }, false, {})
        return
    end

    local row = vim.api.nvim_win_get_cursor(0)[1] ---@type integer
    local indent = require("mjm.utils").get_indent(row) or 0 ---@type integer
    vim.api.nvim_buf_set_text(0, row - 1, 0, row - 1, #line, { string.rep(" ", indent) .. pragma })

    vim.api.nvim_win_set_cursor(0, { row, #vim.api.nvim_get_current_line() - 2 })
    vim.cmd("startinsert")
end

vim.keymap.set("n", "<leader>-a", function()
    add_pragma("#[allow()]")
end)

vim.keymap.set("n", "<leader>-c", function()
    add_pragma("#[cfg()]")
end)

vim.keymap.set("n", "<leader>-d", function()
    add_pragma("#[derive()]")
end)

vim.keymap.set("n", "<leader>-e", function()
    add_pragma("#[expect()]")
end)

mjm.lsp.start(vim.lsp.config["rust_analyzer"], { bufnr = 0 })

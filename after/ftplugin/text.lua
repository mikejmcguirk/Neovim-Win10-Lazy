local ut = require("mjm.utils")

vim.opt_local.wrap = true
vim.opt_local.spell = true
vim.opt_local.colorcolumn = ""
vim.opt_local.sidescrolloff = 12

vim.keymap.set("i", ",", ",<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", ".", ".<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", ":", ":<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "-", "-<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "?", "?<C-g>u", { silent = true, buffer = true })
vim.keymap.set("i", "!", "!<C-g>u", { silent = true, buffer = true })

local norm_pastes = {
    { "p", "p", '"' },
    { "<leader>p", '"+p', "+" },
    { "P", "P", '"' },
    { "<leader>P", '"+P', "+" },
}
-- TODO: Don't just repeat the code from keymap.lua
-- Just repasted here for now because automated indenting in text files creates cooked results
for _, map in pairs(norm_pastes) do
    vim.keymap.set("n", map[1], function()
        if not ut.check_modifiable() then
            return
        end

        local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_set_mark(0, "z", cur_row, cur_col, {})

        local status, result = pcall(function()
            vim.api.nvim_exec2("silent norm! " .. vim.v.count1 .. map[2], {})
        end) ---@type boolean, unknown|nil
        if not status then
            if type(result) == "string" then
                vim.api.nvim_err_writeln(result)
            else
                vim.api.nvim_err_writeln("Unknown error when pasting")
            end
            return
        end

        vim.api.nvim_exec2("silent norm! `z", {})
    end, { silent = true })
end

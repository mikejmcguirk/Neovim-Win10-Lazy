-- MAYBE: This looks fairly simple to do yourself, but I don't want to put in the effort + add
-- maintenance cost unless this ends up being something I use a lot
-- Don't want to make that determination until testing in other languages
-- https://github.com/MariaSolOs/dotfiles/blob/main/.config/nvim/lua/lightbulb.lua
-- Something useful to do would be to update the drawing of the lightbulb when the LSP request
-- completes

require("nvim-lightbulb").setup({
    autocmd = { enabled = false },
    code_lenses = false,
    float = { enabled = false },
    hide_in_unfocused_buffer = false, -- Handled by autocmd below
    number = { enabled = false },
    line = { enabled = false },
    sign = { enabled = false },
    status_text = { enabled = false },
    virtual_text = { enabled = true, text = "󰌶", lens_text = "🔎" },
})

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("attach-lightbulb", { clear = true }),
    callback = function(ev)
        local group_name = "lightbulb-" .. tostring(ev.buf)
        local lb_buf_group = vim.api.nvim_create_augroup(group_name, { clear = true })

        -- The default autocmds change the updatetime option and operate across all buffers
        vim.api.nvim_create_autocmd({ "CursorMoved", "TextChanged", "InsertLeave" }, {
            group = lb_buf_group,
            buffer = ev.buf,
            desc = "lua require('nvim-lightbulb').update_lightbulb()",
            callback = require("nvim-lightbulb").update_lightbulb,
        })

        -- Set up autocmd for clear_lightbulb if configured
        vim.api.nvim_create_autocmd({ "InsertEnter", "WinLeave" }, {
            group = lb_buf_group,
            desc = "lua require('nvim-lightbulb').clear_lightbulb()",
            callback = function()
                require("nvim-lightbulb").clear_lightbulb(ev.buf)
            end,
        })

        vim.api.nvim_create_autocmd("LspDetach", {
            group = lb_buf_group,
            buffer = ev.buf,
            desc = "Detach code action lightbulb",
            callback = function()
                pcall(vim.api.nvim_del_augroup_by_name, group_name)
            end,
        })
    end,
})

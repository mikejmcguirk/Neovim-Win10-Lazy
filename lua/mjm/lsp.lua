local ut = require("mjm.utils")

vim.keymap.set("n", "[D", function()
    vim.diagnostic.goto_prev({ severity = "ERROR" })
end)
vim.keymap.set("n", "]D", function()
    vim.diagnostic.goto_next({ severity = "ERROR" })
end)

local handler_border = {
    border = "single",
    style = "minimal",
}
local default_diag_cfg = {
    severity_sort = true,
    float = vim.tbl_extend("force", { source = "always" }, handler_border),
    virtual_text = {
        severity = {
            min = vim.diagnostic.severity.HINT,
        },
    },
    signs = {
        severity = {
            min = vim.diagnostic.severity.HINT,
        },
    },
}
vim.diagnostic.config(default_diag_cfg)
-- LSP windows use floating windows, documented in nvim_open_win
-- The borders use the "FloatBorder" highlight group
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, handler_border)
vim.lsp.handlers["textDocument/signatureHelp"] =
    vim.lsp.with(vim.lsp.handlers.signature_help, handler_border)

vim.lsp.set_log_level("ERROR")

vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("LSP_Augroup", { clear = true }),
    callback = function(ev)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = ev.buf })
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = ev.buf })
        vim.keymap.set("n", "gI", vim.lsp.buf.implementation, { buffer = ev.buf })
        vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, { buffer = ev.buf })
        vim.keymap.set("n", "gr", vim.lsp.buf.references, { buffer = ev.buf })

        vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, { buffer = ev.buf })
        vim.keymap.set("n", "<leader>vh", vim.lsp.buf.document_highlight, { buffer = ev.buf })

        vim.keymap.set("n", "<leader>va", vim.lsp.buf.add_workspace_folder, { buffer = ev.buf })
        vim.keymap.set("n", "<leader>vd", vim.lsp.buf.remove_workspace_folder, { buffer = ev.buf })
        vim.keymap.set("n", "<leader>vf", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, { buffer = ev.buf })

        vim.keymap.set("n", "<leader>vr", function()
            local input = ut.get_user_input("Rename: ")
            if #input > 0 then
                vim.lsp.buf.rename(input)
            end
        end, { buffer = ev.buf })
        vim.keymap.set({ "n", "v" }, "<leader>vc", vim.lsp.buf.code_action, { buffer = ev.buf })
    end,
})

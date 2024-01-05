vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next)

vim.keymap.set("n", "[D", function()
    vim.diagnostic.goto_prev({ severity = "ERROR" })
end)

vim.keymap.set("n", "]D", function()
    vim.diagnostic.goto_next({ severity = "ERROR" })
end)

vim.keymap.set("n", "<leader>vl", vim.diagnostic.open_float)

local handler_border = {
    border = "single",
    style = "minimal",
}

local default_diag_cfg = {
    severity_sort = true,
    float = vim.tbl_extend("force", { source = "always" }, handler_border),
    virtual_text = true,
    signs = true,
}

vim.diagnostic.config(default_diag_cfg)

vim.keymap.set("n", "<leader>vi", function()
    vim.diagnostic.config(default_diag_cfg)
end)

local diag_cfg_warn = vim.tbl_deep_extend("force", default_diag_cfg, {
    virtual_text = {
        severity = {
            min = vim.diagnostic.severity.WARN,
        },
    },
    signs = {
        severity = {
            min = vim.diagnostic.severity.WARN,
        },
    },
})

vim.keymap.set("n", "<leader>vw", function()
    vim.diagnostic.config(diag_cfg_warn)
end)

vim.keymap.set("n", "<leader>vt", function()
    local cur_diag_cfg = vim.diagnostic.config()
    local min_diag_level = nil

    if type(cur_diag_cfg.virtual_text) == "table" and cur_diag_cfg.virtual_text.severity then
        min_diag_level = cur_diag_cfg.virtual_text.severity.min
    end

    if min_diag_level == nil then
        vim.diagnostic.config(diag_cfg_warn)
    else
        vim.diagnostic.config(default_diag_cfg)
    end
end)

-- LSP windows use floating windows, documented in nvim_open_win
-- The borders use the "FloatBorder" highlight group

vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, handler_border)
vim.lsp.handlers["textDocument/signatureHelp"] =
    vim.lsp.with(vim.lsp.handlers.signature_help, handler_border)

vim.lsp.set_log_level("ERROR")

vim.api.nvim_create_autocmd("LspAttach", {
    group = LSP_Augroup,
    callback = function(ev)
        local lsp_opts = { buffer = ev.buf }

        vim.keymap.set("n", "gd", vim.lsp.buf.definition, lsp_opts)
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, lsp_opts)
        vim.keymap.set("n", "gI", vim.lsp.buf.implementation, lsp_opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, lsp_opts)
        vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, lsp_opts)

        vim.keymap.set("n", "K", vim.lsp.buf.hover, lsp_opts)
        vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, lsp_opts)

        vim.keymap.set("n", "<leader>va", vim.lsp.buf.add_workspace_folder, lsp_opts)
        vim.keymap.set("n", "<leader>vd", vim.lsp.buf.remove_workspace_folder, lsp_opts)
        vim.keymap.set("n", "<leader>vh", vim.lsp.buf.document_highlight, lsp_opts)

        vim.keymap.set("n", "<leader>vf", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, lsp_opts)

        vim.keymap.set("n", "<leader>vr", function()
            vim.ui.input({ prompt = "Rename: " }, function(input)
                if input and #input > 0 then
                    vim.lsp.buf.rename(input)
                end

                vim.api.nvim_cmd({ cmd = "echo", args = { "''" } }, {})
            end)
        end, lsp_opts)

        vim.keymap.set({ "n", "v" }, "<leader>vc", vim.lsp.buf.code_action, lsp_opts)
    end,
})

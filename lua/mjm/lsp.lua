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
local lsp_group = vim.api.nvim_create_augroup("LSP_Augroup", { clear = true })

vim.keymap.set("n", "<leader>vp", function()
    local clients = vim.lsp.get_active_clients()

    local capabilities = vim.tbl_map(function(client)
        return client.server_capabilities
    end, clients)

    local buf = vim.api.nvim_create_buf(false, true)
    local capabilities_to_print = vim.split(vim.inspect(capabilities), "\n")
    vim.api.nvim_buf_set_lines(buf, 0, 0, true, capabilities_to_print)
    vim.api.nvim_set_current_buf(buf)
end)

vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = function(ev)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = ev.buf })
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = ev.buf })
        vim.keymap.set("n", "gI", vim.lsp.buf.implementation, { buffer = ev.buf })
        vim.keymap.set("n", "gr", vim.lsp.buf.references, { buffer = ev.buf })
        vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, { buffer = ev.buf })

        vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, { buffer = ev.buf })

        vim.keymap.set("n", "<leader>va", vim.lsp.buf.add_workspace_folder, { buffer = ev.buf })
        vim.keymap.set("n", "<leader>vd", vim.lsp.buf.remove_workspace_folder, { buffer = ev.buf })
        vim.keymap.set("n", "<leader>vh", vim.lsp.buf.document_highlight, { buffer = ev.buf })

        vim.keymap.set("n", "<leader>vf", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, { buffer = ev.buf })

        vim.keymap.set("n", "<leader>vr", function()
            vim.ui.input({ prompt = "Rename: " }, function(input)
                if input and #input > 0 then
                    vim.lsp.buf.rename(input)
                end

                vim.api.nvim_exec2("echo ''", {})
            end)
        end, { buffer = ev.buf })

        vim.keymap.set({ "n", "v" }, "<leader>vc", vim.lsp.buf.code_action, { buffer = ev.buf })
    end,
})

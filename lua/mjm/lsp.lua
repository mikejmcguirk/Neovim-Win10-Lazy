local ut = require("mjm.utils")

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

local lsp_group = vim.api.nvim_create_augroup("LSP_Augroup", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = function(ev)
        local toggle_virtual_text = function()
            local current_config = vim.diagnostic.config() or {}
            local new_virtual_text = not current_config.virtual_text

            vim.diagnostic.config({ virtual_text = new_virtual_text })

            if new_virtual_text then
                print("Diagnostic virtual text enabled")
            else
                print("Diagnostic virtual text disabled")
            end
        end
        vim.keymap.set("n", "<leader>vd", toggle_virtual_text)

        vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = ev.buf })
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = ev.buf })
        vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, { buffer = ev.buf })

        vim.keymap.set("n", "<leader>vh", vim.lsp.buf.document_highlight, { buffer = ev.buf })

        vim.keymap.set("n", "<leader>va", vim.lsp.buf.add_workspace_folder, { buffer = ev.buf })
        vim.keymap.set("n", "<leader>vo", vim.lsp.buf.remove_workspace_folder, { buffer = ev.buf })
        vim.keymap.set("n", "<leader>vf", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, { buffer = ev.buf })

        vim.keymap.set("n", "grn", function()
            local bufnr = vim.api.nvim_get_current_buf()
            local clients = vim.lsp.get_clients({
                bufnr = bufnr,
                method = "textDocument/rename",
            })
            if #clients == 0 then
                vim.notify("[LSP] Rename, no language servers available with rename capability.")
                return
            end

            local client = clients[1]
            local win = vim.api.nvim_get_current_win()
            local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
            local do_rename = function()
                local input = ut.get_user_input("Rename: ")
                if string.find(input, "%s") then
                    vim.notify(string.format("The name '%s' contains spaces", input))
                elseif #input > 0 then
                    vim.lsp.buf.rename(input)
                end
            end

            if client.supports_method("textDocument/prepareRename") then
                client.request("textDocument/prepareRename", params, function(err, result)
                    if err or not result then
                        vim.notify("Nothing to rename here", vim.log.levels.INFO)
                        return
                    else
                        do_rename()
                    end
                end, bufnr)
            else
                do_rename()
            end
        end, { buffer = ev.buf })

        -- Future default LSP keymappings. Remove when pushed to release version
        vim.keymap.set("n", "gri", vim.lsp.buf.implementation, { buffer = ev.buf })
        vim.keymap.set("n", "grr", vim.lsp.buf.references, { buffer = ev.buf })
        vim.keymap.set({ "n", "x" }, "gra", vim.lsp.buf.code_action, { buffer = ev.buf })
        vim.keymap.set("n", "gO", vim.lsp.buf.document_symbol, { buffer = ev.buf })
        vim.keymap.set("n", "<C-s>", vim.lsp.buf.signature_help, { buffer = ev.buf })
    end,
})

vim.api.nvim_create_autocmd("BufUnload", {
    group = lsp_group,
    callback = function(ev)
        local bufnr = ev.buf
        local clients = vim.lsp.get_clients({ bufnr = bufnr })
        if not clients or vim.tbl_isempty(clients) then
            return
        end

        for _, client in pairs(clients) do
            local attached_buffers = vim.tbl_filter(function(buf_nbr)
                return buf_nbr ~= bufnr
            end, vim.tbl_keys(client.attached_buffers))

            if vim.tbl_isempty(attached_buffers) then
                vim.lsp.stop_client(client.id)
            end
        end
    end,
})

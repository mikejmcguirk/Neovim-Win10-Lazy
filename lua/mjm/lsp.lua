-- Note: Not using the built-in LSP autocompletion because it doesn't bring in other sources

local ut = require("mjm.utils")

vim.lsp.set_log_level("ERROR")

local lsp_group = vim.api.nvim_create_augroup("LSP_Augroup", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = function(ev)
        local buf = ev.buf
        local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))

        -- Overwrite vim defaults
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = buf })
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = buf })
        if client.server_capabilities.implementationProvider then
            vim.keymap.set("n", "gI", vim.lsp.buf.implementation, { buffer = buf })
        end

        if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            vim.keymap.set("n", "grl", function()
                vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }))
            end)
        end

        -- Overwrite Nvim defaults (:help lsp-defaults)
        vim.keymap.set("n", "grn", function()
            local input = ut.get_input("Rename: ")
            if string.find(input, "%s") then
                vim.notify(string.format("The name '%s' contains spaces", input))
            elseif #input > 0 then
                vim.lsp.buf.rename(input)
            end
        end, { buffer = buf })

        vim.keymap.set("n", "grr", function()
            vim.lsp.buf.references({ includeDeclaration = false })
        end, { buffer = buf })

        vim.keymap.set("n", "K", function()
            vim.lsp.buf.hover({ border = Border })
        end, { buffer = buf, desc = "vim.lsp.buf.hover()" })

        vim.keymap.set({ "i", "s" }, "<C-S>", function()
            vim.lsp.buf.signature_help({ border = Border })
        end, { buffer = buf, desc = "vim.lsp.buf.signature_help()" })

        -- Patternful with the rest of the defaults
        -- TODO: This will be added as a default in the future
        vim.keymap.set("n", "grt", vim.lsp.buf.type_definition, { buffer = buf })
        -- Kickstart mapping
        vim.keymap.set("n", "gW", vim.lsp.buf.workspace_symbol, { buffer = buf })
        vim.keymap.set("n", "grh", vim.lsp.buf.document_highlight, { buffer = buf })
        vim.keymap.set("n", "grf", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, { buffer = buf })

        -- Unsure what to do with these
        -- vim.keymap.set("n", "<leader>va", vim.lsp.buf.add_workspace_folder, { buffer = buf })
        -- vim.keymap.set("n", "<leader>vo", vim.lsp.buf.remove_workspace_folder, { buffer = buf })
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

vim.lsp.enable("bashls")
vim.lsp.enable("lua_ls")
vim.lsp.enable("taplo")

vim.lsp.config("rust_analyzer", {
    settings = {
        ["rust-analyzer"] = {
            checkOnSave = true,
            check = {
                command = "clippy",
            },
            lens = {
                enable = true,
            },
        },
    },
})

vim.lsp.enable("rust_analyzer")

vim.lsp.enable("gopls")
vim.lsp.enable("golangci_lint_ls")

vim.lsp.enable("html")
vim.lsp.enable("cssls")

vim.lsp.enable("ruff")
-- Ruff is not feature-complete enough to replace pylsp
vim.lsp.config("pylsp", {
    settings = {
        pylsp = {
            plugins = {
                pycodestyle = {
                    maxLineLength = 99,
                    ignore = {
                        "E201",
                        "E202",
                        "E203", -- Whitespace before ':' (Contradicts ruff formatter)
                        "E211",
                        "E225", -- Missing whitespace around operator
                        "E226", -- Missing whitespace around arithmetic operator
                        "E231", -- Missing whitespace after ,
                        "E261",
                        "E262",
                        "E265",
                        "E302",
                        "E303",
                        "E305",
                        "E501",
                        "E741", -- Ambiguous variable name
                        "W291", -- Trailing whitespace
                        "W292", -- No newline at end of file
                        "W293",
                        "W391",
                        "W503", -- Line break after binary operator
                    },
                },
            },
        },
    },
})

vim.lsp.enable("pylsp")

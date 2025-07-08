-- Note: Not using the built-in LSP autocompletion because it doesn't bring in other sources

local ut = require("mjm.utils")

vim.lsp.set_log_level("ERROR")

local border = "single" -- "FloatBorder" highlight group
local main_diag_cfg = {
    severity_sort = true,
    float = { source = "always", border = border },
    signs = {
        severity = {
            min = vim.diagnostic.severity.HINT,
        },
    },
}

local virtual_text_cfg = {
    virtual_text = {
        severity = {
            min = vim.diagnostic.severity.HINT,
        },
        current_line = true,
    },
    virtual_lines = false,
}

local virtual_lines_cfg = {
    virtual_text = false,
    virtual_lines = { current_line = true },
}

local default_diag_cfg = vim.tbl_extend("force", main_diag_cfg, virtual_text_cfg)
local alt_diag_cfg = vim.tbl_extend("force", main_diag_cfg, virtual_lines_cfg)
vim.diagnostic.config(default_diag_cfg)
vim.keymap.set("n", "grd", function()
    local current_config = vim.diagnostic.config() or {}
    if current_config.virtual_lines == false then
        vim.diagnostic.config(alt_diag_cfg)
    else
        vim.diagnostic.config(default_diag_cfg)
    end
end)

local lsp_group = vim.api.nvim_create_augroup("LSP_Augroup", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_group,
    callback = function(ev)
        local buf = ev.buf

        -- Overwrite vim defaults
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = buf })
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = buf })

        -- Overwrite Nvim defaults (:help lsp-defaults)
        vim.keymap.set("n", "grn", function()
            local input = ut.get_input("Rename: ")
            if string.find(input, "%s") then
                vim.notify(string.format("The name '%s' contains spaces", input))
            elseif #input > 0 then
                vim.lsp.buf.rename(input)
            end
        end, { buffer = buf })

        vim.keymap.set("n", "K", function()
            vim.lsp.buf.hover({ border = border })
        end, { buffer = buf, desc = "vim.lsp.buf.hover()" })

        vim.keymap.set({ "i", "s" }, "<C-S>", function()
            vim.lsp.buf.signature_help({ border = border })
        end, { buffer = buf, desc = "vim.lsp.buf.signature_help()" })

        -- Patternful with the rest of the defaults
        vim.keymap.set("n", "grt", vim.lsp.buf.type_definition, { buffer = buf })
        vim.keymap.set("n", "grf", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, { buffer = buf })

        -- Unsure what to do with these
        -- vim.keymap.set("n", "<leader>vh", vim.lsp.buf.document_highlight, { buffer = buf })
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

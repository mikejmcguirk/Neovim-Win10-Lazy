Opts = { silent = true }

Lsp_Capabilities = vim.lsp.protocol.make_client_capabilities()
LSP_Augroup = vim.api.nvim_create_augroup("LSP_Augroup", { clear = true })

Env_Copilot_Node = os.getenv("NvimCopilotNode")
Env_Disable_Copilot = os.getenv("DisableCopilot")

Env_Main_Browser = os.getenv("MainBrowser")

Env_Theme = os.getenv("NvimTheme")

Env_OmniSharp_DLL = os.getenv("OmniSharpDLL")

Lsp_Capabilities = vim.lsp.protocol.make_client_capabilities()
LSP_Augroup = vim.api.nvim_create_augroup("LSP_Augroup", { clear = true })

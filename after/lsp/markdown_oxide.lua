local capabilities = require("blink.cmp").get_lsp_capabilities()
return {
    capabilities = vim.tbl_deep_extend("force", capabilities, {
        workspace = {
            didChangeWatchedFiles = {
                dynamicRegistration = true,
            },
        },
    }),
} ---@type vim.lsp.Config

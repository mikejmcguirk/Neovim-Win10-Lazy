local capabilities = require("blink.cmp").get_lsp_capabilities()

---@type vim.lsp.Config
return {
    capabilities = vim.tbl_deep_extend("force", capabilities, {
        workspace = { didChangeWatchedFiles = { dynamicRegistration = true } },
    }),
}

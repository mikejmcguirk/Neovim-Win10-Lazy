local gf = require("mjm.global_funcs")

local root_start = gf.get_buf_directory(vim.fn.bufnr())

vim.lsp.start({
    name = "taplo",
    cmd = { "taplo", "lsp", "stdio" },
    root_dir = gf.find_proj_root({ "*.toml" }, root_start, root_start),
    single_file_support = true,
    capabilities = Lsp_Capabilities,
})

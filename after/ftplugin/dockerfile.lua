local gf = require("mjm.global_funcs")

gf.create_lsp_formatter(LSP_Augroup)

local root_start = gf.get_buf_directory(vim.fn.bufnr())

vim.lsp.start({
    name = "dockerls",
    cmd = { "docker-langserver", "--stdio" },
    root_dir = gf.find_proj_root({ "Dockerfile" }, root_start, root_start),
    single_file_support = true,
    capabilities = Lsp_Capabilities,
})

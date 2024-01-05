local gf = require("mjm.global_funcs")

gf.adjust_tab_width(2)

-- Formatting by prettier through conform

local root_start = gf.get_buf_directory(vim.fn.bufnr())

vim.lsp.start({
    name = "cssls",
    cmd = { "vscode-css-language-server", "--stdio" },
    root_dir = gf.find_proj_root({ "package.json", ".git" }, root_start, root_start),
    single_file_support = true,
    capabilities = Lsp_Capabilities,
    settings = {
        css = { validate = true },
        scss = { validate = true },
        less = { validate = true },
    },
})

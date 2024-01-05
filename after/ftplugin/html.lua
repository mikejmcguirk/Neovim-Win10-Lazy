local gf = require("mjm.global_funcs")

gf.adjust_tab_width(2)

-- Formatting provided by prettier through conform

local root_start = gf.get_buf_directory(vim.fn.bufnr())

vim.lsp.start({
    name = "html",
    cmd = { "vscode-html-language-server", "--stdio" },
    capabilities = Lsp_Capabilities,
    root_dir = gf.find_proj_root({ "package.json", ".git" }, root_start, root_start),
    single_file_support = true,
    settings = {},
    init_options = {
        configurationSection = { "html", "css", "javascript" },
        embeddedLanguages = {
            css = true,
            javascript = true,
        },
        provideFormatter = false,
    },
})

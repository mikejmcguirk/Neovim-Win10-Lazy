local gf = require("mjm.global_funcs")

-- Formatting is handled with beautysh through conform

local root_start = gf.get_buf_directory(vim.fn.bufnr())

vim.lsp.start({
    name = "bashls",
    cmd = { "bash-language-server", "start" },
    root_dir = gf.find_proj_root({ ".git" }, root_start, root_start),
    single_file_support = true,
    capabilities = Lsp_Capabilities,
    settings = {
        bashIde = {
            globPattern = vim.env.GLOB_PATTERN or "*@(.sh|.inc|.bash|.command)",
        },
    },
})

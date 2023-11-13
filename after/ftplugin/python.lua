local gf = require("mjm.global_funcs")

local root_files = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
}

-- Formatting provided by ruff_format and isort through conform

local root_start = gf.get_buf_directory(vim.fn.bufnr(""))

vim.lsp.start({
    name = "pylsp",
    cmd = { "pylsp" },
    root_dir = gf.find_proj_root(root_files, root_start, root_start),
    single_file_support = true,
    capabilities = Lsp_Capabilities,
    settings = {
        pylsp = {
            plugins = {
                pycodestyle = {
                    maxLineLength = 99,
                    ignore = {
                        "E302",
                        "E303",
                        "E305",
                        "W931",
                    },
                },
            },
        },
    },
})

vim.lsp.start({
    name = "ruff_lsp",
    cmd = { "ruff-lsp" },
    root_dir = gf.find_proj_root(root_files, root_start, root_start),
    single_file_support = true,
    capabilities = Lsp_Capabilities,
    settings = {},
})

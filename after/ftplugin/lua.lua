local gf = require("mjm.global_funcs")

-- stylua used for formatting through conform

local root_files = {
    ".luarc.json",
    ".luarc.jsonc",
    ".luacheckrc",
    "selene.toml",
    "selene.yml",
}

local root_start = gf.get_buf_directory(vim.fn.bufnr())

vim.lsp.start({
    name = "lua_ls",
    cmd = { "lua-language-server" },
    root_dir = gf.find_proj_root(root_files, root_start, nil),
    capabilities = Lsp_Capabilities,
    before_init = require("neodev.lsp").before_init,
    settings = {
        Lua = {
            workspace = {
                checkThirdParty = false,
            },
            telemetry = {
                enable = false,
            },
        },
    },
})

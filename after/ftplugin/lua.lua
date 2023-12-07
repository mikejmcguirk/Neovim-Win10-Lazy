local gf = require("mjm.global_funcs")

-- stylua used for formatting through conform

local root_files = {
    ".luarc.json",
    ".luarc.jsonc",
    ".luacheckrc",
    "stylua.toml",
    "selene.toml",
    "selene.yml",
}

local root_start = gf.get_buf_directory(vim.fn.bufnr(""))

---@return string

vim.lsp.start({
    name = "lua_ls",
    cmd = { "lua-language-server" },
    root_dir = gf.find_proj_root(root_files, root_start, nil),
    capabilities = Lsp_Capabilities,
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
    on_init = function(client)
        local client_root_dir = client.config.root_dir
        local nvim_config = "nvim"
        local is_nvim_config = string.find(client_root_dir, nvim_config)

        if is_nvim_config == nil then
            return
        end

        client.config.settings = vim.tbl_deep_extend("force", client.config.settings, {
            Lua = {
                runtime = {
                    version = "LuaJIT",
                },
                workspace = {
                    library = vim.api.nvim_get_runtime_file("", true),
                },
            },
        })

        client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
    end,
})

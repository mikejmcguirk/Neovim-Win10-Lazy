local gf = require("mjm.global_funcs")

-- stylua used for formatting through conform

local root_files = {
    ".luarc.json",
    ".luarc.jsonc",
    ".luacheckrc",
    -- ".stylua.toml",
    "selene.toml",
    "selene.yml",
}

local root_start = gf.get_buf_directory(vim.fn.bufnr(""))

local check_for_nvim = function()
    local isLinux = vim.fn.has("unix")
    local linux_config_dir = vim.fn.expand("~/.config/nvim")
    local isWin = vim.fn.has("win32")
    local win_config_dir = vim.fn.expand("~\\AppData\\Local\\nvim-data")

    local check_os = function()
        if isLinux then
            return linux_config_dir
        elseif isWin then
            return win_config_dir
        end
    end

    local config_dir = check_os()
end

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
    on_init = function(client) -- For working in NeoVim
        if client.root_dir == nil then
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

            client.notify(
                "workspace/didChangeConfiguration",
                { settings = client.config.settings }
            )
        end
    end,
})

local gf = require("mjm.global_funcs")

-- Formatting by prettier through conform

local root_start = gf.get_buf_directory(vim.fn.bufnr(""))
vim.lsp.start(gf.setup_tsserver(root_start))

-- Autofixes are performed with eslint_d through conform

local find_eslint_root_dir = function()
    local eslint_root_files = {
        ".eslintrc",
        ".eslintrc.js",
        ".eslintrc.cjs",
        ".eslintrc.yaml",
        ".eslintrc.yml",
        ".eslintrc.json",
        "eslint.config.js",
    }

    local package_json = "package.json"

    if gf.find_file_with_field(package_json, root_start, "eslintConfig") then
        table.insert(eslint_root_files, package_json)
    end

    return gf.find_proj_root(eslint_root_files, root_start, nil)
end

vim.lsp.start({
    name = "eslint",
    cmd = { "vscode-eslint-language-server", "--stdio" },
    root_dir = find_eslint_root_dir(),
    capabilities = Lsp_Capabilities,
    single_file_support = true,
    init_options = {
        hostInfo = "neovim",
    },
    -- Refer to https://github.com/Microsoft/vscode-eslint#settings-options for documentation
    settings = {
        useESLintClass = false,
        experimental = {
            useFlatConfig = false,
        },
        codeActionOnSave = {
            enable = false,
            mode = "all",
        },
        format = false,
        quiet = false,
        onIgnoredFiles = "off",
        rulesCustomizations = {},
        run = "onType",
        problems = {
            shortenToSingleLine = false,
        },
        nodePath = "",
        -- use the workspace folder location or the file location
        -- (if no workspace folder is open) as the working directory
        workingDirectory = { mode = "location" },
        codeAction = {
            disableRuleComment = {
                enable = true,
                location = "separateLine",
            },
            showDocumentation = {
                enable = true,
            },
        },
    },
    handlers = {
        ["eslint/openDoc"] = function(_, result)
            if not result then
                return
            end
            local sysname = vim.loop.os_uname().sysname
            if sysname:match("Windows") then
                os.execute(string.format("start %q", result.url))
            elseif sysname:match("Linux") then
                os.execute(string.format("xdg-open %q", result.url))
            else
                os.execute(string.format("open %q", result.url))
            end
            return {}
        end,
        ["eslint/confirmESLintExecution"] = function(_, result)
            if not result then
                return
            end
            return 4
        end,
        ["eslint/probeFailed"] = function()
            vim.notify("[lspconfig] ESLint probe failed.", vim.log.levels.WARN)
            return {}
        end,
        ["eslint/noLibrary"] = function()
            vim.notify("[lspconfig] Unable to find ESLint library.", vim.log.levels.WARN)
            return {}
        end,
    },
})

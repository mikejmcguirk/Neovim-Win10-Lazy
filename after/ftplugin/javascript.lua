local gf = require("mjm.global_funcs")

-- Formatting by prettier through conform

local root_start = gf.get_buf_directory(vim.fn.bufnr())
vim.lsp.start(gf.setup_tsserver(root_start))

-- Autofixes are performed with eslint_d through conform

local eslint_root_files = {
    "eslint.config.js",
    "eslint.config.cjs",
    ".eslintrc",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.yaml",
    ".eslintrc.yml",
    ".eslintrc.json",
}

local package_json = "package.json"
local pkg_json_files =
    vim.fs.find(package_json, { path = root_start, upward = true, stop = gf.get_home() })

---@param matches string[]
---@return boolean
local check_eslint_cfg = function(matches)
    for _, match in ipairs(matches) do
        local file = io.open(match, "r")

        if file then
            for line in file:lines() do
                if line:find("eslintConfig") then
                    file:close()

                    return true
                end
            end

            file:close()
        end
    end

    return false
end

if check_eslint_cfg(pkg_json_files) then
    table.insert(eslint_root_files, package_json)
end

local eslint_root = gf.find_proj_root(eslint_root_files, root_start, nil)
local eslint_config = vim.fn.globpath(eslint_root, "eslint.config.js")
local is_flat_config = nil

if #eslint_config == 0 then
    is_flat_config = false
else
    is_flat_config = true
end

vim.lsp.start({
    name = "eslint",
    cmd = { "vscode-eslint-language-server", "--stdio" },
    root_dir = eslint_root,
    capabilities = Lsp_Capabilities,
    single_file_support = true,
    init_options = {
        hostInfo = "neovim",
    },
    -- Refer to https://github.com/Microsoft/vscode-eslint#settings-options for documentation
    settings = {
        -- workspaceFolder = {
        --     uri = eslint_root,
        --     name = vim.fn.fnamemodify(eslint_root, ":t"),
        -- },
        validate = "on",
        -- packageManager = nil,
        -- useESLintClass = false,
        experimental = {
            useFlatConfig = is_flat_config,
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

local gf = require("mjm.global_funcs")

if not Env_OmniSharp_DLL then
    vim.api.nvim_err_writeln(
        "Env_OmniSharp_DLL global Neovim variable not found. Cannot start OmniSharp"
    )
else
    -- https://github.com/OmniSharp/omnisharp-roslyn/issues/909
    local omni_capabilities = vim.deepcopy(Lsp_Capabilities)
    omni_capabilities = vim.tbl_deep_extend("force", omni_capabilities, {
        workspace = {
            workspaceFolders = false,
        },
    })

    local root_start = gf.get_buf_directory(vim.fn.bufnr(""))

    local root_files = {
        "*.sln",
        "*.csproj",
        "omnisharp.json",
        "function.json",
    }

    local omnisharp_start_table = {
        name = "omnisharp",
        root_dir = gf.find_proj_root(root_files, root_start, nil),
        capabilities = omni_capabilities,
        init_options = {},
        cmd = {
            "dotnet",
            Env_OmniSharp_DLL,
            "-z", -- https://github.com/OmniSharp/omnisharp-vscode/pull/4300
            "--hostPID",
            tostring(vim.fn.getpid()),
            "DotNet:enablePackageRestore=false",
            "--encoding",
            "utf-8",
            "--languageserver",
            -- Config depdendent arguments
            "FormattingOptions:EnableEditorConfigSupport=true",
            -- "MsBuild:LoadProjectsOnDemand=true",
            "RoslynExtensionsOptions:EnableAnalyzersSupport=true",
            "FormattingOptions:OrganizeImports=true",
            -- "RoslynExtensionsOptions:EnableImportCompletion=true",
            "Sdk:IncludePrereleases=true",
            -- "RoslynExtensionsOptions:AnalyzeOpenDocumentsOnly=true",
        },
        enable_editorconfig_support = true,
        enable_ms_build_load_projects_on_demand = false, -- Useful for big projects
        enable_roslyn_analyzers = true, -- Formatting/linting
        organize_imports_on_format = true,
        -- Adds unimported types and extension methods to completion. Can be slow
        enable_import_completion = false,
        sdk_include_prereleases = true,
        analyze_open_documents_only = false,
    }

    local omnisharp_extended = require("omnisharp_extended")
    omnisharp_start_table.handlers = omnisharp_start_table.handlers or {}
    omnisharp_start_table.handlers["textDocument/definition"] = omnisharp_extended.handler

    vim.lsp.start(omnisharp_start_table)
end

local gf = require("mjm.global_funcs")

-- Formatting provided by csharpier through conform

-- https://github.com/OmniSharp/omnisharp-roslyn/issues/909
local omni_capabilities = vim.deepcopy(Lsp_Capabilities)
omni_capabilities.workspace.workspaceFolders = false

local root_start = gf.get_buf_directory(vim.fn.bufnr())

local root_files = {
    "*.sln",
    "*.csproj",
    "omnisharp.json",
    "function.json",
}

local cmd = {
    "dotnet",
    Env_OmniSharp_DLL,
    "-z", -- https://github.com/OmniSharp/omnisharp-vscode/pull/4300
    "--hostPID",
    tostring(vim.fn.getpid()),
    "DotNet:enablePackageRestore=false",
    "--encoding",
    "utf-8",
    "--languageserver",
}

local editorconfig_support = true
local load_on_demand = false
local roslyn_analyzers = true
local organize_imports_on_format = true
local import_completion = false
local sdk_include_prereleases = true
local analyze_open_documents_only = false

if editorconfig_support then
    table.insert(cmd, "FormattingOptions:EnableEditorConfigSupport=true")
end

if load_on_demand then
    table.insert(cmd, "MsBuild:LoadProjectsOnDemand=true")
end

if roslyn_analyzers then
    table.insert(cmd, "RoslynExtensionsOptions:EnableAnalyzersSupport=true")
end

if organize_imports_on_format then
    table.insert(cmd, "FormattingOptions:OrganizeImports=true")
end

if import_completion then
    table.insert(cmd, "RoslynExtensionsOptions:EnableImportCompletion=true")
end

if sdk_include_prereleases then
    table.insert(cmd, "Sdk:IncludePrereleases=true")
end

if analyze_open_documents_only then
    table.insert(cmd, "RoslynExtensionsOptions:AnalyzeOpenDocumentsOnly=true")
end

local omnisharp_start_table = {
    name = "omnisharp",
    root_dir = gf.find_proj_root(root_files, root_start, nil),
    capabilities = omni_capabilities,
    init_options = {},
    cmd = cmd,
    enable_editorconfig_support = editorconfig_support,
    enable_ms_build_load_projects_on_demand = load_on_demand, -- Useful for big projects
    enable_roslyn_analyzers = roslyn_analyzers, -- Linting
    organize_imports_on_format = organize_imports_on_format,
    -- Adds unimported types and extension methods to completion. Can be slow
    enable_import_completion = import_completion,
    sdk_include_prereleases = sdk_include_prereleases,
    analyze_open_documents_only = analyze_open_documents_only,
}

local omnisharp_extended = require("omnisharp_extended")
omnisharp_start_table.handlers = omnisharp_start_table.handlers or {}
omnisharp_start_table.handlers["textDocument/definition"] = omnisharp_extended.handler

if Env_OmniSharp_DLL then
    vim.lsp.start(omnisharp_start_table)
else
    vim.api.nvim_err_writeln("Env_OmniSharp_DLL Nvim variable not found. Cannot start OmniSharp")
end

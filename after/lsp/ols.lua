local function get_ols_profile()
    local sys = vim.uv.os_uname().sysname
    if sys == "Linux" then
        return "linux_profile"
    elseif sys == "Darwin" then
        return "mac_profile"
    elseif sys == "Windows_NT" then
        return "windows_profile"
    else
        return "default"
    end
end

local checker_args = {
    -- "-vet-packages", -- Needs specific packages to be named.
    -- "-vet-unused-procedures", -- Requires vet-packages

    "-did-you-mean-limit:100",
    "-max-error-count:100",
    "-show-unused-with-location",
    "-strict-style",
    "-vet-cast",
    "-vet-shadowing",
    "-vet-tabs",
    "-vet-unused",
    "-vet-unused-imports",
    "-vet-unused-variables",
    "-vet-using-stmt",
}

local util = require("lspconfig.util")

local function default_odin_root()
    local odin_root = os.getenv("ODIN_ROOT")
    if odin_root and odin_root ~= "" then
        return vim.fs.normalize(odin_root)
    end

    local result = vim.system({ "odin", "root" }, { text = true }):wait()
    if result.code == 0 and result.stdout then
        local stdout = vim.trim(result.stdout)
        if stdout ~= "" then
            return vim.fs.normalize(stdout)
        end
    end

    return nil
end

local function is_library(fname)
    local odin_root = default_odin_root()
    if not odin_root then
        return nil
    end

    fname = vim.fs.normalize(fname)
    for _, dir in ipairs({ "base", "core", "vendor" }) do
        local item = vim.fs.joinpath(odin_root, dir)
        if vim.fs.relpath(item, fname) then
            local clients = vim.lsp.get_clients({ name = "ols" })
            return #clients > 0 and clients[#clients].config.root_dir or nil
        end
    end
end

return {
    root_dir = function(bufnr, on_dir)
        local fname = vim.api.nvim_buf_get_name(bufnr)
        local reused_dir = is_library(fname)
        if reused_dir then
            on_dir(reused_dir)
            return
        end

        on_dir(util.root_pattern("ols.json", ".git", "*.odin")(fname))
    end,
    init_options = {
        checker_args = table.concat(checker_args, " "),
        checker_skip_packages = {},
        completion_exclude_attributes = {},
        enable_auto_import = true,
        enable_checker_only_saved = false,
        enable_checker_workspace_diagnostics = false,
        enable_code_action_invert_if = true,
        enable_comp_lit_signature_help = false,
        enable_comp_lit_signature_help_use_docs = false,
        enable_completion_matching = true,
        enable_document_highlights = true,
        enable_document_links = true,
        enable_document_symbols = true,
        enable_fake_methods = false,
        enable_format = false, -- odinfmt is setup through conform
        enable_hover = true,
        enable_inlay_hints_default_params = true,
        enable_inlay_hints_implicit_return = true,
        enable_inlay_hints_optional_result = true,
        enable_inlay_hints_params = true,
        enable_overload_resolution = true,
        enable_procedure_snippet = true,
        enable_references = true,
        enable_semantic_tokens = true,
        enable_snippets = true,
        odin_command = nil,
        odin_root_override = nil,
        profile = get_ols_profile(),
        profiles = {
            {
                name = "default",
                defines = { ODIN_DEBUG = "false" },
            },
            {
                name = "linux_profile",
                os = "linux",
                defines = { ODIN_DEBUG = "false" },
            },
            {
                name = "mac_profile",
                os = "darwin",
                arch = "arm64",
                defines = { ODIN_DEBUG = "false" },
            },
            {
                name = "windows_profile",
                os = "windows",
                defines = { ODIN_DEBUG = "false" },
            },
        },
        struct_fields_underscore_visibility = "",
        verbose = false,
    },
}

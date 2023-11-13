local gf = require("mjm.global_funcs")

-- Formatting is handled with the built-in RustFmt function + rust.vim plugin

local root_start = gf.get_buf_directory(vim.fn.bufnr(""))

vim.lsp.start({
    name = "rust_analyzer",
    cmd = { "rust-analyzer" },
    capabilities = Lsp_Capabilities,
    root_dir = gf.find_proj_root({ "Cargo.toml" }, root_start, nil),
    settings = {
        ["rust-analyzer"] = {
            cargo = {
                features = "all",
            },
            checkOnSave = {
                command = "clippy", --linting
            },
        },
    },
})

local function reload_workspace(bufnr)
    local clients = vim.lsp.get_active_clients({ name = "rust_analyzer", bufnr = bufnr })
    for _, client in ipairs(clients) do
        vim.notify("Reloading Cargo Workspace")
        client.request("rust-analyzer/reloadWorkspace", nil, function(err)
            if err then
                error(tostring(err))
            end
            vim.notify("Cargo workspace reloaded")
        end, 0)
    end
end

vim.keymap.set("n", "<leader>vsro", function()
    reload_workspace(vim.fn.bufnr(""))
end, Opts)

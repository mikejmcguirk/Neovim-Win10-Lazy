local api = vim.api
local expr_group = "conform-formatexpr" ---@type string
local ft_config = {
    css = { "prettier" },
    go = { "gofumpt" },
    html = { "prettier" },
    json = { "prettier" },
    lua = { "stylua" },
    python = { "ruff_format" },
    rust = { "rustfmt" },
    query = { "format-queries" },
    sh = { "shfmt" },
    toml = { "taplo" },
} ---@type table<string, conform.FiletypeFormatter>

local fts = vim.tbl_keys(ft_config) ---@type string[]
return {
    "stevearc/conform.nvim",
    ft = fts,
    opts = {
        formatters_by_ft = ft_config,
    },
    init = function()
        api.nvim_create_autocmd("FileType", {
            group = api.nvim_create_augroup("conformer", { clear = true }),
            pattern = fts,
            callback = function(ev)
                api.nvim_create_autocmd("BufWritePre", {
                    group = api.nvim_create_augroup("conform-" .. tostring(ev.buf), {}),
                    buffer = ev.buf,
                    callback = function()
                        require("conform").format({
                            bufnr = ev.buf,
                            lsp_fallback = false,
                            async = false,
                            timeout_ms = 1000,
                        })
                    end,
                })
            end,
        })

        api.nvim_create_autocmd("FileType", {
            group = api.nvim_create_augroup(expr_group, { clear = true }),
            pattern = fts,
            callback = function(ev)
                local expr = "v:lua.require'conform'.formatexpr()" ---@type string
                api.nvim_set_option_value("formatexpr", expr, { buf = ev.buf })
            end,
        })
    end,
}

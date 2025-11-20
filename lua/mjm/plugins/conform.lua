local api = vim.api
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
    typst = { "typstyle" },
} ---@type table<string, conform.FiletypeFormatter>

local fts = vim.tbl_keys(ft_config) ---@type string[]
return {
    "stevearc/conform.nvim",
    ft = fts,
    opts = { formatters_by_ft = ft_config },
    init = function()
        api.nvim_create_autocmd("FileType", {
            group = api.nvim_create_augroup("conformer", { clear = true }),
            pattern = fts,
            callback = function(ev)
                local do_conform = function(buf)
                    require("conform").format({
                        bufnr = buf,
                        lsp_fallback = false,
                        async = false,
                        timeout_ms = 1000,
                    })
                end

                local expr = "v:lua.require'conform'.formatexpr()" ---@type string
                api.nvim_set_option_value("formatexpr", expr, { buf = ev.buf })
                vim.keymap.set("n", "<localleader>c", function()
                    do_conform(ev.buf)
                end, { buffer = ev.buf })

                api.nvim_create_autocmd("BufWritePre", {
                    group = api.nvim_create_augroup("conform-" .. tostring(ev.buf), {}),
                    buffer = ev.buf,
                    callback = function()
                        do_conform(ev.buf)
                    end,
                })
            end,
        })
    end,
}

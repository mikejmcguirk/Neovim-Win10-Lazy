local api = vim.api

local ft_cfg = {
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
    -- TODO: Configure to remove trailing blanks
    typst = { "typstyle" },
} ---@type table<string, conform.FiletypeFormatter>

return {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = ft_cfg },
    init = function()
        api.nvim_create_autocmd("FileType", {
            group = api.nvim_create_augroup("conformer", {}),
            pattern = vim.tbl_keys(ft_cfg),
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

-- MAYBE: https://github.com/neovim/neovim/discussions/35602
-- Probably not, be interesting to have around
